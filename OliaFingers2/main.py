import bettercam
import keyboard
import re
import time


def parse_lua_dataset(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    pattern = re.compile(r'\{[\s\S]*?\["key"\] = "(.*?)",[\s\S]*?\["id"\] = "(.*?)",[\s\S]*?\["color"\] = "(.*?)",',
                         re.MULTILINE)
    matches = pattern.findall(content)
    dataset = {}
    for key_name, action_id, hex_color in matches:
        r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)
        formatted_key = key_name.lower().replace('-', '+')
        dataset[(r, g, b)] = formatted_key
    print(f"Parsed {len(dataset)} actions.")
    return dataset


ACTION_MAP = parse_lua_dataset('OliaEyes6.lua')
camera = bettercam.create(region=(0, 0, 1, 1))
TRIGGER_KEYS = ['num 1', 'num 2', 'num 3', 'num 4', 'num 5', 'num 6']

print("Bot standby. Hold Numpad 1-6 to start scanning.")

try:
    while True:
        # Check if ANY of the trigger keys are currently held down
        active = any(keyboard.is_pressed(k) for k in TRIGGER_KEYS)

        if active:
            frame = camera.grab()
            if frame is not None:
                pixel = tuple(frame[0][0])
                if pixel in ACTION_MAP:
                    key_to_press = ACTION_MAP[pixel]
                    # Press and Release
                    keyboard.press_and_release(key_to_press)

                    # Prophylactic cooldown: prevents the bot from spamming
                    # the same key while you are holding the trigger
                    time.sleep(0.1)
            else:
                # If frame is None, the camera is likely waiting for a screen change
                # Tiny sleep to prevent CPU spiking
                time.sleep(0.001)
        else:
            # When NO keys are held, sleep longer to save CPU
            time.sleep(0.02)

except KeyboardInterrupt:
    print("Shutting down.")