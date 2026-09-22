"""Real SDP and RTP regression tests in the runner's isolated namespace."""

import time
import uuid

from rtp_test_support import MediaPeer, RtpEngineControl, assert_bidirectional_rtp, parse_sdp
from test_sip_socket_routing import KamailioRoutingTestCase, LAN, PBX, PROXY, PUBLIC, SERVICE, WAN, header, uri, response


class RtpRoutingTests(KamailioRoutingTestCase):
    rtp_enabled = True
    # Also exercise the no-NAT case with configured local subnets: that daemon
    # only provides internal/external interfaces, never an interface named local.
    local_networks = "127.10.0.0/24,127.20.0.0/24"

    @classmethod
    def setUpClass(cls):
        cls.control = RtpEngineControl(19999 if cls.behind_nat else 29999)
        cls.control.wait_ready()
        super().setUpClass()

    def media_peer(self, address):
        peer = MediaPeer(address)
        self.addCleanup(peer.close)
        return peer

    def advertised_media(self, peer_ip):
        if peer_ip == PBX:
            return SERVICE
        if peer_ip == LAN and self.behind_nat:
            return PROXY
        return PUBLIC

    def media_target(self, message, recipient_ip, transport="RTP/AVP"):
        sdp = parse_sdp(message)
        advertised = self.advertised_media(recipient_ip)
        self.assertEqual(sdp["address"], advertised, message)
        self.assertEqual(sdp["origin_address"], advertised, message)
        self.assertEqual(sdp["transport"], transport, message)
        self.assertIn(8, sdp["payloads"])
        self.assertGreater(sdp["port"], 0)
        # Simulate only the public-to-private address mapping at the test peer.
        # No firewall or conntrack rules are created in the host or namespace.
        bound = PROXY if self.behind_nat and advertised == PUBLIC else advertised
        return (bound, sdp["port"])

    def start_call(self, caller_ip=LAN, callee_ip=PBX, caller_transport="udp", delayed_offer=False, trunk=True, target_user="peer"):
        caller = self.peer(caller_ip, caller_transport)
        callee = self.peer(callee_ip)
        caller_media, callee_media = self.media_peer(caller_ip), self.media_peer(callee_ip)
        proxy = (SERVICE if caller_ip == PBX else self.proxy_ip, 5061 if caller_transport == "tls" else 5060)
        callee_proxy = (SERVICE if callee_ip == PBX else self.proxy_ip, 5060)
        caller.connect(proxy)
        call_id = uuid.uuid4().hex
        self.addCleanup(self.control.delete, call_id)
        initial = self.request(caller, "INVITE", callee.contact.replace("sip:peer@", "sip:" + target_user + "@"), call_id,
                               extra="isTrunk: 1\r\n" if trunk else "", body="" if delayed_offer else caller_media.sdp())
        caller.send(initial, proxy)
        invite, source = callee.receive()
        self.assertTrue(invite.startswith("INVITE "), invite)
        self.assert_contact(invite, self.advertised_media(callee_ip), "udp")
        call = dict(a=caller, b=callee, am=caller_media, bm=callee_media, id=call_id,
                    a_ip=caller_ip, b_ip=callee_ip, a_proxy=proxy, b_proxy=callee_proxy,
                    initial=initial, invite=invite, invite_source=source,
                    a_from=header(initial, "From"), b_from=header(invite, "To") + ";tag=test-peer",
                    b_contact=uri(header(invite, "Contact")), delayed_offer=delayed_offer)
        if not delayed_offer:
            transport = "RTP/SAVP" if not trunk and caller_ip == PBX else "RTP/AVP"
            call["b_target"] = self.media_target(invite, callee_ip, transport=transport)
            self.assert_session(call)
        return call

    def answer_call(self, call, provisional=False, reliable=False, body=None):
        answered = response(call["invite"], call["b"].contact, body=call["bm"].sdp() if body is None else body,
                            code="183 Session Progress" if provisional else "200 OK")
        if provisional and reliable:
            answered = answered.replace("Content-Length:", "Require: 100rel\r\nRSeq: 1\r\nContent-Length:", 1)
        call["b"].send(answered, call["invite_source"])
        received = self.receive_status(call["a"], "183" if provisional else "200")
        call["a_target"] = self.media_target(received, call["a_ip"])
        call["a_contact"] = uri(header(received, "Contact"))
        self.assert_contact(received, self.advertised_media(call["a_ip"]), call["a"].transport)
        self.assert_session(call)
        if provisional:
            return
        ack = self.in_dialog(call, "ACK", body=call["am"].sdp() if call["delayed_offer"] else "", sequence=1)
        call["a"].send(ack, call["a_proxy"])
        delivered, _ = call["b"].receive()
        self.assertTrue(delivered.startswith("ACK "), delivered)
        if call["delayed_offer"]:
            call["b_target"] = self.media_target(delivered, call["b_ip"])

    def in_dialog(self, call, method, reverse=False, body="", sequence=2, extra=""):
        sender = "b" if reverse else "a"
        receiver = "a" if reverse else "b"
        return self.request(call[sender], method, call[sender + "_contact"], call["id"], sequence=sequence,
                            from_value=call[sender + "_from"], to_value=call[receiver + "_from"],
                            body=body, extra=extra)

    def receive_status(self, peer, status):
        for _ in range(12):
            message, _ = peer.receive()
            if message.startswith("SIP/2.0 " + status):
                return message
            self.assertTrue(message.startswith("SIP/2.0 100"), message)
        self.fail("Missing SIP response " + status)

    def assert_session(self, call):
        result = self.control.query(call["id"])
        self.assertEqual(result.get("result"), "ok", result)

    def assert_deleted(self, call):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            result = self.control.query(call["id"])
            if result.get("result") == "error":
                self.assertIn("Unknown call-id", result.get("error-reason", ""))
                return
            time.sleep(0.05)
        self.fail("RTPEngine retained a terminated call: " + str(result))

    def check_audio(self, call):
        received = assert_bidirectional_rtp(call["am"], call["a_target"], call["bm"], call["b_target"])
        for side in ("a", "b"):
            self.assertEqual(received[side]["source"][0], call[side + "_target"][0])
        self.assert_session(call)

    def close_call(self, call, reverse=False):
        sender, receiver = ("b", "a") if reverse else ("a", "b")
        call[sender].send(self.in_dialog(call, "BYE", reverse=reverse, sequence=20), call[sender + "_proxy"])
        bye, source = call[receiver].receive()
        self.assertTrue(bye.startswith("BYE "), bye)
        call[receiver].send(response(bye), source)
        self.receive_status(call[sender], "200")
        self.assert_deleted(call)

    def established_call(self, **kwargs):
        call = self.start_call(**kwargs)
        self.answer_call(call)
        self.check_audio(call)
        return call

    def renegotiate(self, call, method="UPDATE", reverse=True, direction="sendrecv", version=2, reject=False):
        sender, receiver = ("b", "a") if reverse else ("a", "b")
        request = self.in_dialog(call, method, reverse=reverse, sequence=version,
                                 body=call[sender + "m"].sdp(version=version, direction=direction),
                                 extra="isTrunk: 1\r\n" if method == "INVITE" else "")
        call[sender].send(request, call[sender + "_proxy"])
        delivered, source = call[receiver].receive()
        self.assertTrue(delivered.startswith(method + " "), delivered)
        recipient_target = self.media_target(delivered, call[receiver + "_ip"])
        if reject:
            call[receiver].send(response(delivered, code="480 Temporarily Unavailable"), source)
            self.receive_status(call[sender], "480")
            if method == "INVITE":
                ack, _ = call[receiver].receive()
                self.assertTrue(ack.startswith("ACK "), ack)
                # The UA acknowledges the failure on its original transaction.
                failed_ack = request.replace("INVITE ", "ACK ", 1).replace(
                    "CSeq: {} INVITE".format(version), "CSeq: {} ACK".format(version))
                call[sender].send(failed_ack, call[sender + "_proxy"])
            self.assert_session(call)
            return
        answer = response(delivered, call[receiver].contact,
                          body=call[receiver + "m"].sdp(version=version, direction=direction))
        call[receiver].send(answer, source)
        received = self.receive_status(call[sender], "200")
        call[sender + "_target"] = self.media_target(received, call[sender + "_ip"])
        call[receiver + "_target"] = recipient_target
        self.assertEqual(parse_sdp(received)["direction"], direction)
        if method == "INVITE":
            call[sender].send(self.in_dialog(call, "ACK", reverse=reverse, sequence=version), call[sender + "_proxy"])
            ack, _ = call[receiver].receive()
            self.assertTrue(ack.startswith("ACK "), ack)
        self.assert_session(call)

    def test_lan_to_service_media(self):
        self.close_call(self.established_call())

    def test_early_media_then_answer(self):
        call = self.start_call()
        self.answer_call(call, provisional=True)
        self.check_audio(call)
        self.answer_call(call)
        self.check_audio(call)
        self.close_call(call)

    def test_service_to_lan_media(self):
        self.close_call(self.established_call(caller_ip=PBX, callee_ip=LAN), reverse=True)

    def test_wan_to_service_media(self):
        self.close_call(self.established_call(caller_ip=WAN))

    def test_service_to_wan_media(self):
        self.close_call(self.established_call(caller_ip=PBX, callee_ip=WAN), reverse=True)

    def test_lan_to_wan_media(self):
        self.close_call(self.established_call(caller_ip=LAN, callee_ip=WAN))

    def test_tcp_signaling_with_rtp(self):
        self.close_call(self.established_call(caller_transport="tcp"), reverse=True)

    def test_tls_signaling_with_rtp(self):
        self.close_call(self.established_call(caller_transport="tls"), reverse=True)

    def test_reverse_update_media(self):
        call = self.established_call()
        self.renegotiate(call)
        self.check_audio(call)
        self.close_call(call)

    def test_reverse_update_of_outbound_call(self):
        call = self.established_call(caller_ip=PBX, callee_ip=LAN)
        self.renegotiate(call)
        self.check_audio(call)
        self.close_call(call)

    def test_update_preserves_rtp_with_changed_contact_user(self):
        call = self.established_call(caller_ip=PBX, callee_ip=LAN, target_user="dialed-number")
        self.renegotiate(call, reverse=False)
        self.check_audio(call)
        self.close_call(call)

    def test_update_preserves_negotiated_srtp_transport(self):
        call = self.start_call(caller_ip=PBX, callee_ip=LAN, trunk=False)
        srtp_answer = call["bm"].sdp(transport="RTP/SAVP") + "a=crypto:" + header(call["invite"], "a=crypto") + "\r\n"
        self.answer_call(call, body=srtp_answer)
        update = self.in_dialog(call, "UPDATE", body=call["am"].sdp(version=2))
        call["a"].send(update, call["a_proxy"])
        delivered, source = call["b"].receive()
        self.assertTrue(delivered.startswith("UPDATE "), delivered)
        self.media_target(delivered, LAN, transport="RTP/SAVP")
        self.assertIn("a=crypto:", delivered)
        call["b"].send(response(delivered, call["b"].contact, body=srtp_answer), source)
        received = self.receive_status(call["a"], "200")
        self.media_target(received, PBX, transport="RTP/AVP")
        self.assertNotIn("a=crypto:", received)
        self.close_call(call)

    def test_reverse_reinvite_media(self):
        call = self.established_call()
        self.renegotiate(call, method="INVITE")
        self.check_audio(call)
        self.close_call(call)

    def test_hold_resume_media(self):
        call = self.established_call()
        self.renegotiate(call, direction="inactive")
        self.renegotiate(call, direction="sendrecv", version=3)
        self.check_audio(call)
        self.close_call(call)

    def test_failed_reinvite_keeps_session(self):
        call = self.established_call()
        self.renegotiate(call, method="INVITE", reject=True)
        self.check_audio(call)
        self.close_call(call)

    def test_delayed_offer_answer_in_ack(self):
        self.close_call(self.established_call(delayed_offer=True))

    def test_delayed_offer_answer_in_prack(self):
        call = self.start_call(delayed_offer=True)
        self.answer_call(call, provisional=True, reliable=True)
        call["a"].send(self.in_dialog(call, "PRACK", body=call["am"].sdp(), extra="RAck: 1 1 INVITE\r\n"), call["a_proxy"])
        prack, source = call["b"].receive()
        self.assertTrue(prack.startswith("PRACK "), prack)
        call["b_target"] = self.media_target(prack, call["b_ip"])
        call["b"].send(response(prack), source)
        self.receive_status(call["a"], "200")
        self.check_audio(call)
        call["b"].send(response(call["invite"], call["b"].contact), call["invite_source"])
        self.receive_status(call["a"], "200")
        call["a"].send(self.in_dialog(call, "ACK", sequence=1), call["a_proxy"])
        ack, _ = call["b"].receive()
        self.assertTrue(ack.startswith("ACK "), ack)
        self.close_call(call)

    def test_failed_initial_delayed_offer_releases_media(self):
        call = self.start_call(delayed_offer=True)
        self.answer_call(call, provisional=True, reliable=True)
        call["b"].send(response(call["invite"], code="486 Busy Here"), call["invite_source"])
        self.receive_status(call["a"], "486")
        self.assert_deleted(call)

    def test_cancel_without_sdp_releases_media(self):
        call = self.start_call()
        call["b"].send(response(call["invite"], code="180 Ringing"), call["invite_source"])
        self.receive_status(call["a"], "180")
        initial = call["initial"].split("\r\n\r\n", 1)[0]
        initial = initial.replace("INVITE ", "CANCEL ", 1).replace("CSeq: 1 INVITE", "CSeq: 1 CANCEL")
        initial = initial.split("Content-Type:", 1)[0] + "Content-Length: 0\r\n\r\n"
        call["a"].send(initial, call["a_proxy"])
        cancel, source = call["b"].receive()
        self.assertTrue(cancel.startswith("CANCEL "), cancel)
        call["b"].send(response(cancel), source)
        call["b"].send(response(call["invite"], code="487 Request Terminated"), call["invite_source"])
        self.assert_deleted(call)

    def test_srtp_fallback_retries_once_then_releases_media(self):
        call = self.start_call(caller_ip=PBX, callee_ip=LAN, trunk=False)
        self.assertIn("a=crypto:", call["invite"])
        call["b"].send(response(call["invite"], code="488 Not Acceptable Here"), call["invite_source"])
        ack, _ = call["b"].receive()
        self.assertTrue(ack.startswith("ACK "), ack)
        fallback, source = call["b"].receive()
        self.assertTrue(fallback.startswith("INVITE "), fallback)
        self.media_target(fallback, LAN, transport="RTP/AVP")
        self.assertNotIn("a=crypto:", fallback)
        call["b"].send(response(fallback, code="488 Not Acceptable Here"), source)
        self.receive_status(call["a"], "488")
        self.assert_deleted(call)


class PublicAddressRtpRoutingTests(RtpRoutingTests):
    behind_nat = False
