import sys
import os

print("--- 1. CHECKING LIBRARIES ---")

# Check Keyboard
try:
    import keyboard

    print("[PASS] 'keyboard' library found.")
except ImportError:
    print("[FAIL] 'keyboard' library MISSING. Run: pip install keyboard")

# Check vgamepad
has_vgamepad = False
try:
    import vgamepad as vg

    # Try to initialize to ensure drivers are present
    try:
        temp_pad = vg.VX360Gamepad()
        print("[PASS] 'vgamepad' library found AND Virtual Controller created.")
        has_vgamepad = True
    except Exception as e:
        print(f"[FAIL] 'vgamepad' installed but DRIVER FAILED: {e}")
        print("       (Did you install the ViGEmBus driver?)")
except ImportError:
    print("[FAIL] 'vgamepad' library MISSING.")
    print("       To fix: pip install vgamepad")

print("\n--- 2. SIMULATING KEY RECOGNITION ---")

# Specific Gamepad keys from your log
test_keys = [
    "PAD1", "PAD2", "PADDUP", "PADDRIGHT",
    "PADLSTICK", "PADLSTICKUP", "PADSYSTEM"
]


# Minimal version of the logic in main.py to test recognition
def simulate_recognition(lua_key):
    lua_key = lua_key.upper().strip()

    # 1. Check Gamepad Availability
    if has_vgamepad:
        # Check against our map (Simplified for test)
        # Note: In main.py this map is fuller, here we just check if it WOULD work
        known_gamepad_keys = [
            "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6",
            "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
            "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4",
            "PADLSTICK", "PADRSTICK",
            "PADLSTICKUP", "PADLSTICKDOWN", "PADLSTICKLEFT", "PADLSTICKRIGHT",
            "PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT",
            "PADSYSTEM", "PADSOCIAL", "PADFORWARD"
        ]

        if lua_key in known_gamepad_keys:
            return "GAMEPAD (Virtual Xbox 360)"

    # 2. Fallback to Keyboard
    return "KEYBOARD (Standard)"


print(f"{'INPUT KEY':<15} | {'SYSTEM STATUS':<15} | {'RESULT'}")
print("-" * 60)

for k in test_keys:
    result = simulate_recognition(k)
    status = "Active" if has_vgamepad else "MISSING LIB"

    # Logic check
    if result == "KEYBOARD (Standard)" and "PAD" in k:
        outcome = "CRASH (Will fail in execution)"
    else:
        outcome = "OK"

    print(f"{k:<15} | {status:<15} | {result} -> {outcome}")

print("\n--- 3. RECOMMENDATION ---")
if not has_vgamepad:
    print("CRITICAL: You are missing the Gamepad infrastructure.")
    print("1. Open Terminal.")
    print("2. Run: pip install vgamepad")
    print("3. Ensure ViGEmBus driver is installed (Windows).")
else:
    print("System looks good. If main.py still fails, ensure 'GAMEPAD_MAP' in main.py contains all keys listed above.")