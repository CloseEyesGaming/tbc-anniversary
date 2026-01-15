# core/lua_parser.py
import re


def parse_lua_dump(filepath):
    """
    Reads the LUA file and returns a dict: { (R, G, B): "HOTKEY_STRING" }
    """
    color_map = {}
    try:
        with open(filepath, "r") as f:
            content = f.read()
    except FileNotFoundError:
        print(f"[Error] Could not find file: {filepath}")
        return {}

    # Regex to extract ["key"] and ["color"] from the Lua table
    # Matches: ["key"] = "CTRL-F1", ... ["color"] = "3c734e",
    pattern = re.compile(r'\["key"\]\s*=\s*"(.*?)",.*?\["color"\]\s*=\s*"(.*?)"', re.DOTALL)

    matches = pattern.findall(content)

    for key_str, hex_color in matches:
        # Convert Hex string "3c734e" -> RGB Tuple (60, 115, 78)
        if len(hex_color) == 6:
            r = int(hex_color[0:2], 16)
            g = int(hex_color[2:4], 16)
            b = int(hex_color[4:6], 16)

            # Store as tuple for fast dictionary lookup
            color_map[(r, g, b)] = key_str

    print(f"[Parser] Successfully loaded {len(color_map)} bindings.")
    return color_map