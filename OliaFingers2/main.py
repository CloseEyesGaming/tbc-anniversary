import bettercam
import keyboard
import re
import time
import os

# --- 1. GAMEPAD SUPPORT ---
try:
    import vgamepad as vg

    HAS_GAMEPAD_LIB = True
    print("[System] vgamepad library loaded. Virtual Controller Active.")
except ImportError:
    HAS_GAMEPAD_LIB = False
    print("[System] WARNING: 'vgamepad' not found. Install with 'pip install vgamepad'. Gamepad keys will be ignored.")

# --- 2. MAPPING CONSTANTS ---
# We use a tuple structure: (Type, Target, Value)
# Types: 'btn' (Button), 'trigger' (Left/Right Trigger 0-255), 'axis' (Stick X/Y)
GAMEPAD_MAP = {}

if HAS_GAMEPAD_LIB:
    # Shortcuts for XUSB Buttons
    BTN = vg.XUSB_BUTTON

    GAMEPAD_MAP = {
        # --- FACE BUTTONS ---
        'PAD1': ('btn', BTN.XUSB_GAMEPAD_A, None),
        'PAD2': ('btn', BTN.XUSB_GAMEPAD_B, None),
        'PAD3': ('btn', BTN.XUSB_GAMEPAD_X, None),
        'PAD4': ('btn', BTN.XUSB_GAMEPAD_Y, None),

        # --- BUMPERS (L1/R1) ---
        'PAD5': ('btn', BTN.XUSB_GAMEPAD_LEFT_SHOULDER, None),
        'PAD6': ('btn', BTN.XUSB_GAMEPAD_RIGHT_SHOULDER, None),

        # --- TRIGGERS (L2/R2) - Mapped to PADPADDLE 1/2 ---
        'PADPADDLE1': ('trigger', 'left', 255),  # Full Press LT
        'PADPADDLE2': ('trigger', 'right', 255),  # Full Press RT

        # --- EXTRA PADDLES - Mapped to Stick Clicks or D-Pad ---
        'PADPADDLE3': ('btn', BTN.XUSB_GAMEPAD_LEFT_THUMB, None),  # L3
        'PADPADDLE4': ('btn', BTN.XUSB_GAMEPAD_RIGHT_THUMB, None),  # R3

        # --- D-PAD ---
        'PADDUP': ('btn', BTN.XUSB_GAMEPAD_DPAD_UP, None),
        'PADDDOWN': ('btn', BTN.XUSB_GAMEPAD_DPAD_DOWN, None),
        'PADDLEFT': ('btn', BTN.XUSB_GAMEPAD_DPAD_LEFT, None),
        'PADDRIGHT': ('btn', BTN.XUSB_GAMEPAD_DPAD_RIGHT, None),

        # --- STICKS (CLICKS) ---
        'PADLSTICK': ('btn', BTN.XUSB_GAMEPAD_LEFT_THUMB, None),
        'PADRSTICK': ('btn', BTN.XUSB_GAMEPAD_RIGHT_THUMB, None),

        # --- STICK MOVEMENT (AXIS EMULATION) ---
        # Values are float -1.0 to 1.0.
        # (Type, StickSide, (X, Y))
        'PADLSTICKUP': ('axis', 'left', (0.0, 1.0)),
        'PADLSTICKDOWN': ('axis', 'left', (0.0, -1.0)),
        'PADLSTICKLEFT': ('axis', 'left', (-1.0, 0.0)),
        'PADLSTICKRIGHT': ('axis', 'left', (1.0, 0.0)),

        'PADRSTICKUP': ('axis', 'right', (0.0, 1.0)),
        'PADRSTICKDOWN': ('axis', 'right', (0.0, -1.0)),
        'PADRSTICKLEFT': ('axis', 'right', (-1.0, 0.0)),
        'PADRSTICKRIGHT': ('axis', 'right', (1.0, 0.0)),

        # --- SYSTEM BUTTONS ---
        'PADSYSTEM': ('btn', BTN.XUSB_GAMEPAD_START, None),
        'PADSOCIAL': ('btn', BTN.XUSB_GAMEPAD_BACK, None),
        'PADFORWARD': ('btn', BTN.XUSB_GAMEPAD_GUIDE, None),
    }

    virtual_pad = vg.VX360Gamepad()


def normalize_key(lua_key):
    """
    Parses a Lua key string into a structured object.
    """
    lua_key = lua_key.upper().strip()

    # 1. Extract Modifiers
    modifiers = []
    if 'CTRL-' in lua_key:
        modifiers.append('ctrl')
        lua_key = lua_key.replace('CTRL-', '')
    if 'ALT-' in lua_key:
        modifiers.append('alt')
        lua_key = lua_key.replace('ALT-', '')
    if 'SHIFT-' in lua_key:
        modifiers.append('shift')
        lua_key = lua_key.replace('SHIFT-', '')

    # 2. Check for Gamepad
    if HAS_GAMEPAD_LIB and lua_key in GAMEPAD_MAP:
        mapping = GAMEPAD_MAP[lua_key]
        return {
            'type': 'gamepad',
            'subtype': mapping[0],  # btn, trigger, axis
            'target': mapping[1],
            'value': mapping[2],
            'modifiers': modifiers,
            'key': lua_key  # Raw name for logging
        }

    # 3. Standardize Keyboard Keys
    key_map = {
        'MINUS': '-', 'EQUALS': '=', 'PLUS': '+',
        'NUMPAD': 'num ', 'PAGEUP': 'page up', 'PAGEDOWN': 'page down',
        'RETURN': 'enter', 'INSERT': 'insert', 'DELETE': 'delete',
        'HOME': 'home', 'END': 'end', 'SPACE': 'space', 'TAB': 'tab',
        'BACKSPACE': 'backspace',
        '\\\\': 'backslash', 'BACKSLASH': 'backslash', '\\': 'backslash',
        '[': '[', ']': ']', ';': ';', "'": "'", ',': ',', '.': '.', '/': '/'
    }

    clean_key = lua_key
    if 'NUMPAD' in clean_key:
        clean_key = clean_key.replace('NUMPAD', 'num ')
    elif clean_key in key_map:
        clean_key = key_map[clean_key]
    else:
        if clean_key in key_map:
            clean_key = key_map[clean_key]
        else:
            clean_key = clean_key.lower()

    return {
        'type': 'keyboard',
        'modifiers': modifiers,
        'key': clean_key
    }


def parse_lua_dataset(file_path):
    if not os.path.exists(file_path):
        print(f"Error: Could not find '{file_path}'.")
        return {}

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    dataset = {}
    blocks = re.findall(r'\{([\s\S]*?)\}', content)

    for block in blocks:
        key_match = re.search(r'\["key"\]\s*=\s*"(.*?)"', block)
        id_match = re.search(r'\["id"\]\s*=\s*"(.*?)"', block)
        color_match = re.search(r'\["color"\]\s*=\s*"(.*?)"', block)

        if key_match and id_match and color_match:
            try:
                hex_color = color_match.group(1)
                r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)

                action_data = normalize_key(key_match.group(1))
                action_data['name'] = id_match.group(1)
                dataset[(r, g, b)] = action_data
            except ValueError:
                continue
    return dataset


def execute_action(action):
    # 1. Modifiers (Always Keyboard)
    for mod in action['modifiers']:
        keyboard.press(mod)

    # 2. Main Action
    try:
        if action['type'] == 'keyboard':
            keyboard.press(action['key'])
            time.sleep(0.05)
            keyboard.release(action['key'])

        elif action['type'] == 'gamepad' and HAS_GAMEPAD_LIB:
            subtype = action['subtype']

            if subtype == 'btn':
                virtual_pad.press_button(button=action['target'])
                virtual_pad.update()
                time.sleep(0.05)
                virtual_pad.release_button(button=action['target'])
                virtual_pad.update()

            elif subtype == 'trigger':
                # Target is 'left' or 'right'
                if action['target'] == 'left':
                    virtual_pad.left_trigger(value=action['value'])
                else:
                    virtual_pad.right_trigger(value=action['value'])
                virtual_pad.update()
                time.sleep(0.05)
                if action['target'] == 'left':
                    virtual_pad.left_trigger(value=0)
                else:
                    virtual_pad.right_trigger(value=0)
                virtual_pad.update()

            elif subtype == 'axis':
                # Target is 'left' or 'right', Value is (x, y) tuple
                x, y = action['value']
                if action['target'] == 'left':
                    virtual_pad.left_joystick_float(x_value_float=x, y_value_float=y)
                else:
                    virtual_pad.right_joystick_float(x_value_float=x, y_value_float=y)
                virtual_pad.update()
                time.sleep(0.1)  # Sticks need a bit more time to register
                if action['target'] == 'left':
                    virtual_pad.left_joystick_float(x_value_float=0.0, y_value_float=0.0)
                else:
                    virtual_pad.right_joystick_float(x_value_float=0.0, y_value_float=0.0)
                virtual_pad.update()

    except Exception as e:
        # Graceful error handling (No crash)
        print(f"Error Executing {action.get('key', 'Unknown')}: {e}")

    # 3. Release Modifiers
    for mod in reversed(action['modifiers']):
        keyboard.release(mod)


if __name__ == "__main__":
    LUA_FILE = 'OliaEyes6.lua'
    TRIGGER_KEYS = ['num 1', 'num 2', 'num 3', 'num 4', 'num 5', 'num 6']

    print(f"--- Parsing {LUA_FILE} ---")
    ACTION_MAP = parse_lua_dataset(LUA_FILE)

    if not ACTION_MAP:
        print("CRITICAL: No actions loaded.")
        exit()

    print(f"\nSuccessfully loaded {len(ACTION_MAP)} actions.")
    camera = bettercam.create(region=(0, 0, 1, 1))
    print(f"\nBot Ready. Hold {TRIGGER_KEYS} to scan.")

    try:
        while True:
            if any(keyboard.is_pressed(k) for k in TRIGGER_KEYS):
                frame = camera.grab()
                if frame is not None:
                    pixel = tuple(frame[0][0])
                    if pixel in ACTION_MAP:
                        action = ACTION_MAP[pixel]
                        # print(f"Detected {pixel} -> {action['name']}")
                        execute_action(action)
                        time.sleep(0.1)
                else:
                    time.sleep(0.001)
            else:
                time.sleep(0.02)
    except KeyboardInterrupt:
        print("\nShutting down.")