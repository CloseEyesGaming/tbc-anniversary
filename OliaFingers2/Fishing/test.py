import pyaudiowpatch as pyaudio
import numpy as np
import time


def listen_to_headphones():
    p = pyaudio.PyAudio()
    print("--- SEARCHING FOR MAJOR III HEADPHONES ---")

    # 1. Find the WASAPI Host (Required for Loopback)
    try:
        wasapi_info = p.get_host_api_info_by_type(pyaudio.paWASAPI)
    except OSError:
        print("Error: WASAPI host not found.")
        return

    target_device = None

    # 2. Scan for a Loopback device matching "MAJOR III"
    for i in range(p.get_device_count()):
        dev = p.get_device_info_by_index(i)

        # Must be WASAPI
        if dev["hostApi"] != wasapi_info["index"]:
            continue

        # Check name for your headphones
        if "MAJOR III" in dev["name"].upper():
            print(f"Found: {dev['name']} (ID: {i})")

            # We specifically want the Loopback (Input) version
            if dev["maxInputChannels"] > 0 and dev.get("isLoopbackDevice") is True:
                target_device = dev
                break
            else:
                print(f"   -> Skipping ID {i} (It is an Output, not a Loopback Input)")

    # 3. If not found, try default loopback as fallback
    if target_device is None:
        print("\n[!] Could not find a specific Loopback for Major III.")
        print("This usually means the Bluetooth driver blocks internal recording.")
        print("Trying default system loopback as a Hail Mary...\n")
        try:
            default_out = p.get_device_info_by_index(wasapi_info["defaultOutputDevice"])
            # Find loopback for default
            for i in range(p.get_device_count()):
                d = p.get_device_info_by_index(i)
                if d["name"] == default_out["name"] and d["maxInputChannels"] > 0 and d.get("isLoopbackDevice"):
                    target_device = d
                    break
        except:
            pass

    if target_device is None:
        print("CRITICAL ERROR: No loopback device found.")
        return

    # 4. Listen
    print(f"\n>>> ATTEMPTING CONNECTION TO: {target_device['name']} (ID: {target_device['index']}) <<<")
    print("Play music now! Press Ctrl+C to stop.")

    try:
        stream = p.open(format=pyaudio.paFloat32,
                        channels=int(target_device["maxInputChannels"]),
                        rate=int(target_device["defaultSampleRate"]),
                        input=True,
                        input_device_index=target_device["index"],
                        frames_per_buffer=1024)

        while True:
            data = stream.read(1024, exception_on_overflow=False)
            audio = np.frombuffer(data, dtype=np.float32)
            volume = np.max(np.abs(audio))

            # Print a visual bar
            bars = "|" * int(volume * 50)
            if volume > 0.01:
                print(f"Vol: {volume:.4f} {bars}")

    except OSError as e:
        print(f"\n[Error] Windows blocked the connection: {e}")
        print("Bluetooth drivers often disable loopback to prevent recording.")
        print("SOLUTION: You MUST install 'VB-Cable' or use 'Stereo Mix' bridge.")


if __name__ == "__main__":
    listen_to_headphones()