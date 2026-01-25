import bettercam, keyboard, re, time, os
import pydirectinput
from Fishing.Fish import FishingEngine

# --- RESTORED ORIGINAL GAMEPAD LOGIC ---
try:
    import vgamepad as vg

    HAS_GAMEPAD_LIB = True
    virtual_pad = vg.VX360Gamepad()
    BTN = vg.XUSB_BUTTON
    GAMEPAD_MAP = {
        'PAD1': ('btn', BTN.XUSB_GAMEPAD_A, None), 'PAD2': ('btn', BTN.XUSB_GAMEPAD_B, None),
        'PAD3': ('btn', BTN.XUSB_GAMEPAD_X, None), 'PAD4': ('btn', BTN.XUSB_GAMEPAD_Y, None),
        'PAD5': ('btn', BTN.XUSB_GAMEPAD_LEFT_SHOULDER, None), 'PAD6': ('btn', BTN.XUSB_GAMEPAD_RIGHT_SHOULDER, None),
        'PADLTRIGGER': ('trigger', 'left', 255), 'PADRTRIGGER': ('trigger', 'right', 255),
    }
except:
    HAS_GAMEPAD_LIB = False


# --- RESTORED ORIGINAL KEY NORMALIZATION ---
def normalize_key(lua_key):
    lua_key = lua_key.upper().strip()
    modifiers = []
    if 'CTRL-' in lua_key: modifiers.append('ctrl'); lua_key = lua_key.replace('CTRL-', '')
    if 'ALT-' in lua_key: modifiers.append('alt'); lua_key = lua_key.replace('ALT-', '')
    if 'SHIFT-' in lua_key: modifiers.append('shift'); lua_key = lua_key.replace('SHIFT-', '')

    key_map = {'MINUS': '-', 'EQUALS': '=', 'RETURN': 'enter', 'SPACE': 'space', 'TAB': 'tab'}
    clean_key = lua_key.replace('NUMPAD', 'num ') if 'NUMPAD' in lua_key else key_map.get(lua_key, lua_key.lower())
    return {'type': 'keyboard', 'modifiers': modifiers, 'key': clean_key}


# --- RESTORED ORIGINAL EXECUTION LOGIC ---
def execute_action(action):
    for mod in action['modifiers']: keyboard.press(mod)
    try:
        if action['type'] == 'keyboard':
            keyboard.press(action['key']);
            time.sleep(0.05);
            keyboard.release(action['key'])
    except Exception as e:
        print(f"Execute Error: {e}")
    for mod in reversed(action['modifiers']): keyboard.release(mod)


def parse_lua_dataset(file_path):
    if not os.path.exists(file_path): return {}
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    dataset = {}
    for block in re.findall(r'\{([\s\S]*?)\}', content):
        k_m = re.search(r'\["key"\]\s*=\s*"(.*?)"', block)
        c_m = re.search(r'\["color"\]\s*=\s*"(.*?)"', block)
        i_m = re.search(r'\["id"\]\s*=\s*"(.*?)"', block)
        if k_m and c_m and i_m:
            hex_c = c_m.group(1)
            r, g, b = int(hex_c[0:2], 16), int(hex_c[2:4], 16), int(hex_c[4:6], 16)
            action_data = normalize_key(k_m.group(1))
            action_data['name'] = i_m.group(1)
            dataset[(r, g, b)] = action_data
    return dataset


if __name__ == "__main__":
    ACTION_MAP = parse_lua_dataset('OliaEyes6.lua')
    camera = bettercam.create(region=(0, 0, 1, 1))
    fish = FishingEngine()
    is_auto = False

    print(f"Bot Context Restored. F4: Toggle Auto | Num1-6: Manual")
    while True:
        # 1. F4: ENABLE Auto-Pilot ONLY
        if keyboard.is_pressed('f4'):
            if not is_auto:
                is_auto = True
                print(f"[System] AUTO-PILOT ENABLED (is_auto: {is_auto})")
            time.sleep(0.5)

        # 2. Num 1-6: DISABLE Auto-Pilot + Execute Manual
        manual_active = any(keyboard.is_pressed(f'num {i}') for i in range(1, 7))

        if manual_active:
            if is_auto:
                is_auto = False
                print(f"[System] MANUAL OVERRIDE: Auto-Pilot DISABLED (is_auto: {is_auto})")

            # Immediate Manual Execution (No delay)
            frame = camera.grab()
            if frame is not None:
                pixel = tuple(frame[0][0])
                if pixel in ACTION_MAP:
                    print(f"Manual Action: {ACTION_MAP[pixel]['name']}")
                    execute_action(ACTION_MAP[pixel])

        # 3. Automation Loop (F4 Mode)
        elif is_auto:
            frame = camera.grab()
            if frame is not None:
                pixel = tuple(frame[0][0])
                if pixel in ACTION_MAP:
                    print(f"Auto Combat: {ACTION_MAP[pixel]['name']}")
                    execute_action(ACTION_MAP[pixel])
                    # Apply the Auto-only delay
                    time.sleep(0.2)

            # Process Fishing
            fish.poll()

        time.sleep(0.01)
