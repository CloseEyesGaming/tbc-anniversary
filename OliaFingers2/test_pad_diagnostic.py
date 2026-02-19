import time
import sys

# --- DIAGNOSTIC CONFIG ---
FAILING_KEYS = [
    "PAD5", "PAD6",
    "PADLSTICKUP", "PADLSTICKRIGHT", "PADLSTICKDOWN", "PADLSTICKLEFT",
    "PADRSTICKUP", "PADRSTICKRIGHT", "PADRSTICKDOWN", "PADRSTICKLEFT",
    "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4"
]

try:
    # We now import normalize_key to prevent the 'modifiers' KeyError
    from main import execute_action, normalize_key
except ImportError:
    print("Error: Ensure main.py is in this directory.")
    sys.exit(1)

print("--- STARTING PAD DIAGNOSTIC ---")
print("I will fire one button every 3 seconds.")
print("Watch your WoW Chat for '[SNIFFER] Pressed: ...'")
print("-------------------------------")

for key in FAILING_KEYS:
    print(f"Firing Signal: {key}...")

    # Use the official normalization function to build the full data structure
    action_data = normalize_key(key)
    action_data['name'] = 'DIAGNOSTIC'

    # Now it contains ['modifiers'], ['type'], and ['key'] properly
    execute_action(action_data)
    time.sleep(3)

print("--- DIAGNOSTIC COMPLETE ---")