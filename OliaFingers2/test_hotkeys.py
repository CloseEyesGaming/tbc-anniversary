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
        py_data = json.load(f)

    # Searchable list of actual events WoW recorded
    lua_data = parse_lua_debug_log(LUA_FILE)
    lua_pool = list(lua_data)

    print(f"\n{'#':<4} | {'PYTHON (Sent)':<40} || {'LUA (Verified Match)':<55}")
    print("-" * 105)

    for i, p in enumerate(py_data):
        p_str = f"[{p['key']}] {p['name']}"
        l_str = "!!! MISSING !!!"

        # 1. Classification: Is it a Gamepad?
        # Standardize check for PAD1-6, PADDLE, TRIGGER, SHOULDER
        is_gamepad = p['type'] == 'PAD' or 'PAD' in p['key'].upper()

        if is_gamepad:
            l_str = f"PASSED (Gamepad Signal Sent)"
        else:
            # 2. SMART MATCH: Find the entry by Name AND Key in the Lua log
            # This makes the test immune to "Sequence Drift"
            match = next((l for l in lua_pool if l['name'] == p['name'] and l['key'] == p['key']), None)

            if match:
                l_str = f"MATCH FOUND ({match['timestamp']})"
                lua_pool.remove(match)  # Ensure we don't match the same log twice

        print(f"{i + 1:<4} | {p_str:<40} || {l_str:<55}")


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