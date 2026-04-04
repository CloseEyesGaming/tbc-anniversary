import bettercam, keyboard, re, time, os, ctypes
from Fishing.Fish import FishingEngine

# --- RESTORED ORIGINAL GAMEPAD LOGIC ---
try:
    import vgamepad as vg

    HAS_GAMEPAD_LIB = True
    virtual_pad = vg.VX360Gamepad()
    BTN = vg.XUSB_BUTTON
    GAMEPAD_MAP = {
        'PAD1': ('btn', BTN.XUSB_GAMEPAD_A), 'PAD2': ('btn', BTN.XUSB_GAMEPAD_B),
        'PAD3': ('btn', BTN.XUSB_GAMEPAD_X), 'PAD4': ('btn', BTN.XUSB_GAMEPAD_Y),
        'PADLSHOULDER': ('btn', BTN.XUSB_GAMEPAD_LEFT_SHOULDER), 'PAD5': ('btn', BTN.XUSB_GAMEPAD_LEFT_SHOULDER),
        'PADRSHOULDER': ('btn', BTN.XUSB_GAMEPAD_RIGHT_SHOULDER), 'PAD6': ('btn', BTN.XUSB_GAMEPAD_RIGHT_SHOULDER),
        'PADLTRIGGER': ('trigger', 'left'), 'PADRTRIGGER': ('trigger', 'right'),
        'PADDUP': ('btn', BTN.XUSB_GAMEPAD_DPAD_UP), 'PADDDOWN': ('btn', BTN.XUSB_GAMEPAD_DPAD_DOWN),
        'PADDLEFT': ('btn', BTN.XUSB_GAMEPAD_DPAD_LEFT), 'PADDRIGHT': ('btn', BTN.XUSB_GAMEPAD_DPAD_RIGHT),
        'PADLSTICK': ('btn', BTN.XUSB_GAMEPAD_LEFT_THUMB), 'PADRSTICK': ('btn', BTN.XUSB_GAMEPAD_RIGHT_THUMB),
        'PADLSTICKUP': ('stick', 'left', 0.0, 1.0), 'PADLSTICKDOWN': ('stick', 'left', 0.0, -1.0),
        'PADLSTICKLEFT': ('stick', 'left', -1.0, 0.0), 'PADLSTICKRIGHT': ('stick', 'left', 1.0, 0.0),
        'PADRSTICKUP': ('stick', 'right', 0.0, 1.0), 'PADRSTICKDOWN': ('stick', 'right', 0.0, -1.0),
        'PADRSTICKLEFT': ('stick', 'right', -1.0, 0.0), 'PADRSTICKRIGHT': ('stick', 'right', 1.0, 0.0),
        'PADFORWARD': ('btn', BTN.XUSB_GAMEPAD_START), 'PADBACK': ('btn', BTN.XUSB_GAMEPAD_BACK),
    }
except ImportError:
    HAS_GAMEPAD_LIB = False


def normalize_key(lua_key):
    lua_key = lua_key.upper().strip()
    modifiers = []
    if 'CTRL-' in lua_key: modifiers.append('ctrl'); lua_key = lua_key.replace('CTRL-', '')
    if 'ALT-' in lua_key: modifiers.append('alt'); lua_key = lua_key.replace('ALT-', '')
    if 'SHIFT-' in lua_key: modifiers.append('shift'); lua_key = lua_key.replace('SHIFT-', '')

    if HAS_GAMEPAD_LIB and lua_key in GAMEPAD_MAP:
        return {'type': 'gamepad', 'key': lua_key, 'modifiers': modifiers}

    key_map = {
        'MINUS': '-', 'EQUALS': '=', 'RETURN': 'enter', 'SPACE': 'space', 'TAB': 'tab',
        'LEFTBRACKET': '[', 'RIGHTBRACKET': ']', 'BACKSLASH': '\\',
        'SEMICOLON': ';', 'QUOTE': "'", 'COMMA': ',', 'PERIOD': '.', 'SLASH': '/'
    }
    clean_key = lua_key.replace('NUMPAD', 'num ') if 'NUMPAD' in lua_key else key_map.get(lua_key, lua_key.lower())
    return {'type': 'keyboard', 'modifiers': modifiers, 'key': clean_key}


def force_release_modifiers():
    """Safety net to unstick Windows modifiers."""
    for mod in ['ctrl', 'alt', 'shift']:
        keyboard.release(mod)


def execute_action(action):
    # Send modifiers using keyboard library
    for mod in action['modifiers']:
        keyboard.press(mod)

    try:
        press_duration = 0.02

        if action['type'] == 'keyboard':
            keyboard.press(action['key'])
            time.sleep(press_duration)
            keyboard.release(action['key'])

        elif action['type'] == 'gamepad' and HAS_GAMEPAD_LIB:
            data = GAMEPAD_MAP.get(action['key'])
            if data:
                g_type = data[0]
                if g_type == 'btn':
                    virtual_pad.press_button(button=data[1])
                    virtual_pad.update()
                    time.sleep(press_duration)
                    virtual_pad.release_button(button=data[1])
                elif g_type == 'trigger':
                    if data[1] == 'left':
                        virtual_pad.left_trigger(value=255)
                    else:
                        virtual_pad.right_trigger(value=255)
                    virtual_pad.update()
                    time.sleep(press_duration)
                    if data[1] == 'left':
                        virtual_pad.left_trigger(value=0)
                    else:
                        virtual_pad.right_trigger(value=0)
                elif g_type == 'stick':
                    side, x, y = data[1], data[2], data[3]
                    if side == 'left':
                        virtual_pad.left_joystick_float(x_value_float=x, y_value_float=y)
                    else:
                        virtual_pad.right_joystick_float(x_value_float=x, y_value_float=y)
                    virtual_pad.update()
                    time.sleep(press_duration)
                    if side == 'left':
                        virtual_pad.left_joystick_float(x_value_float=0.0, y_value_float=0.0)
                    else:
                        virtual_pad.right_joystick_float(x_value_float=0.0, y_value_float=0.0)

                virtual_pad.update()
    except Exception as e:
        print(f"Execute Error: {e}")
    finally:
        # Guarantee modifiers release
        for mod in reversed(action['modifiers']):
            keyboard.release(mod)
        if action['modifiers']:
            force_release_modifiers()


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
    try:
        ACTION_MAP = parse_lua_dataset('OliaEyes6.lua')
        camera = bettercam.create(region=(0, 0, 1, 1))
        fish = FishingEngine()
        is_auto = False

        print(f"Bot Context Restored. F4: Toggle Auto | Numpad 1-6: Manual (Hold to loop)")

        f4_was_pressed = False
        last_action_time = 0

        NUMPAD_VK_CODES = {1: 0x61, 2: 0x62, 3: 0x63, 4: 0x64, 5: 0x65, 6: 0x66}
        F4_VK_CODE = 0x73

        while True:
            current_time = time.time()

            # 1. Hardware-level F4 Toggle
            f4_is_pressed = (ctypes.windll.user32.GetAsyncKeyState(F4_VK_CODE) & 0x8000) != 0
            if f4_is_pressed and not f4_was_pressed:
                is_auto = not is_auto
                print(f"[System] AUTO-PILOT {'ENABLED' if is_auto else 'DISABLED'} (is_auto: {is_auto})")
            f4_was_pressed = f4_is_pressed

            # 2. Hardware-level Manual Keys
            manual_active = False
            for num_id, vk_code in NUMPAD_VK_CODES.items():
                if (ctypes.windll.user32.GetAsyncKeyState(vk_code) & 0x8000) != 0:
                    manual_active = True
                    break

            # --- DYNAMIC COOLDOWN ---
            # 0.05s if you are holding a manual key, 0.5s if it's running Auto mode
            active_cooldown = 0.05 if manual_active else 0.5

            # 3. Execution Logic with Dynamic Cooldown
            if (manual_active or is_auto) and (current_time - last_action_time > active_cooldown):

                if manual_active and is_auto:
                    is_auto = False
                    print(f"[System] MANUAL OVERRIDE: Auto-Pilot DISABLED")

                frame = camera.grab()
                if frame is not None:
                    pixel = tuple(frame[0][0])
                    if pixel in ACTION_MAP:
                        prefix = "Manual Action" if manual_active else "Auto Combat"
                        print(f"{prefix}: {ACTION_MAP[pixel]['name']}")
                        execute_action(ACTION_MAP[pixel])

                        last_action_time = time.time()

            # 4. Process Fishing loop unhindered
            fish.poll()
            time.sleep(0.01)
            
    except Exception as e:
        import traceback
        print("\n\n====== A CRITICAL ERROR OCCURRED ======")
        traceback.print_exc()
        print("=======================================\n")
        input("Press Enter to close this window...")