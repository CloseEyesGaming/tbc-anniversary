import re
import keyboard


def test_keys(file_path):
    print(f"--- Testing Keybinds from {file_path} ---")

    # 1. Read the Lua file
    try:
        with open(file_path, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: Could not find file '{file_path}'")
        return

    # 2. Extract keys using Regex (looking for ["key"] = "SOMETHING")
    pattern = re.compile(r'\["key"\] = "(.*?)",', re.MULTILINE)
    matches = pattern.findall(content)

    print(f"Found {len(matches)} key definitions. Validating...\n")

    errors = []

    # 3. Iterate and Validate
    for original_key in matches:
        # Apply your transformation logic here
        # We add replacements for common Lua vs Python key naming mismatches
        formatted_key = (original_key.lower()
                         .replace('-', '+')  # Lua uses '-', keyboard uses '+' for combos
                         .replace('equals', '=')  # Fixes 'equals' error
                         .replace('minus', '-')  # Fixes 'minus' error
                         .replace('numpad', 'num ')  # Fixes 'NUMPAD1' -> 'num 1'
                         .replace('pageup', 'page up')
                         .replace('pagedown', 'page down')
                         # Add more replacements here if new errors appear
                         )

        try:
            # We use parse_hotkey to check if the library understands the string.
            # This throws a ValueError if the key is unknown.
            keyboard.parse_hotkey(formatted_key)
            # print(f"[OK] {original_key} -> {formatted_key}") # Uncomment to see all passes

        except ValueError as e:
            # Capture the failure
            errors.append((original_key, formatted_key, str(e)))
        except Exception as e:
            errors.append((original_key, formatted_key, f"Unexpected error: {e}"))

    # 4. Report Results
    if not errors:
        print("✅ SUCCESS: All keys passed validation!")
    else:
        print(f"❌ FAILURE: {len(errors)} keys failed validation.\n")
        print(f"{'Original Lua Key':<20} | {'Formatted Python Key':<20} | {'Error Message'}")
        print("-" * 80)
        for orig, fmt, err in errors:
            print(f"{orig:<20} | {fmt:<20} | {err}")


if __name__ == "__main__":
    # Make sure OliaEyes6.lua is in the same folder, or provide full path
    test_keys('OliaEyes6.lua')