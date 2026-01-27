import vgamepad as vg
import time
import sys


def test_gamepad():
    print("--- Gamepad Diagnostic Tool ---")
    print("Attempting to connect to Virtual Xbox 360 Controller...")

    try:
        gamepad = vg.VX360Gamepad()
        print("[SUCCESS] Virtual Controller Created!")
        print("Note: If this is the first time running, Windows might be installing drivers in the background.")
        print("      Check your 'Game Controllers' setting in Windows to see 'Xbox 360 Controller for Windows'.")
    except Exception as e:
        print(f"[FAIL] Could not create virtual controller: {e}")
        print("Ensure ViGEmBus driver is installed.")
        return
    print("\nStarting Loop: Pressing 'A', then 'Right Trigger', then 'Left Trigger'.")
    print("Focus your WoW window now.")
    print("1. 'A' (PAD1) should Jump/Interact.")
    print("2. 'Right Trigger' (PADRTRIGGER) should verify trigger binding.")
    print("Press Ctrl+C to stop.\n")
    counter = 1
    try:
        while True:
            # 1. Press A
            print(f"[{counter}] Pressing 'A' (PAD1)...")
            gamepad.press_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_A)
            gamepad.update()
            time.sleep(0.2)
            gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_A)
            gamepad.update()
            time.sleep(1.0)
            # 2. Press Right Trigger
            print(f"[{counter}] Pulling Right Trigger (PADRTRIGGER)...")
            gamepad.right_trigger(value=255)
            gamepad.update()
            time.sleep(0.5)  # Longer hold for triggers
            gamepad.right_trigger(value=0)
            gamepad.update()
            time.sleep(1.0)

            # 3. Press Left Trigger
            print(f"[{counter}] Pulling Left Trigger (PADLTRIGGER)...")
            gamepad.left_trigger(value=255)
            gamepad.update()
            time.sleep(0.5)
            gamepad.left_trigger(value=0)
            gamepad.update()
            time.sleep(1.0)
            counter += 1
    except KeyboardInterrupt:
        print("\nTest Stopped.")


if __name__ == "__main__":
    test_gamepad()
