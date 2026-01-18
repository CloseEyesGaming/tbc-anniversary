import bettercam
import keyboard
import re
import time


def parse_lua_dataset(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: Could not find '{file_path}'. Make sure it exists.")
        return {}

    # Regex to find key, id, and color in the Lua table
    pattern = re.compile(r'\{[\s\S]*?\["key"\] = "(.*?)",[\s\S]*?\["id"\] = "(.*?)",[\s\S]*?\["color"\] = "(.*?)",',
                         re.MULTILINE)
    matches = pattern.findall(content)
    dataset = {}

    # --- KEY MAPPINGS (Adjusted for Numpad Hypothesis) ---
    key_map = {
        # Hypothesis: User binds are actually on the NUMPAD
        'MINUS': 'num -',  # Mapped to Numpad Minus
        'EQUALS': 'num +',  # Mapped to Numpad Plus (Common alternative for =)
        'PLUS': 'num +',  # Explicit Plus

        # Standard Modifiers & Navigation
        'NUMPAD': 'num ',
        'PAGEUP': 'page up',
        'PAGEDOWN': 'page down',
        'RETURN': 'enter',
        'CTRL': 'ctrl',
        'SHIFT': 'shift',
        'ALT': 'alt',
        'RIGHT': 'right',  # Arrow Key Right
        'LEFT': 'left',  # Arrow Key Left
        'UP': 'up',  # Arrow Key Up
        'DOWN': 'down',  # Arrow Key Down
        'INSERT': 'insert',
        'DELETE': 'delete',
        'HOME': 'home',
        'END': 'end',
        'SPACE': 'space',
        'TAB': 'tab',
        'F1': 'f1', 'F2': 'f2', 'F3': 'f3', 'F4': 'f4', 'F5': 'f5', 'F6': 'f6',
        'F7': 'f7', 'F8': 'f8', 'F9': 'f9', 'F10': 'f10', 'F11': 'f11', 'F12': 'f12'
    }

    for key_name, action_id, hex_color in matches:
        r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)

        # Sanitize dashes
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
        dataset[(r, g, b)] = formatted_key

    print(f"Parsed {len(dataset)} actions from {file_path}.")
    return dataset


# --- Configuration ---
LUA_FILE = 'OliaEyes6.lua'
TRIGGER_KEYS = ['num 1', 'num 2', 'num 3', 'num 4', 'num 5', 'num 6']

# --- Initialization ---
ACTION_MAP = parse_lua_dataset(LUA_FILE)
camera = bettercam.create(region=(0, 0, 1, 1))

if not ACTION_MAP:
    print("CRITICAL: No actions loaded. Exiting.")
    exit()

print(f"Bot standby. Hold {', '.join(TRIGGER_KEYS)} to start scanning.")

try:
    while True:
        active = any(keyboard.is_pressed(k) for k in TRIGGER_KEYS)

        if active:
            frame = camera.grab()
            if frame is not None:
                pixel = tuple(frame[0][0])

                if pixel in ACTION_MAP:
                    key_to_press = ACTION_MAP[pixel]

                    # [DEBUG] Check console to see if it says "alt+num -" or "alt+num +"
                    print(f"Detected {pixel} -> Pressing: {key_to_press}")

                    try:
                        keyboard.press(key_to_press)
                        time.sleep(0.05)
                        keyboard.release(key_to_press)
                    except ValueError as e:
                        print(f"Error pressing key '{key_to_press}': {e}")
                    except Exception as e:
                        print(f"Unexpected error with '{key_to_press}': {e}")

                    time.sleep(0.1)
            else:
                time.sleep(0.001)
        else:
            time.sleep(0.02)

except KeyboardInterrupt:
    print("\nShutting down.")