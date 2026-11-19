"""
iPhone ki screen USB par dekhne wala PC viewer.

Pehle iPhone par broadcast start karo, phir:
    python mirror_viewer.py
Band karne ke liye window par  q  ya  Esc  dabao.
"""

import argparse
import struct
import sys
import threading
import time

import av
import cv2

from usbmux import connect_to_device, list_devices, recv_exact

latest = None            # sabse naya decoded frame (BGR numpy array)
latest_lock = threading.Lock()
stop = threading.Event()
error = None


def reader(sock):
    """Socket se frames padho, decode karo, `latest` me rakho."""
    global latest, error
    codec = av.CodecContext.create("h264", "r")
    codec.thread_type = "SLICE"          # frame-threading band: latency kam
    try:
        while not stop.is_set():
            (size,) = struct.unpack(">I", recv_exact(sock, 4))
            if size == 0 or size > 20_000_000:
                raise ValueError(f"galat frame size: {size}")
            data = recv_exact(sock, size)
            try:
                for frame in codec.decode(av.Packet(data)):
                    img = frame.to_ndarray(format="bgr24")
                    with latest_lock:
                        latest = img
            except av.AVError:
                continue                 # kharab frame, agle keyframe tak chhod do
    except Exception as e:               # noqa: BLE001
        error = e
    finally:
        stop.set()


def main():
    global latest
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=5000, help="iPhone extension ka port (default 5000)")
    ap.add_argument("--height", type=int, default=800, help="window ki height")
    args = ap.parse_args()

    try:
        devices = list_devices()
    except OSError as e:
        sys.exit(f"usbmuxd se connect nahi ho paya: {e}")
    if not devices:
        sys.exit("Koi iPhone nahi mila. Cable, unlock aur Trust check karo.")

    dev = devices[0]
    print(f"iPhone mila: {dev.get('SerialNumber')}")

    try:
        sock = connect_to_device(dev["DeviceID"], args.port)
    except ConnectionError as e:
        sys.exit(str(e))
    print("Connected. Window me frame ka intezaar...")

    threading.Thread(target=reader, args=(sock,), daemon=True).start()

    win = "iPhone (USB)"
    cv2.namedWindow(win, cv2.WINDOW_NORMAL)
    sized = False
    frames, t0 = 0, time.time()

    while not stop.is_set():
        with latest_lock:
            img, latest = latest, None
        if img is not None:
            if not sized:
                h, w = img.shape[:2]
                cv2.resizeWindow(win, int(args.height * w / h), args.height)
                sized = True
            cv2.imshow(win, img)
            frames += 1
            if time.time() - t0 >= 2:
                print(f"{frames / (time.time() - t0):.1f} fps")
                frames, t0 = 0, time.time()
        key = cv2.waitKey(5) & 0xFF
        if key in (ord("q"), 27):
            break
        if cv2.getWindowProperty(win, cv2.WND_PROP_VISIBLE) < 1 and sized:
            break

    stop.set()
    sock.close()
    cv2.destroyAllWindows()
    if error:
        print(f"Stream ruk gayi: {error}")


if __name__ == "__main__":
    main()
