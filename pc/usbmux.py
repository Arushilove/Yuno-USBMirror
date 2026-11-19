"""usbmuxd ke saath baat karne ke helper (iPhone ko USB par dhoondhna aur uske port se connect karna)."""

import plistlib
import socket
import struct
import sys

USBMUXD_TCP = ("127.0.0.1", 27015)   # Windows
USBMUXD_UNIX = "/var/run/usbmuxd"    # macOS / Linux

# Header: length, version, request type, tag (4 x uint32, little-endian)
HEADER = struct.Struct("<IIII")
VERSION_PLIST = 1
REQUEST_PLIST = 8
PROG = "iphone-usb-mirror"


def open_socket():
    if sys.platform == "win32":
        return socket.create_connection(USBMUXD_TCP, timeout=5)
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(5)
    sock.connect(USBMUXD_UNIX)
    return sock


def recv_exact(sock, n):
    data = bytearray()
    while len(data) < n:
        chunk = sock.recv(n - len(data))
        if not chunk:
            raise ConnectionError("connection band ho gaya")
        data += chunk
    return bytes(data)


def send_plist(sock, payload, tag=1):
    body = plistlib.dumps(payload)
    sock.sendall(HEADER.pack(HEADER.size + len(body), VERSION_PLIST, REQUEST_PLIST, tag) + body)


def recv_plist(sock):
    length, _v, _r, _t = HEADER.unpack(recv_exact(sock, HEADER.size))
    return plistlib.loads(recv_exact(sock, length - HEADER.size))


def list_devices():
    """USB se jude devices ki list (har item me DeviceID aur SerialNumber/UDID)."""
    sock = open_socket()
    try:
        send_plist(sock, {
            "MessageType": "ListDevices",
            "ClientVersionString": PROG,
            "ProgName": PROG,
        })
        reply = recv_plist(sock)
    finally:
        sock.close()
    devices = []
    for d in reply.get("DeviceList", []):
        props = d.get("Properties", {})
        if props.get("ConnectionType", "USB") == "USB":
            devices.append(props)
    return devices


def connect_to_device(device_id, port):
    """iPhone ke `port` par TCP tunnel kholo. Kaamyab hone par raw socket milta hai."""
    sock = open_socket()
    send_plist(sock, {
        "MessageType": "Connect",
        "ClientVersionString": PROG,
        "ProgName": PROG,
        "DeviceID": device_id,
        "PortNumber": socket.htons(port),
    })
    reply = recv_plist(sock)
    code = reply.get("Number", -1)
    if code != 0:
        sock.close()
        reasons = {
            2: "device connected nahi hai",
            3: "iPhone ne port refuse kiya (broadcast start kiya hai?)",
            5: "bad version",
        }
        raise ConnectionError(f"Connect fail (code {code}): {reasons.get(code, 'unknown')}")
    sock.settimeout(None)
    return sock
