"""SIP integration tests; run through run-sip-routing-tests.sh, not on an NS8 node.

Uses Kamailio 5.8 and TOPOS/Redis, the production relay/branch/local-request
routes and sip-routing.cfg. Peers are sockets on isolated loopback addresses.
The PBX and authentication are outside the fixture. RTP tests extend it with
the real media routes and RTPEngine.
"""

import os
from pathlib import Path
import re
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
import time
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "modules/kamailio/config"
PROXY = "127.10.0.1"
PUBLIC = "127.30.0.1"
SERVICE = "127.20.0.1"
LAN = "127.10.0.2"
WAN = "127.30.0.2"
PBX = "127.20.0.2"


def headers(message, name):
    return re.findall(r"^" + re.escape(name) + r":\s*(.*?)\r?$", message, re.M | re.I)


def header(message, name):
    values = headers(message, name)
    if not values:
        raise AssertionError("Missing {} in:\n{}".format(name, message))
    return values[0]


def uri(contact):
    return re.search(r"<([^>]+)>", contact).group(1)


def response(request, contact=None, body="", code="200 OK"):
    lines = ["SIP/2.0 " + code]
    lines.extend("Via: " + value for value in headers(request, "Via"))
    lines.extend("Record-Route: " + value for value in headers(request, "Record-Route"))
    to = header(request, "To")
    if ";tag=" not in to:
        to += ";tag=test-peer"
    lines.extend(["From: " + header(request, "From"), "To: " + to,
                  "Call-ID: " + header(request, "Call-ID"),
                  "CSeq: " + header(request, "CSeq")])
    if contact:
        lines.append("Contact: <{}>".format(contact))
    if body:
        lines.append("Content-Type: application/sdp")
    return "\r\n".join(lines) + "\r\nContent-Length: {}\r\n\r\n{}".format(len(body.encode()), body)


class Peer:
    def __init__(self, address, transport="udp", certificate=None, server=False):
        self.transport = transport
        self.certificate = certificate
        self.buffer = b""
        self.connection = None
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM if transport == "udp" else socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.settimeout(4)
        self.sock.bind((address, 0))
        self.address = self.sock.getsockname()
        if server and transport != "udp":
            self.sock.listen(1)

    @property
    def contact(self):
        return "sip:peer@{}:{};transport={}".format(*self.address, self.transport)

    def connect(self, address):
        if self.transport == "udp":
            return
        self.sock.connect(address)
        self.connection = self.sock
        if self.transport == "tls":
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            self.connection = context.wrap_socket(self.sock, server_hostname="localhost")

    def send(self, message, address):
        if self.transport == "udp":
            self.sock.sendto(message.encode(), address)
        else:
            self.connection.sendall(message.encode())

    def receive(self):
        if self.transport == "udp":
            data, address = self.sock.recvfrom(65535)
            return data.decode(), address
        if self.connection is None:
            self.connection, _ = self.sock.accept()
            self.connection.settimeout(4)
            if self.transport == "tls":
                context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                context.load_cert_chain(*self.certificate)
                self.connection = context.wrap_socket(self.connection, server_side=True)
        while True:
            boundary = self.buffer.find(b"\r\n\r\n")
            if boundary >= 0:
                prefix = self.buffer[:boundary].decode()
                length = int(header(prefix, "Content-Length"))
                end = boundary + 4 + length
                if len(self.buffer) >= end:
                    message, self.buffer = self.buffer[:end], self.buffer[end:]
                    return message.decode(), self.connection.getpeername()
            data = self.connection.recv(65535)
            if not data:
                raise AssertionError("SIP connection closed before a complete message")
            self.buffer += data

    def receive_final(self):
        for _ in range(10):
            message, address = self.receive()
            if not message.startswith("SIP/2.0 1"):
                return message, address
        raise AssertionError("No final SIP response")

    def close(self):
        if self.connection is not None and self.connection is not self.sock:
            self.connection.close()
        self.sock.close()


def production_block(source, prefix, name):
    pattern = r"^" + re.escape(prefix + "[" + name + "]") + r"\s*\{.*?^\}[^\n]*"
    match = re.search(pattern, source, re.M | re.S)
    if not match:
        raise AssertionError("Missing production block {}[{}]".format(prefix, name))
    return match.group(0)


@unittest.skipUnless(os.environ.get("SIP_TEST_ISOLATED") == "1", "Use tests/run-sip-routing-tests.sh")
class KamailioRoutingTestCase(unittest.TestCase):
    behind_nat = True
    rtp_enabled = False
    local_networks = None

    @classmethod
    def setUpClass(cls):
        cls.kamailio = shutil.which("kamailio") or "/usr/sbin/kamailio"
        if not Path(cls.kamailio).exists():
            raise unittest.SkipTest("Use tests/run-sip-routing-tests.sh for the isolated integration environment")
        cls.temp = tempfile.TemporaryDirectory(prefix="sip-routing-")
        cls.directory = Path(cls.temp.name)
        cls.addClassCleanup(cls.temp.cleanup)
        certificate_dir = Path(os.environ["SIP_TEST_CERTIFICATE_DIR"])
        cert, key = certificate_dir / "cert.pem", certificate_dir / "key.pem"
        cls.certificate = (str(cert), str(key))
        tls_config = cls.directory / "tls.cfg"
        tls_config.write_text("""[server:default]
method = TLSv1.2+
verify_certificate = no
require_certificate = no
certificate = {cert}
private_key = {key}
[client:default]
method = TLSv1.2+
verify_certificate = no
require_certificate = no
""".format(cert=cert, key=key))
        cls.probes = {name: Peer(address) for name, address in (
            ("local", LAN), ("internal", PBX), ("external", WAN), ("loopback", "127.0.0.1"))}
        for peer in cls.probes.values():
            cls.addClassCleanup(peer.close)
        source = (CONFIG / "kamailio.cfg").read_text()
        definitions = "\n".join(re.findall(r"^#!define .*$", source, re.M))
        route_names = [
            ("route", "RELAY"), ("branch_route", "MANAGE_BRANCH"),
            ("route", "NATMANAGE"), ("route", "DLGURI"),
            ("event_route", "tm:local-request"), ("event_route", "topos:msg-sending")]
        if cls.rtp_enabled:
            route_names.extend([("route", "SET_RTP_DIRECTION"), ("route", "RTP_FAILURE"),
                                ("onreply_route", "MANAGE_REPLY"), ("failure_route", "MANAGE_FAILURE")])
        blocks = "\n".join(production_block(source, kind, name) for kind, name in route_names)
        config = """#!KAMAILIO
{definitions}
{lan_define}
#!define WITH_NAT
{rtp_define}
#!define PUBLIC_IP "{public}"
#!define PRIVATE_IP "{private}"
#!define SERVICE_IP "{service}"
#!define LOCALNETWORKS "{local_networks}"
#!define INTERNAL_NETWORK "127.20.0.0/24"
#!define DEFAULT_REPLY_CODE 480
debug=2
log_stderror=yes
children=1
tcp_children=1
auto_aliases=no
enable_tls=yes
mpath="/usr/lib/x86_64-linux-gnu/kamailio/modules/"
loadmodule "tls.so"
loadmodule "corex.so"
loadmodule "tm.so"
loadmodule "tmx.so"
loadmodule "sl.so"
loadmodule "pv.so"
loadmodule "xlog.so"
loadmodule "ipops.so"
loadmodule "textops.so"
loadmodule "textopsx.so"
loadmodule "siputils.so"
loadmodule "rr.so"
loadmodule "dialog.so"
loadmodule "ndb_redis.so"
loadmodule "topos.so"
loadmodule "topos_redis.so"
loadmodule "keepalive.so"
loadmodule "nathelper.so"
loadmodule "kex.so"
{rtp_modules}
modparam("tls", "config", "{tls_config}")
modparam("pv", "shvset", "debug=i:0")
modparam("rr", "enable_full_lr", 1)
modparam("rr", "append_fromtag", 1)
modparam("rr", "enable_double_rr", 1)
modparam("ndb_redis", "server", "name=srv1;addr=127.0.0.1;port=6379;db=0")
modparam("topos", "storage", "redis")
modparam("topos_redis", "serverid", "srv1")
modparam("keepalive", "ping_interval", 1)
modparam("nathelper", "received_avp", "$avp(RECEIVED)")
{rtp_parameters}
{probe_config}
{listeners}
request_route {{
    force_rport();
    if ($rU == "health") {{ sl_send_reply("200", "OK"); exit; }}
#!ifdef WITH_RTPENGINE
    dlg_manage();
    if (!is_method("UPDATE")) {{
        $avp(direction) = "in";
        if (is_in_subnet($si, INTERNAL_NETWORK) || $si == "127.0.0.1") $avp(direction) = "out";
        $dlg_var(direction) = $avp(direction);
        $dlg_var(source_ip) = $si;
    }}
    if (is_method("CANCEL")) {{
        if (t_check_trans()) route(RELAY);
        exit;
    }}
#!endif
    if (has_totag()) {{
        if (!loose_route()) {{ sl_send_reply("404", "Missing route"); exit; }}
        route(DLGURI);
        if (is_method("ACK")) route(NATMANAGE);
    }} else if (is_method("INVITE|SUBSCRIBE|PUBLISH|NOTIFY|UPDATE")) {{
        setflag(FLT_RECORD_ROUTE);
        setflag(FLT_NATS);
    }}
    if ($hdr(X-Test-Destination) != $null) $du = $hdr(X-Test-Destination);
    if (!has_totag() && $hdr(X-Test-Branch) != $null) append_branch("$hdr(X-Test-Branch)");
    route(RELAY);
}}
{reply_route}
#!ifdef WITH_RTPENGINE
route[DISPATCHER_FAILURE] {{ return; }}
#!else
failure_route[MANAGE_FAILURE] {{
    if (t_check_status("503") && $hdr(X-Test-Failover) != $null && $avp(failed_over) != 1) {{
        $avp(failed_over) = 1;
        $du = $hdr(X-Test-Failover);
        route(RELAY);
    }}
}}
#!endif
{blocks}
include_file "{routing}"
""".format(definitions=definitions, lan_define="#!define WITH_LAN_SOCKETS" if cls.behind_nat else "",
           public=PUBLIC, private=PROXY if cls.behind_nat else "", service=SERVICE, tls_config=tls_config,
           rtp_define="#!define WITH_RTPENGINE" if cls.rtp_enabled else "",
           rtp_modules='loadmodule "rtpengine.so"\nloadmodule "sdpops.so"' if cls.rtp_enabled else "",
           rtp_parameters=('modparam("rtpengine", "rtpengine_sock", "udp:127.0.0.1:{}")\n'
                           'modparam("dialog", "profiles_with_value", "remote_sig")\n'
                           'modparam("pv", "shvset", "rtpengine=s:t")').format(
                               19999 if cls.behind_nat else 29999) if cls.rtp_enabled else "",
           reply_route="" if cls.rtp_enabled else "onreply_route[MANAGE_REPLY] { return; }",
           local_networks=cls.local_networks if cls.local_networks is not None else (
               "127.10.0.0/24,127.20.0.0/24" if cls.behind_nat else ""),
           probe_config="\n".join('modparam("keepalive", "destination", "{}")'.format(peer.contact) for peer in cls.probes.values()),
           listeners=cls.listeners(), blocks=blocks, routing=CONFIG / "sip-routing.cfg")
        cls.config = cls.directory / "kamailio.cfg"
        cls.config.write_text(config)
        validation = subprocess.run([cls.kamailio, "-c", "-f", str(cls.config)], stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, timeout=15)
        if validation.returncode:
            raise AssertionError(validation.stdout + "\n" + "\n".join(
                "{}: {}".format(index, line) for index, line in enumerate(config.splitlines(), 1)))
        cls.log = open(cls.directory / "kamailio.log", "w+")
        cls.addClassCleanup(cls.log.close)
        cls.process = subprocess.Popen([cls.kamailio, "-DD", "-E", "-f", str(cls.config), "-m", "32", "-M", "8"],
                                       stdout=cls.log, stderr=subprocess.STDOUT, start_new_session=True)
        cls.addClassCleanup(cls.stop)
        cls.proxy_ip = PROXY if cls.behind_nat else PUBLIC
        deadline = time.monotonic() + 10
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as health:
            health.settimeout(0.2)
            while time.monotonic() < deadline:
                if cls.process.poll() is not None:
                    cls.log.seek(0)
                    raise AssertionError(cls.log.read())
                health.sendto(b"OPTIONS sip:health@localhost SIP/2.0\r\nVia: SIP/2.0/UDP 127.0.0.1:9;rport;branch=z9hG4bKhealth\r\nFrom: <sip:health@localhost>;tag=h\r\nTo: <sip:health@localhost>\r\nCall-ID: health\r\nCSeq: 1 OPTIONS\r\nContent-Length: 0\r\n\r\n", (cls.proxy_ip, 5060))
                try:
                    health.recvfrom(4096)
                    break
                except socket.timeout:
                    pass
            else:
                raise AssertionError("Kamailio did not become ready")

    @classmethod
    def listeners(cls):
        items = []
        for transport, port in (("udp", 5060), ("tcp", 5060), ("tls", 5061)):
            items.append("listen={}:127.0.0.1:{}".format(transport, port))
            if cls.behind_nat:
                items.append("listen={}:{}:{} advertise {}:{}".format(transport, PROXY, port, PUBLIC, port))
                items.append("listen={}:{}:{} advertise {}:{}".format(transport, PROXY, port + 1000, PROXY, port))
            else:
                items.append("listen={}:{}:{}".format(transport, PUBLIC, port))
            items.append("listen={}:{}:{}".format(transport, SERVICE, port))
        return "\n".join(items)

    @classmethod
    def stop(cls):
        if cls.process.poll() is None:
            os.killpg(cls.process.pid, signal.SIGTERM)
            try:
                cls.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(cls.process.pid, signal.SIGKILL)
                cls.process.wait(timeout=5)

    def peer(self, address, transport="udp", server=False):
        peer = Peer(address, transport, self.certificate, server)
        self.addCleanup(peer.close)
        return peer

    def request(self, peer, method, target, call_id, sequence=1, to_tag="", extra="", from_value=None, to_value=None, body=""):
        if body:
            extra += "Content-Type: application/sdp\r\n"
        return ("{method} {target} SIP/2.0\r\n"
                "Via: SIP/2.0/{transport} {ip}:{port};rport;branch=z9hG4bK{branch}\r\n"
                "From: {from_value}\r\nTo: {to_value}\r\n"
                "Call-ID: {call_id}\r\nCSeq: {sequence} {method}\r\nMax-Forwards: 70\r\n"
                "Contact: <{contact}>\r\n{extra}Content-Length: {length}\r\n\r\n{body}").format(
                    method=method, target=target, transport=peer.transport.upper(), ip=peer.address[0],
                    port=peer.address[1], branch=uuid.uuid4().hex,
                    from_value=from_value or "<sip:caller@{}>;tag=caller".format(peer.address[0]),
                    to_value=to_value or "<sip:callee@{}>{}".format(PBX, to_tag),
                    call_id=call_id, sequence=sequence, contact=peer.contact, extra=extra,
                    length=len(body.encode()), body=body)

    def dialog(self, caller_ip=LAN, caller_transport="udp", callee_ip=PBX, callee_transport="udp",
               redirected=False, destination=None, reverse_bye=False, failover=False):
        caller = self.peer(caller_ip, caller_transport)
        callee = self.peer(callee_ip, callee_transport, server=True)
        proxy = (SERVICE if caller_ip == PBX else self.proxy_ip,
                 (5061 if caller_transport == "tls" else 5060) + (1000 if redirected else 0))
        caller.connect(proxy)
        call_id = uuid.uuid4().hex
        target, extra = callee.contact, ""
        if destination:
            next_hop = callee.contact
            if destination == "sips":
                next_hop = next_hop.replace("sip:", "sips:").split(";transport=")[0]
            target = "sip:callee@{}:9;transport=udp".format(WAN)
            extra = "X-Test-Destination: {}\r\n".format(next_hop)
        if failover:
            rejected = self.peer(WAN)
            target = rejected.contact
            extra = "X-Test-Failover: {}\r\n".format(callee.contact)
        caller.send(self.request(caller, "INVITE", target, call_id, extra=extra), proxy)
        if failover:
            first, first_source = rejected.receive()
            self.assertIn("@" + PUBLIC, header(first, "Contact"))
            rejected.send(response(first).replace("200 OK", "503 Service Unavailable", 1), first_source)
        invite, source = callee.receive()
        self.assertTrue(invite.startswith("INVITE "), invite)
        expected_bind = SERVICE if callee_ip == PBX else self.proxy_ip
        expected_port = 5061 if callee_transport == "tls" else 5060
        if self.behind_nat and callee_ip == LAN:
            expected_port += 1000
        self.assertEqual(source[0], expected_bind)
        if callee_transport == "udp":
            self.assertEqual(source[1], expected_port)
        expected_destination_contact = SERVICE if callee_ip == PBX else (PROXY if self.behind_nat and callee_ip == LAN else PUBLIC)
        self.assert_contact(invite, expected_destination_contact, callee_transport)
        callee.send(response(invite, callee.contact), source)
        answered, response_source = caller.receive_final()
        self.assertTrue(answered.startswith("SIP/2.0 200"), answered)
        expected_source_contact = SERVICE if caller_ip == PBX else (PROXY if self.behind_nat and caller_ip == LAN else PUBLIC)
        self.assert_contact(answered, expected_source_contact, caller_transport)
        if caller_transport == "udp":
            self.assertEqual(response_source, proxy)
        contact = uri(header(answered, "Contact"))
        caller.send(self.request(caller, "ACK", contact, call_id, to_tag=";tag=test-peer"), proxy)
        ack, _ = callee.receive()
        self.assertTrue(ack.startswith("ACK "), ack)
        self.assertEqual(header(ack, "Call-ID"), call_id)
        if reverse_bye:
            contact = uri(header(invite, "Contact"))
            callee.send(self.request(callee, "BYE", contact, call_id, sequence=2,
                                    from_value=header(answered, "To"), to_value=header(invite, "From")),
                        (expected_bind, 5061 if callee_transport == "tls" else 5060))
            bye, source = caller.receive()
            self.assertTrue(bye.startswith("BYE "), bye)
            caller.send(response(bye), source)
            closed, _ = callee.receive_final()
            self.assertTrue(closed.startswith("SIP/2.0 200"), closed)
            self.assertEqual(header(closed, "CSeq"), "2 BYE")
            return
        caller.send(self.request(caller, "BYE", contact, call_id, sequence=2, to_tag=";tag=test-peer"), proxy)
        bye, source = callee.receive()
        self.assertTrue(bye.startswith("BYE "), bye)
        callee.send(response(bye), source)
        closed, _ = caller.receive_final()
        self.assertTrue(closed.startswith("SIP/2.0 200"), closed)
        self.assertEqual(header(closed, "CSeq"), "2 BYE")

    def assert_contact(self, message, address, transport):
        contact = uri(header(message, "Contact"))
        port = 5061 if transport == "tls" else 5060
        self.assertRegex(contact, r"^sips?:[^@]+@" + re.escape(address) + r"(?::" + str(port) + r")?(?:;|$)")
        if transport != "udp":
            self.assertIn(";transport=" + transport, contact)

    def tearDown(self):
        # Keep failures diagnosable after the disposable test environment exits.
        errors = getattr(self._outcome, "errors", None)
        if errors is None:
            errors = self._outcome.result.errors + self._outcome.result.failures
        failed = any(test is self and error is not None for test, error in errors)
        if failed:
            self.log.flush()
            self.log.seek(0)
            print(self.log.read(), file=sys.stderr)


class SipRoutingTests(KamailioRoutingTestCase):
    def test_00_locally_generated_options(self):
        for network, peer in self.probes.items():
            with self.subTest(network=network):
                message, address = peer.receive()
                self.assertTrue(message.startswith("OPTIONS "), message)
                expected_ip = SERVICE if network == "internal" else self.proxy_ip
                if network == "loopback":
                    expected_ip = "127.0.0.1"
                expected_port = 6060 if self.behind_nat and network == "local" else 5060
                self.assertEqual(address, (expected_ip, expected_port))
                advertised = SERVICE if network == "internal" else (PROXY if self.behind_nat and network == "local" else PUBLIC)
                if network == "loopback":
                    advertised = "127.0.0.1"
                self.assertRegex(header(message, "Via"), r"^SIP/2.0/UDP " + re.escape(advertised) + r"(?::5060)?;")

    def test_lan_invite_without_redirect(self):
        self.dialog()

    def test_lan_tcp_invite_without_redirect(self):
        self.dialog(caller_transport="tcp")

    def test_lan_tls_invite_without_redirect(self):
        self.dialog(caller_transport="tls")

    def test_wan_invite(self):
        self.dialog(caller_ip=WAN)

    def test_pbx_to_lan(self):
        self.dialog(caller_ip=PBX, callee_ip=LAN)

    def test_pbx_to_lan_tcp(self):
        self.dialog(caller_ip=PBX, callee_ip=LAN, callee_transport="tcp")

    def test_pbx_to_lan_tls(self):
        self.dialog(caller_ip=PBX, callee_ip=LAN, callee_transport="tls")

    def test_pbx_to_wan(self):
        self.dialog(caller_ip=PBX, callee_ip=WAN)

    def test_lan_callee_hangup(self):
        self.dialog(reverse_bye=True)

    def test_lan_tcp_callee_hangup(self):
        self.dialog(caller_transport="tcp", reverse_bye=True)

    def test_lan_tls_callee_hangup(self):
        self.dialog(caller_transport="tls", reverse_bye=True)

    def test_destination_uri_transport_takes_precedence(self):
        self.dialog(caller_ip=PBX, callee_ip=LAN, callee_transport="tcp", destination="sip")

    def test_sips_destination_uri_selects_tls(self):
        self.dialog(caller_ip=PBX, callee_ip=LAN, callee_transport="tls", destination="sips")

    def test_failover_reselects_socket_and_record_route(self):
        self.dialog(failover=True)

    def test_parallel_branches_select_their_own_socket(self):
        caller = self.peer(LAN)
        first, second = self.peer(PBX), self.peer(WAN)
        proxy = (self.proxy_ip, 5060)
        call_id = uuid.uuid4().hex
        caller.send(self.request(caller, "INVITE", first.contact, call_id,
                                 extra="X-Test-Branch: {}\r\n".format(second.contact)), proxy)
        for peer, expected_bind, advertised in ((first, SERVICE, SERVICE), (second, self.proxy_ip, PUBLIC)):
            invite, address = peer.receive()
            self.assertEqual(address, (expected_bind, 5060))
            self.assert_contact(invite, advertised, "udp")
            peer.send(response(invite).replace("200 OK", "486 Busy Here", 1), address)
        busy, _ = caller.receive_final()
        self.assertTrue(busy.startswith("SIP/2.0 486"), busy)

    def test_redirected_lan_invite(self):
        if not self.behind_nat:
            self.skipTest("No redirect listeners in the public-address deployment")
        self.dialog(redirected=True)


class PublicAddressRoutingTests(SipRoutingTests):
    behind_nat = False


@unittest.skipUnless(os.environ.get("SIP_TEST_ISOLATED") == "1", "Use tests/run-sip-routing-tests.sh")
class BootstrapConfigurationTests(unittest.TestCase):
    def test_full_production_configuration_with_and_without_nat(self):
        # Bootstrap renders the real templates, but a local shim prevents it
        # from starting a server. The real binary validates the result below.
        kamailio = shutil.which("kamailio")
        with tempfile.TemporaryDirectory(prefix="sip-bootstrap-") as directory:
            shim = Path(directory) / "kamailio"
            shim.write_text("#!/bin/sh\nexit 0\n")
            shim.chmod(0o755)
            for behind_nat in (True, False):
                with self.subTest(behind_nat=behind_nat):
                    environment = dict(os.environ, PATH=directory + ":" + os.environ["PATH"], ENV="", ENVIRONMENT="test",
                                       BEHIND_NAT="true" if behind_nat else "false", PRIVATE_IP=PROXY if behind_nat else "",
                                       PUBLIC_IP=PUBLIC, SERVICE_IP=SERVICE, SERVICE_NET="127.20.0.0/24",
                                       LOCALNETWORKS="127.10.0.0/24" if behind_nat else "",
                                       POSTGRES_USER="test", POSTGRES_PASSWORD="test", POSTGRES_HOST="127.0.0.1",
                                       POSTGRES_PORT="5432", POSTGRES_DB="test", REDIS_HOST="127.0.0.1", REDIS_PORT="6379",
                                       KML_SIP_URL="proxy.test", KML_UA_HEADER="Test", KML_SERVER_HEADER="Test",
                                       DEFAULT_CONTACT="sip:test@proxy.test")
                    subprocess.run(["bash", "/bootstrap.sh"], env=environment, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, check=True, timeout=15)
                    checked = subprocess.run([kamailio, "-c", "-f", "/etc/kamailio/kamailio.cfg"],
                                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=15)
                    self.assertEqual(checked.returncode, 0, checked.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
