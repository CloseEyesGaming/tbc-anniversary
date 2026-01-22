import time
import sys
import os
import re
import argparse

# --- IMPORTS FROM MAIN ---
# We reuse the core logic to ensure the test exactly matches the bot's behavior.
try:
    from main import execute_action, normalize_key, HAS_GAMEPAD_LIB
except ImportError:
    print("CRITICAL: 'main.py' not found. This tool requires the refactored main.py.")
    sys.exit(1)


def parse_lua_with_classes(file_path):
    """
    A specialized parser for the Test Tool.
    """
    if not os.path.exists(file_path):
        print(f"Error: Could not find '{file_path}'.")
        return []

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    actions_list = []

    # robust block parser
    blocks = re.findall(r'\{([\s\S]*?)\}', content)

    for block in blocks:
        # Extract fields
        key_match = re.search(r'\["key"\]\s*=\s*"(.*?)"', block)
        id_match = re.search(r'\["id"\]\s*=\s*"(.*?)"', block)
        class_match = re.search(r'\["class"\]\s*=\s*"(.*?)"', block)

        if key_match and id_match and class_match:
            raw_key = key_match.group(1)
            action_id = id_match.group(1)
            class_name = class_match.group(1).upper()

            # Use main.py's normalizer to get the structure (Type, Modifiers, KeyCode)
            action_data = normalize_key(raw_key)

            # Enrich with metadata
            action_data['name'] = action_id
            action_data['class'] = class_name
            action_data['raw_key'] = raw_key

            actions_list.append(action_data)

    return actions_list


def run_test(target_class=None):
    LUA_FILE = 'OliaEyes6.lua'

    print(f"--- Loading {LUA_FILE} ---")
    all_actions = parse_lua_with_classes(LUA_FILE)

    if not all_actions:
        print("No actions found. Check file.")
        return

    test_queue = []

    if target_class:
        target_class = target_class.upper()
        print(f"--- Filtering for CLASS: {target_class} (+GLOBAL) ---")
        for act in all_actions:
            c = act['class']
            if c == target_class or c == "GLOBAL" or c == "SYSTEM":
                test_queue.append(act)
    else:
        print("--- Testing ALL Classes ---")
        test_queue = all_actions

    # Sort for readability: Global first, then Alphabetical by Name
    test_queue.sort(key=lambda x: (0 if x['class'] == 'GLOBAL' else 1, x['class'], x['name']))

    print(f"\nLoaded {len(test_queue)} actions to test.")

    # --- DIAGNOSTIC INFO ---
    if HAS_GAMEPAD_LIB:
        print("\n[SUCCESS] Gamepad Driver: ACTIVE")
        print("          Virtual Controller keys will be simulated.")
    else:
        print("\n[WARNING] Gamepad Driver: MISSING/INACTIVE")
        print("          'PAD' keys will likely FAIL or be ignored.")

    print("\n[!!!] Switch to WoW window NOW. Starting in 5 seconds... [!!!]")
    try:
        for i in range(5, 0, -1):
            print(f"{i}...", end=" ", flush=True)
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nAborted.")
        return

    print("\n\n--- STARTING SEQUENCE ---")

    for i, action in enumerate(test_queue, 1):
        # Pretty print
        display_key = action.get('raw_key')
        type_str = "KBD" if action['type'] == 'keyboard' else "PAD"

        print(f"[{i}/{len(test_queue)}] [{type_str}] {action['class']} : {action['name']} -> [{display_key}]")

        # Execute using the shared logic from main.py
        execute_action(action)

        # Delay to allow visual verification in game
        time.sleep(0.4)

    print("\n--- TEST COMPLETE ---")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OliaEyes Keybind Verification Tool")
    parser.add_argument("classname", nargs="?", help="Specific Class to test (e.g. DRUID). Leave empty to test all.")
    args = parser.parse_args()

    try:
        run_test(args.classname)
    except KeyboardInterrupt:
        print("\nTest Interrupted by User.")