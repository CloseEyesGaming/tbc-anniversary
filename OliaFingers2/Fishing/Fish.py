import pyaudiowpatch as pyaudio
import soundfile as sf
import numpy as np
from scipy import signal
import pydirectinput
import threading
import time

import sys
import os

# --- CONFIGURATION (RESTORED FROM ORIGINAL) ---
TRIGGER_KEY = '`'
FISHING_KEY = 'u'
MIN_SCORE = 0.0035
MAX_SCORE = 0.0065

# Resolve TEMPLATE_FILE relative to sys._MEIPASS if frozen, otherwise relative to the parent directory of this file.
if getattr(sys, 'frozen', False):
    base_path = sys._MEIPASS
else:
    base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEMPLATE_FILE = os.path.join(base_path, "Fishing", "MasterTemplate.wav")


def normalize(data):
    peak = np.max(np.abs(data))
    return data / peak if peak != 0 else data


def trigger_action(score):
    """Original fast reaction timing"""
    print(f"\n>>> !!! BITE DETECTED (Score: {score:.5f}) !!! <<<")
    pydirectinput.keyDown(TRIGGER_KEY)
    time.sleep(0.05)
    pydirectinput.keyUp(TRIGGER_KEY)
    print(">>> CLICKED <<<")
    time.sleep(1.5)
    pydirectinput.keyDown(FISHING_KEY)
    time.sleep(0.05)
    pydirectinput.keyUp(FISHING_KEY)
    print("--- Scanning for bites ---")


class FishingEngine:
    def __init__(self):
        self.stream = None  # <--- ADD THIS LINE HERE
        try:
            data, file_fs = sf.read(TEMPLATE_FILE)
            if len(data.shape) > 1: data = np.mean(data, axis=1)
            self.template_raw = data
            self.p = pyaudio.PyAudio()
            wasapi = self.p.get_host_api_info_by_type(pyaudio.paWASAPI)

            # Universal loopback device search logic
            self.dev = None
            try:
                def_out = self.p.get_device_info_by_index(wasapi["defaultOutputDevice"])
                def_name = def_out["name"]
            except Exception:
                def_out = None
                def_name = ""

            # Helper generator to yield loopback devices across both pyaudiowpatch and standard pyaudio
            def get_loopback_devices():
                if hasattr(self.p, "get_loopback_device_info_generator"):
                    yield from self.p.get_loopback_device_info_generator()
                else:
                    for i in range(self.p.get_device_count()):
                        d = self.p.get_device_info_by_index(i)
                        if d.get("hostApi") == wasapi["index"]:
                            if d.get("isLoopbackDevice") or "LOOPBACK" in d["name"].upper() or "STEREO MIX" in d["name"].upper():
                                yield d

            # Tier 1: Search for loopback device matching default output device name
            if def_name:
                for loopback in get_loopback_devices():
                    if def_name in loopback["name"] or loopback["name"].startswith(def_name):
                        self.dev = loopback
                        break

            # Tier 2: Search for any loopback device containing common playback keywords
            if not self.dev:
                for loopback in get_loopback_devices():
                    lname = loopback["name"].upper()
                    if any(kw in lname for kw in ["SPEAKERS", "HEADPHONES", "LINE", "SYSTEM", "CABLE", "AUDIO"]):
                        self.dev = loopback
                        break

            # Tier 3: Grab the first available loopback device
            if not self.dev:
                for loopback in get_loopback_devices():
                    self.dev = loopback
                    break

            # <--- SAFETY CHECK --->
            if self.dev is None:
                print("[Fishing] Audio device not found. Fishing module disabled, but bot will continue running.")
                return

            print(f"[Fishing] Engine Active on: {self.dev['name']}")
            self.fs = int(self.dev["defaultSampleRate"])
            if self.fs != file_fs:
                num = round(len(self.template_raw) * float(self.fs) / file_fs)
                self.template_raw = signal.resample(self.template_raw, num)

            self.STEP_SIZE = int(self.fs * 0.1)
            self.window = np.zeros(int(len(self.template_raw) * 1.2), dtype=np.float32)
            self.stream = self.p.open(format=pyaudio.paFloat32, channels=int(self.dev["maxInputChannels"]),
                                      rate=self.fs, input=True, input_device_index=self.dev["index"],
                                      frames_per_buffer=self.STEP_SIZE)
            self.last_trigger = 0
        except Exception as e:
            print(f"[Fishing] Init Error: {e} - Fishing module disabled.")

    def poll(self):
        if self.stream is None: return
        if self.stream.get_read_available() < self.STEP_SIZE: return
        data = self.stream.read(self.STEP_SIZE, exception_on_overflow=False)
        new_audio = np.frombuffer(data, dtype=np.float32)
        if self.dev["maxInputChannels"] > 1:
            new_audio = np.mean(new_audio.reshape(-1, self.dev["maxInputChannels"]), axis=1)
        self.window = np.roll(self.window, -len(new_audio))
        self.window[-len(new_audio):] = new_audio
        if np.max(np.abs(self.window)) < 0.001: return

        window_norm = normalize(self.window)
        temp_norm = normalize(self.template_raw)
        corr = signal.correlate(window_norm, temp_norm, mode='valid', method='fft')
        score = np.max(np.abs(corr)) / len(temp_norm)

        if score > 0.001: print(f"Score: {score:.5f}")
        if MIN_SCORE <= score <= MAX_SCORE:
            if time.time() - self.last_trigger > 4.0:
                threading.Thread(target=trigger_action, args=(score,)).start()
                self.last_trigger = time.time()
                self.window.fill(0)