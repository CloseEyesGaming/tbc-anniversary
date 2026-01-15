import pyautogui
import time

# Disable Fail-Safe so mouse movement doesn't crash the bot
pyautogui.FAILSAFE = False

KEY_MAP = {
    # Modifiers
    'ALT': 'alt', 'CTRL': 'ctrl', 'SHIFT': 'shift',

    # Numpad
    'NUMPAD1': 'num1', 'NUMPAD2': 'num2', 'NUMPAD3': 'num3',
    'NUMPAD4': 'num4', 'NUMPAD5': 'num5', 'NUMPAD6': 'num6',

    # F-Keys
    'F1': 'f1', 'F2': 'f2', 'F3': 'f3', 'F4': 'f4', 'F5': 'f5', 'F6': 'f6',
    'F7': 'f7', 'F8': 'f8', 'F9': 'f9', 'F10': 'f10', 'F11': 'f11', 'F12': 'f12',

    # Misc
    'INSERT': 'insert', 'DELETE': 'delete', 'HOME': 'home', 'END': 'end',
    'PAGEUP': 'pageup', 'PAGEDOWN': 'pagedown',
    'UP': 'up', 'DOWN': 'down', 'LEFT': 'left', 'RIGHT': 'right',
    'SPACE': 'space', 'TAB': 'tab', 'ENTER': 'enter', 'ESC': 'esc'
}


def trigger_hotkey(hotkey_string):
    """
    Robust Hotkey Press for WoW (approx 100ms total execution time)
    """
    parts = hotkey_string.upper().split('-')

    keys = []
    for p in parts:
        keys.append(KEY_MAP.get(p, p.lower()))

    action_key = keys[-1]
    modifiers = keys[:-1]

    # 1. Hold Modifiers
    for mod in modifiers:
        pyautogui.keyDown(mod)

    # 2. Wait for Windows/Game to register Modifiers
    # time.sleep(0.02)

    # 3. Press Action Key (Hold 40ms)
    pyautogui.keyDown(action_key)
    # time.sleep(0.04)
    pyautogui.keyUp(action_key)

    # 4. Release Modifiers
    for mod in reversed(modifiers):
        pyautogui.keyUp(mod)