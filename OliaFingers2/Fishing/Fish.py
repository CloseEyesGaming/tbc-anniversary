import pyaudiowpatch as pyaudio
import soundfile as sf
import numpy as np
from scipy import signal
import pydirectinput
import threading
import time
import random

# --- CONFIGURATION ---
TRIGGER_KEY = '6'
FISHING_KEY = '7'

# Expanded range slightly to catch edge cases
MIN_SCORE = 0.0035
MAX_SCORE = 0.0065

TEMPLATE_FILE = "MasterTemplate.wav"


# ---------------------

def load_template(filename):
    data, fs = sf.read(filename)
    if len(data.shape) > 1: data = np.mean(data, axis=1)
    return data, fs


def normalize(data):
    peak = np.max(np.abs(data))
    if peak == 0: return data
    return data / peak


def trigger_action(score):
    print(f"\n>>> !!! INSTANT TRIGGER (Score: {score:.5f}) !!! <<<")

    # Super fast reaction
    pydirectinput.keyDown(TRIGGER_KEY)
    time.sleep(0.05)
    pydirectinput.keyUp(TRIGGER_KEY)

    print(">>> CLICKED <<<")
    # Cooldown
    time.sleep(1.0)
    print("Fish cast")
    pydirectinput.keyDown(FISHING_KEY)
    time.sleep(0.05)
    pydirectinput.keyUp(FISHING_KEY)
    print("--- Scanning ---")


def start_fast_debug_bot():
    print("--- HIGH SPEED DEBUG BOT ---")
    print(f"Target Range: {MIN_SCORE} < Score < {MAX_SCORE}")

    # 1. Load Template
    try:
        template_raw, file_fs = load_template(TEMPLATE_FILE)
    except FileNotFoundError:
        print("ERROR: MasterTemplate.wav missing.")
        return

    p = pyaudio.PyAudio()

    # 2. Find Device
    wasapi = p.get_host_api_info_by_type(pyaudio.paWASAPI)
    dev = None
    for i in range(p.get_device_count()):
        d = p.get_device_info_by_index(i)
        if d["hostApi"] == wasapi["index"] and "MAJOR III" in d["name"].upper() and d.get("isLoopbackDevice"):
            dev = d;
            break
    if not dev:
        def_out = p.get_device_info_by_index(wasapi["defaultOutputDevice"])
        for i in range(p.get_device_count()):
            d = p.get_device_info_by_index(i)
            if d["name"] == def_out["name"] and d.get("isLoopbackDevice"):
                dev = d;
                break

    print(f"Listening on: {dev['name']}")
    fs = int(dev["defaultSampleRate"])

    # Resample template
    if fs != file_fs:
        num = round(len(template_raw) * float(fs) / file_fs)
        template_raw = signal.resample(template_raw, num)

    template_len = len(template_raw)
    if template_len == 0: template_len = int(fs * 0.5)

    # --- SLIDING WINDOW SETUP ---
    # Window = 1.2x template length (tight fit for speed)
    WINDOW_SIZE = int(template_len * 1.2)
    # Step = Update 10 times per second
    STEP_SIZE = int(fs * 0.1)

    window = np.zeros(WINDOW_SIZE, dtype=np.float32)
    stream = p.open(format=pyaudio.paFloat32, channels=int(dev["maxInputChannels"]),
                    rate=fs, input=True, input_device_index=dev["index"],
                    frames_per_buffer=STEP_SIZE)

    last_trigger = 0
    print(f"\n[LIVE SCORE FEED] (Updates every 0.1s)")

    try:
        while True:
            # 1. Read small chunk
            data = stream.read(STEP_SIZE, exception_on_overflow=False)
            new_audio = np.frombuffer(data, dtype=np.float32)

            # Mono
            if dev["maxInputChannels"] > 1:
                new_audio = new_audio.reshape(-1, dev["maxInputChannels"])
                new_audio = np.mean(new_audio, axis=1)

            # 2. Update Window
            window = np.roll(window, -len(new_audio))
            window[-len(new_audio):] = new_audio

            # Skip calculation if silence (saves CPU)
            if np.max(np.abs(window)) < 0.001:
                continue

            # 3. Calculate Score
            score = 0.0
            window_norm = normalize(window)
            temp_norm = normalize(template_raw)

            corr = signal.correlate(window_norm, temp_norm, mode='valid', method='fft')
            score = np.max(np.abs(corr)) / len(temp_norm)

            # 4. DEBUG PRINT (Show everything above 0.001)
            if score > 0.001:
                status = " "
                if MIN_SCORE <= score <= MAX_SCORE: status = "<<< TARGET >>>"
                print(f"Score: {score:.5f} {status}")

            # 5. TRIGGER
            if MIN_SCORE <= score <= MAX_SCORE:
                if time.time() - last_trigger > 4.0:
                    threading.Thread(target=trigger_action, args=(score,)).start()
                    last_trigger = time.time()
                    # Clear window
                    window.fill(0)

    except KeyboardInterrupt:
        p.terminate()


if __name__ == "__main__":
    start_fast_debug_bot()