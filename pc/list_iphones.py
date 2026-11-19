"""USB se jude iPhones ki list dikhao.  Run: python list_iphones.py"""

import sys
from usbmux import list_devices

try:
    devices = list_devices()
except OSError as e:
    print(f"usbmuxd se connect nahi ho paya: {e}")
    print("Apple Mobile Device Support install hai? 'Apple Mobile Device Service' chal rahi hai?")
    sys.exit(1)

if not devices:
    print("Koi iPhone nahi mila. Cable lagao, unlock karo, 'Trust' dabao.")
else:
    for d in devices:
        print(f"DeviceID={d.get('DeviceID')}  UDID={d.get('SerialNumber')}")
