import time
from core import input_driver

print("3... Click WoW Window!")
time.sleep(1)
print("2...")
time.sleep(1)
print("1...")
time.sleep(1)

print("Sending ALT-F5...")
input_driver.trigger_hotkey("ALT-F5")
print("Sent.")