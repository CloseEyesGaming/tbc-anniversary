import time
import dxcam
import win32api
from core import input_driver, lua_parser
import config


def main():
    print("--- OliaFingers v5.0 (LIVE) ---")

    # 1. Load Database
    color_db = lua_parser.parse_lua_dump(config.LUA_FILE_PATH)
    if not color_db:
        print(f"[Error] Database empty at {config.LUA_FILE_PATH}")
        return
    print(f"[Init] Loaded {len(color_db)} spells.")

    # 2. Start Camera (Strict 1x1 Pixel at 0,0)
    try:
        camera = dxcam.create(output_idx=0, output_color="BGR")
        region = (config.SCREEN_X, config.SCREEN_Y, config.SCREEN_X + 1, config.SCREEN_Y + 1)
        camera.start(region=region, target_fps=60)
    except Exception as e:
        print(f"[Error] Camera failed: {e}")
        return

    print(f"[Ready] Watching Pixel: {config.SCREEN_X}x{config.SCREEN_Y}")
    print("[Control] Hold Numpad 1-6 to activate.")

    last_cast_time = 0
    COOLDOWN = 0.1  # Minimum time between actions (prevent double-press)

    try:
        while True:
            active_trigger = None

            # --- TRIGGER CHECKS (Numpad) ---
            # Using simple boolean logic for speed
            if win32api.GetAsyncKeyState(0x61) < 0:
                active_trigger = "Thread 1"
            elif win32api.GetAsyncKeyState(0x62) < 0:
                active_trigger = "Thread 2"
            elif win32api.GetAsyncKeyState(0x63) < 0:
                active_trigger = "Thread 3"
            elif win32api.GetAsyncKeyState(0x64) < 0:
                active_trigger = "Thread 4"
            elif win32api.GetAsyncKeyState(0x65) < 0:
                active_trigger = "Thread 5"
            elif win32api.GetAsyncKeyState(0x66) < 0:
                active_trigger = "Thread 6"

            # If nothing held, sleep to save CPU
            if not active_trigger:
                time.sleep(0.01)
                continue

            # --- VISION LOGIC ---
            frame = camera.get_latest_frame()
            if frame is not None:
                # BGR -> RGB
                b, g, r = frame[0][0]
                current_color = (int(r), int(g), int(b))

                # Check Database
                hotkey = color_db.get(current_color)

                if hotkey and (time.time() - last_cast_time > COOLDOWN):
                    print(f"[{active_trigger}] Matched {current_color} -> Cast: {hotkey}")

                    input_driver.trigger_hotkey(hotkey)

                    last_cast_time = time.time()

                    # Optional: Small sleep after cast to let GCD start
                    time.sleep(0.05)

                    # Ultra fast loop when active
            time.sleep(0.01)

    except KeyboardInterrupt:
        print("\n[Stop] Bot Stopped.")
    finally:
        if 'camera' in locals():
            camera.stop()


if __name__ == "__main__":
    main()