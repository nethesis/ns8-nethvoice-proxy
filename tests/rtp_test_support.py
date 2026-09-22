"""Small standard-library clients for the isolated SIP/RTP integration tests."""

import select
import socket
import struct
import time
import uuid


def bencode(value):
    """Encode the NG protocol subset: dictionaries, lists, integers and strings."""
    if isinstance(value, str):
        value = value.encode("utf-8")
    if isinstance(value, bytes):
        return str(len(value)).encode("ascii") + b":" + value
    if isinstance(value, bool):
        value = int(value)
    if isinstance(value, int):
        return b"i" + str(value).encode("ascii") + b"e"
    if isinstance(value, (list, tuple)):
        return b"l" + b"".join(bencode(item) for item in value) + b"e"
    if isinstance(value, dict):
        keys = sorted(value, key=lambda key: key.encode("utf-8") if isinstance(key, str) else key)
        return b"d" + b"".join(bencode(key) + bencode(value[key]) for key in keys) + b"e"
    raise TypeError("Unsupported bencode value: {!r}".format(type(value)))


def bdecode(data):
    """Decode an NG reply, returning text strings where UTF-8 is valid."""
    position = 0

    def parse():
        nonlocal position
        if position >= len(data):
            raise ValueError("Truncated bencode value")
        marker = data[position:position + 1]
        if marker == b"i":
            end = data.index(b"e", position + 1)
            number = int(data[position + 1:end])
            position = end + 1
            return number
        if marker in (b"l", b"d"):
            position += 1
            output = [] if marker == b"l" else {}
            while position < len(data) and data[position:position + 1] != b"e":
                item = parse()
                if marker == b"l":
                    output.append(item)
                else:
                    output[item] = parse()
            if position >= len(data):
                raise ValueError("Unterminated bencode collection")
            position += 1
            return output
        if b"0" <= marker <= b"9":
            colon = data.index(b":", position)
            length = int(data[position:colon])
            position = colon + 1
            end = position + length
            if end > len(data):
                raise ValueError("Truncated bencode string")
            value = data[position:end]
            position = end
            try:
                return value.decode("utf-8")
            except UnicodeDecodeError:
                return value
        raise ValueError("Invalid bencode marker {!r}".format(marker))

    value = parse()
    if position != len(data):
        raise ValueError("Trailing bytes after bencode value")
    return value


class RtpEngineControl:
    """Synchronous, cookie-checked RTPEngine NG UDP control client."""

    def __init__(self, port, address="127.0.0.1", timeout=2):
        self.target = (address, port)
        self.timeout = timeout

    def request(self, command, **fields):
        cookie = uuid.uuid4().hex.encode("ascii")
        message = dict(fields)
        message["command"] = command
        request = cookie + b" " + bencode(message)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as connection:
            connection.connect(self.target)
            connection.settimeout(self.timeout)
            connection.send(request)
            deadline = time.monotonic() + self.timeout
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError("No NG reply for {!r}".format(command))
                connection.settimeout(remaining)
                reply = connection.recv(65535)
                reply_cookie, separator, payload = reply.partition(b" ")
                if separator and reply_cookie == cookie:
                    result = bdecode(payload)
                    if not isinstance(result, dict):
                        raise ValueError("NG reply is not a dictionary")
                    return result

    def wait_ready(self, timeout=10):
        deadline = time.monotonic() + timeout
        last_error = None
        while time.monotonic() < deadline:
            try:
                result = self.request("ping")
                if result.get("result") == "pong":
                    return result
                last_error = result
            except (OSError, ValueError, TimeoutError) as error:
                last_error = error
            time.sleep(0.05)
        raise TimeoutError("RTPEngine NG did not become ready: {}".format(last_error))

    def query(self, call_id):
        return self.request("query", **{"call-id": call_id})

    def delete(self, call_id):
        return self.request("delete", **{"call-id": call_id, "delete-delay": 0})


def parse_sdp(message):
    """Read the first audio media section of SDP or a complete SIP message."""
    if isinstance(message, bytes):
        message = message.decode("utf-8")
    if "\r\n\r\n" in message:
        message = message.split("\r\n\r\n", 1)[1]
    elif "\n\n" in message:
        message = message.split("\n\n", 1)[1]
    result = {"sdp": message, "direction": "sendrecv"}
    in_audio = False
    saw_media = False
    for line in message.splitlines():
        if line.startswith("o="):
            fields = line[2:].split()
            if len(fields) >= 6:
                result["origin_address"] = fields[5]
        elif line.startswith("m="):
            fields = line[2:].split()
            if in_audio:
                break
            saw_media = True
            in_audio = fields[0] == "audio"
            if in_audio:
                result.update(port=int(fields[1].split("/")[0]), transport=fields[2],
                              payloads=tuple(int(item) for item in fields[3:]))
        elif line.startswith("c=IN IP4 ") and (in_audio or not saw_media):
            result["address"] = line[len("c=IN IP4 "):].split("/")[0]
        elif line.startswith("a=rtcp:") and in_audio:
            fields = line[len("a=rtcp:"):].split()
            result["rtcp_port"] = int(fields[0])
            if len(fields) >= 4:
                result["rtcp_address"] = fields[3]
        elif line in ("a=sendrecv", "a=sendonly", "a=recvonly", "a=inactive") and (in_audio or not saw_media):
            result["direction"] = line[2:]
    if "port" not in result or "address" not in result:
        raise ValueError("SDP has no IPv4 audio destination: {!r}".format(message))
    result.setdefault("rtcp_port", result["port"] + 1)
    result.setdefault("rtcp_address", result["address"])
    return result


def parse_rtp(packet):
    """Extract the RTP header and payload, accounting for CSRCs and extensions."""
    if len(packet) < 12 or packet[0] >> 6 != 2:
        raise ValueError("Invalid RTP packet")
    flags, marker_payload, sequence, timestamp, ssrc = struct.unpack("!BBHII", packet[:12])
    offset = 12 + 4 * (flags & 15)
    if flags & 16:
        if len(packet) < offset + 4:
            raise ValueError("Truncated RTP extension")
        extension_words = struct.unpack("!H", packet[offset + 2:offset + 4])[0]
        offset += 4 + extension_words * 4
    if offset > len(packet):
        raise ValueError("Truncated RTP header")
    end = len(packet)
    if flags & 32:
        padding = packet[-1]
        if not padding or padding > end - offset:
            raise ValueError("Invalid RTP padding")
        end -= padding
    return {"payload_type": marker_payload & 127, "marker": bool(marker_payload & 128),
            "sequence": sequence, "timestamp": timestamp, "ssrc": ssrc,
            "payload": packet[offset:end]}


class MediaPeer:
    """A clear-RTP test endpoint with an even RTP port and adjacent RTCP port."""

    def __init__(self, address):
        self.address = address
        self.ssrc = uuid.uuid4().int & 0xffffffff
        self.rtp = None
        self.rtcp = None
        for _ in range(100):
            rtp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            rtcp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                rtp.bind((address, 0))
                port = rtp.getsockname()[1]
                if port % 2 or port == 65535:
                    continue
                rtcp.bind((address, port + 1))
                self.rtp, self.rtcp = rtp, rtcp
                self.port, self.rtcp_port = port, port + 1
                break
            except OSError:
                pass
            finally:
                if self.rtp is not rtp:
                    rtp.close()
                    rtcp.close()
        if self.rtp is None:
            raise OSError("Cannot allocate RTP/RTCP ports on {}".format(address))

    def sdp(self, version=1, direction="sendrecv", transport="RTP/AVP", payloads=(8, 101)):
        if direction not in ("sendrecv", "sendonly", "recvonly", "inactive"):
            raise ValueError("Invalid SDP direction")
        lines = ["v=0", "o=test {} {} IN IP4 {}".format(self.ssrc, version, self.address),
                 "s=Local RTP routing test", "c=IN IP4 {}".format(self.address), "t=0 0",
                 "m=audio {} {} {}".format(self.port, transport, " ".join(map(str, payloads))),
                 "a=rtcp:{} IN IP4 {}".format(self.rtcp_port, self.address)]
        if 8 in payloads:
            lines.append("a=rtpmap:8 PCMA/8000")
        if 0 in payloads:
            lines.append("a=rtpmap:0 PCMU/8000")
        if 101 in payloads:
            lines.extend(["a=rtpmap:101 telephone-event/8000", "a=fmtp:101 0-16"])
        lines.extend(["a=ptime:20", "a=" + direction])
        return "\r\n".join(lines) + "\r\n"

    def send_rtp(self, target, sequence=1, timestamp=None, ssrc=None, payload=None):
        if timestamp is None:
            timestamp = sequence * 160
        if ssrc is None:
            ssrc = self.ssrc
        if payload is None:
            payload = bytes([0xd5]) * 160
        packet = struct.pack("!BBHII", 0x80, 8, sequence & 0xffff,
                             timestamp & 0xffffffff, ssrc & 0xffffffff) + payload
        self.rtp.sendto(packet, target)
        return packet

    def receive_rtp(self, timeout=2):
        self.rtp.settimeout(timeout)
        return self.rtp.recvfrom(65535)

    def close(self):
        if self.rtp is not None:
            self.rtp.close()
        if self.rtcp is not None:
            self.rtcp.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


def assert_bidirectional_rtp(peer_a, target_a, peer_b, target_b, timeout=3):
    """Prove PCMA delivery both ways, allowing RTPEngine endpoint learning.

    ``target_a`` is the rewritten SDP destination received by peer A; likewise B.
    Payload markers identify this exchange independently of SSRC rewriting.
    """
    marker = uuid.uuid4().bytes
    payload_a = (b"a" + marker) * 9 + b"a" * 7
    payload_b = (b"b" + marker) * 9 + b"b" * 7
    expected = {peer_a.rtp: payload_b, peer_b.rtp: payload_a}
    received = {}
    deadline = time.monotonic() + timeout
    sequence = 1
    next_send = 0
    while time.monotonic() < deadline and len(received) < 2:
        now = time.monotonic()
        if now >= next_send:
            peer_a.send_rtp(target_a, sequence=sequence, payload=payload_a)
            peer_b.send_rtp(target_b, sequence=sequence, payload=payload_b)
            sequence += 1
            next_send = now + 0.02
        ready, _, _ = select.select(list(expected), [], [], min(0.02, max(0, deadline - now)))
        for stream in ready:
            packet, source = stream.recvfrom(65535)
            try:
                parsed = parse_rtp(packet)
            except ValueError:
                continue
            if parsed["payload_type"] == 8 and parsed["payload"] == expected[stream]:
                received[stream] = {"source": source, "rtp": parsed}
    if len(received) != 2:
        raise AssertionError("RTP did not pass both ways: A received={}, B received={}, "
                             "A target={!r}, B target={!r}".format(
                                 peer_a.rtp in received, peer_b.rtp in received, target_a, target_b))
    return {"a": received[peer_a.rtp], "b": received[peer_b.rtp]}
