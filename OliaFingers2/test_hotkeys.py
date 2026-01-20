import time
import keyboard
import sys
import os
from main import parse_lua_dataset

"""
OliaEyes Keybind Verification Tool
----------------------------------
Purpose:
    Parses the addon's Lua configuration ('OliaEyes6.lua') and physically simulates 
    keypresses for every bound action. This allows you to verify that your 
    in-game action bars are lighting up correctly.

Usage:
    python test_keybinds.py [CLASS_FILTER]

Arguments:
    CLASS_FILTER (Optional):
        If provided, tests bindings for that specific class PLUS all GLOBAL bindings.
        Examples: 'DRUID', 'PALADIN', 'ROGUE'.
        If omitted, tests ALL bindings found in the file.

Safety & Instructions:
    1. Run this script.
    2. You have a 5-SECOND DELAY to Alt-Tab into World of Warcraft.
    3. The script will press keys every 0.5 seconds.
    4. Watch your action bars to confirm the correct spells are highlighting.
    5. To Abort: Press 'Ctrl+C' in this terminal.

Requirements:
    - 'OliaEyes6.lua' must be in the same directory.
    - 'main.py' (for the parser) must be in the same directory.
    - Run as Administrator if inputs are not registering in WoW.
"""


def test_rotation():
    LUA_FILE = 'OliaEyes6.lua'

    # These are the keys defined in main.py to trigger the bot
    # We explicitly ensure they are tested.
    BOT_TRIGGER_KEYS = ['num 1', 'num 2', 'num 3', 'num 4', 'num 5', 'num 6']

    # 1. Parse Arguments for Class Filtering
    target_class = None
    if len(sys.argv) > 1:
        target_class = sys.argv[1].upper()
        print(f"--- TEST MODE: Filtering for Class [{target_class}] + GLOBAL ---")
    else:
        print(f"--- TEST MODE: Testing ALL Classes (No filter provided) ---")
        print("Tip: You can run 'python test_keybinds.py PALADIN' to test specific classes.")

    # 2. Check File Existence
    if not os.path.exists(LUA_FILE):
        print(f"ERROR: '{LUA_FILE}' not found. Please place it in this folder.")
        return

    # 3. Load Data
    action_map = parse_lua_dataset(LUA_FILE)
    if not action_map:
        print("No bindings found or file is empty.")
        return

    # 4. Filter Data
    unique_actions = []
    seen_keys = set()

    # Add Lua Actions
    for data in action_map.values():
        k = data["key"]
        n = data["name"]
        c = data["class"]

        # Filtering Logic:
        # Keep if no filter is set OR if class matches OR if it is GLOBAL
        if target_class and c != target_class and c != "GLOBAL":
            continue

        if k not in seen_keys:
            unique_actions.append((k, n, c))
            seen_keys.add(k)

    # 5. Explicitly Add Trigger Keys (if not already present)
    # This ensures num 1-6 are tested even if Lua export is missing them
    for t_key in BOT_TRIGGER_KEYS:
        if t_key not in seen_keys:
            # Only add if we are not filtering, or if we are filtering for GLOBAL (conceptually)
            # Since threads are global, we usually want to test them.
            print(f"Note: Adding Trigger Key '{t_key}' manually to test list.")
            unique_actions.append((t_key, "Bot Trigger / Thread", "SYSTEM"))
            seen_keys.add(t_key)

    # 6. Sort Data
    # Priority: SYSTEM/GLOBAL (0) -> Others (1), then by Class Name, then by Action Name
    unique_actions.sort(key=lambda x: (0 if x[2] in ["GLOBAL", "SYSTEM"] else 1, x[2], x[1]))

    if not unique_actions:
        print(f"No actions found for class '{target_class}'. Check spelling.")
        # Print available classes to help the user
        available = set(d['class'] for d in action_map.values())
        print(f"Available classes: {', '.join(sorted(available))}")
        return

    print(f"\nReady to test {len(unique_actions)} keybinds for {target_class or 'ALL'} (+GLOBAL/TRIGGERS).")
    print("Switch to World of Warcraft NOW.")
    print("Starting in 5 seconds...")
    time.sleep(5)

    for idx, (key_str, action_name, class_name) in enumerate(unique_actions, 1):
        print(f"\n[{idx}/{len(unique_actions)}] Class: {class_name} | Spell: '{action_name}'")
        print(f"    -> Key: {key_str}")

        try:
            # Press
            keys = key_str.split('+')
            for k in keys:
                keyboard.press(k)

            time.sleep(0.05)  # Hold duration

            for k in reversed(keys):
                keyboard.release(k)

            print("    -> SENT.")

        except Exception as e:
            print(f"    -> FAILED: {e}")

        time.sleep(0.5)

    print("\n--- TEST COMPLETE ---")


if __name__ == "__main__":
    test_rotation()