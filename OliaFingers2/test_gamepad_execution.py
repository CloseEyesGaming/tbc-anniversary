import time
import sys

# Import the actual logic from your main script
try:
    from main import normalize_key, execute_action, HAS_GAMEPAD_LIB
except ImportError:
    print("CRITICAL: Place this script in the same folder as main.py")
    sys.exit(1)


def run_debug_test():
    # Define a set of diverse test cases
    test_keys = [
        "0",  # Simple Keyboard (Attack)
        "CTRL-0",  # Modified Keyboard (Steady Shot)
        "PAD1",  # Gamepad Button (A/Jump)
        "PADLTRIGGER",  # Gamepad Trigger (Faerie Fire)
    ]

    print("--- OLIA EXECUTION DEBUGGER ---")
    print(f"Gamepad Driver (vgamepad): {'READY' if HAS_GAMEPAD_LIB else 'MISSING'}")
    print("\n[STEP 1] Switch to WoW or a Gamepad Tester window (e.g., gamepad-tester.com).")
    print("[STEP 2] Testing will begin in 5 seconds...")

    for i in range(5, 0, -1):
        print(f"{i}...")
        time.sleep(1)

    print("\n--- STARTING EXECUTION ---")
    for key_str in test_keys:
        # 1. Parse the key
        action = normalize_key(key_str)

        # 2. Report what Python 'thinks' it is doing
        print(f"Testing: {key_str:<12} | Type: {action['type']:<10} | Key: {action['key']}")

        # 3. Execute
        execute_action(action)

        # Pause to observe results
        time.sleep(2)

    print("\n--- DEBUG COMPLETE ---")


if __name__ == "__main__":
    run_debug_test()