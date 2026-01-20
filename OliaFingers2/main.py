import bettercam
import keyboard
import re
import time
import os


def parse_lua_dataset(file_path):
    if not os.path.exists(file_path):
        print(f"Error: Could not find '{file_path}'. Make sure it exists.")
        return {}

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # REGEX UPDATE: Now captures Group 3 as "class"
    # Pattern: key -> id -> class -> color
    pattern = re.compile(
        r'\{[\s\S]*?\["key"\] = "(.*?)",[\s\S]*?\["id"\] = "(.*?)",[\s\S]*?\["class"\] = "(.*?)",[\s\S]*?\["color"\] = "(.*?)",',
        re.MULTILINE)

    matches = pattern.findall(content)
    dataset = {}

    # --- KEY MAPPINGS ---
    key_map = {
        'MINUS': 'num -', 'EQUALS': 'num +', 'PLUS': 'num +',
        'NUMPAD': 'num ', 'PAGEUP': 'page up', 'PAGEDOWN': 'page down',
        'RETURN': 'enter', 'CTRL': 'ctrl', 'SHIFT': 'shift', 'ALT': 'alt',
        'RIGHT': 'right', 'LEFT': 'left', 'UP': 'up', 'DOWN': 'down',
        'INSERT': 'insert', 'DELETE': 'delete', 'HOME': 'home', 'END': 'end',
        'SPACE': 'space', 'TAB': 'tab',
        'F1': 'f1', 'F2': 'f2', 'F3': 'f3', 'F4': 'f4', 'F5': 'f5', 'F6': 'f6',
        'F7': 'f7', 'F8': 'f8', 'F9': 'f9', 'F10': 'f10', 'F11': 'f11', 'F12': 'f12'
    }

    for key_name, action_id, class_name, hex_color in matches:
        try:
            r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)
        except ValueError:
            continue

        # Sanitize Key Name
        clean_name = key_name.replace('–', '-').replace('—', '-').replace('−', '-')
        parts = clean_name.split('-')
        converted_parts = []

        for part in parts:
            part_upper = part.upper().strip()
            if part_upper.startswith('NUMPAD'):
                converted = part_upper.replace('NUMPAD', 'num ')
            elif part_upper in key_map:
                converted = key_map[part_upper]
            else:
                converted = part.lower()
            converted_parts.append(converted)

        formatted_key = '+'.join(converted_parts)

        # Store KEY, NAME, and CLASS
        dataset[(r, g, b)] = {
            "key": formatted_key,
            "name": action_id,
            "class": class_name.upper()  # Store as uppercase for easy filtering
        }

    return dataset


# --- Execution ---
if __name__ == "__main__":
    LUA_FILE = 'OliaEyes6.lua'
    TRIGGER_KEYS = ['num 1', 'num 2', 'num 3', 'num 4', 'num 5', 'num 6']

    print(f"--- Parsing {LUA_FILE} ---")
    ACTION_MAP = parse_lua_dataset(LUA_FILE)

    if not ACTION_MAP:
        print("CRITICAL: No actions loaded. Exiting.")
        exit()

    print(f"\nSuccessfully loaded {len(ACTION_MAP)} actions.")

    # Print a summary of classes found
    classes_found = set(d['class'] for d in ACTION_MAP.values())
    print(f"Classes found: {', '.join(classes_found)}")

    camera = bettercam.create(region=(0, 0, 1, 1))
    print(f"\nBot standby. Hold {', '.join(TRIGGER_KEYS)} to start scanning.")

    try:
        while True:
            if any(keyboard.is_pressed(k) for k in TRIGGER_KEYS):
                frame = camera.grab()
                if frame is not None:
                    pixel = tuple(frame[0][0])

                    if pixel in ACTION_MAP:
                        action_data = ACTION_MAP[pixel]
                        key_str = action_data["key"]
                        action_name = action_data["name"]
                        # We don't filter by class in the main bot, only in tests,
                        # but you could add logic here if you wanted.

                        print(f"Detected {pixel} -> Casting: [{action_name}] via [{key_str}]")

                        try:
                            keys = key_str.split('+')
                            for k in keys: keyboard.press(k)
                            time.sleep(0.05)
                            for k in reversed(keys): keyboard.release(k)
                        except Exception as e:
                            print(f"Error pressing '{key_str}': {e}")

                        time.sleep(0.1)
                else:
                    time.sleep(0.001)
            else:
                time.sleep(0.02)

    except KeyboardInterrupt:
        print("\nShutting down.")