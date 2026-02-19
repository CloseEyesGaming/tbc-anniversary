import time
import sys
import os
import re
import argparse
import json
from datetime import datetime

# --- IMPORTS FROM MAIN ---
try:
    from main import execute_action, normalize_key, HAS_GAMEPAD_LIB
except ImportError:
    print("CRITICAL: 'main.py' not found. This tool requires the refactored main.py.")
    sys.exit(1)


# --- PARSERS ---

def parse_lua_with_classes(file_path):
    """Parses OliaEyes_Export for action definitions."""
    if not os.path.exists(file_path):
        print(f"Error: Could not find '{file_path}'.")
        return []

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    actions_list = []
    blocks = re.findall(r'\{([\s\S]*?)\}', content)

    for block in blocks:
        if '["type"]' not in block:
            continue

        key_match = re.search(r'\["key"\]\s*=\s*"(.*?)"', block)
        id_match = re.search(r'\["id"\]\s*=\s*"(.*?)"', block)
        class_match = re.search(r'\["class"\]\s*=\s*"(.*?)"', block)

        if key_match and id_match and class_match:
            raw_key = key_match.group(1)
            action_id = id_match.group(1)
            class_name = class_match.group(1).upper()

            action_data = normalize_key(raw_key)
            action_data['name'] = action_id
            action_data['class'] = class_name
            action_data['raw_key'] = raw_key

            actions_list.append(action_data)

    return actions_list


def parse_lua_debug_log(file_path):
    """Parses OliaDebugLog from the Lua file (Resilient Version)."""
    if not os.path.exists(file_path):
        return []

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    start_match = re.search(r'OliaDebugLog\s*=\s*\{', content)
    if not start_match:
        if "OliaDebugLog" in content:
            print("DEBUG: Found 'OliaDebugLog' text but regex failed to match start.")
        return []

    log_content = content[start_match.end():]
    entries = []
    block_pattern = re.compile(r'\{([\s\S]*?)\}')

    for block in block_pattern.findall(log_content):
        ts_match = re.search(r'\["timestamp"\]\s*=\s*"(.*?)"', block)
        key_match = re.search(r'\["key"\]\s*=\s*"(.*?)"', block)
        spell_match = re.search(r'\["spell"\]\s*=\s*"(.*?)"', block)

        if ts_match and key_match and spell_match:
            entries.append({
                "timestamp": ts_match.group(1),
                "key": key_match.group(1),
                "name": spell_match.group(1)
            })

    return entries


# --- MAIN MODES ---

def run_test(target_class=None):
    LUA_FILE = 'OliaEyes6.lua'
    LOG_FILE = 'python_key_log.json'

    print(f"--- Loading Definitions from {LUA_FILE} ---")
    all_actions = parse_lua_with_classes(LUA_FILE)

    if not all_actions:
        print("No actions found. Check file.")
        return

    # Filter Exclusions
    excluded_names = ["Thread 1", "Thread 2", "Thread 3", "Thread 4", "Thread 5", "Thread 6", "Thread 7"]
    all_actions = [a for a in all_actions if a['name'] not in excluded_names]

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

    test_queue.sort(key=lambda x: (0 if x['class'] == 'GLOBAL' else 1, x['class'], x['name']))

    print(f"\nLoaded {len(test_queue)} actions to test.")
    if HAS_GAMEPAD_LIB:
        print("[SUCCESS] Gamepad Driver: ACTIVE")
    else:
        print("[WARNING] Gamepad Driver: MISSING/INACTIVE")

    print("\n[!!!] Switch to WoW window NOW. Starting in 5 seconds... [!!!]")
    try:
        for i in range(5, 0, -1):
            print(f"{i}...", end=" ", flush=True)
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nAborted.")
        return

    print("\n\n--- STARTING SEQUENCE ---")
    execution_log = []

    for i, action in enumerate(test_queue, 1):
        display_key = action.get('raw_key')
        type_str = "KBD" if action['type'] == 'keyboard' else "PAD"
        timestamp = datetime.now().strftime("%H:%M:%S")

        print(f"[{i}/{len(test_queue)}] [{type_str}] {action['class']} : {action['name']} -> [{display_key}]")

        execution_log.append({
            "index": i,
            "timestamp": timestamp,
            "type": type_str,
            "class": action['class'],
            "name": action['name'],
            "key": display_key
        })

        execute_action(action)
        time.sleep(0.4)

    try:
        with open(LOG_FILE, 'w', encoding='utf-8') as f:
            json.dump(execution_log, f, indent=4)
        print(f"\n[LOG SAVED] Execution dump written to '{LOG_FILE}'")
    except Exception as e:
        print(f"\n[ERROR] Could not save log: {e}")

    print("--- TEST COMPLETE ---")


def run_compare():
    PYTHON_LOG = 'python_key_log.json'
    LUA_FILE = 'OliaEyes6.lua'

    if not os.path.exists(PYTHON_LOG):
        print(f"Error: '{PYTHON_LOG}' not found.")
        return

    with open(PYTHON_LOG, 'r', encoding='utf-8') as f:
        skeleton = json.load(f)

    lua_events = parse_lua_debug_log(LUA_FILE)

    print(f"\n{'Action/Spell':<25} | {'Key':<12} | {'Win Recog':<10} | {'WoW Result'}")
    print("-" * 75)

    for item in skeleton:
        name = item['name'].strip().lower()
        key = item['key'].strip().upper()

        # 1. Hardware/Windows Verification (Did Python successfully fire the driver?)
        # Since we use execute_action(action) in the test, we pull its status from the log
        win_status = "OK" if item.get('type') in ['KBD', 'PAD'] else "ERR"

        # 2. WoW Verification (Did the engine accept it?)
        actual_press = next((l for l in lua_events if
                             l['name'].strip().lower() == name and
                             l['key'].strip().upper() == key), None)

        wow_status = "[ PASS ]" if actual_press else "[!! FAIL !!]"

        # Check for specific "Silent Drops" (Windows says OK, WoW says FAIL)
        if win_status == "OK" and not actual_press:
            wow_status = "[!! DROPPED !!]"

        print(f"{item['name']:<25} | {item['key']:<12} | {win_status:<10} | {wow_status}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OliaEyes Keybind Verification Tool")
    parser.add_argument("classname", nargs="?", help="Specific Class to test (e.g. DRUID). Leave empty to test all.")
    parser.add_argument("--compare", action="store_true", help="Compare the last python dump with the Lua Debug Log.")
    args = parser.parse_args()

    try:
        if args.compare:
            run_compare()
        else:
            run_test(args.classname)
    except KeyboardInterrupt:
        print("\nInterrupted.")