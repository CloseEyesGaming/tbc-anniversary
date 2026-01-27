import pyaudiowpatch as pyaudio
import soundfile as sf
import numpy as np
from scipy import signal
import pydirectinput
import threading
import time

# --- CONFIGURATION (RESTORED FROM ORIGINAL) ---
TRIGGER_KEY = '`'
FISHING_KEY = 'u'
MIN_SCORE = 0.0035
MAX_SCORE = 0.0065
TEMPLATE_FILE = "Fishing/MasterTemplate.wav"


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
        try:
            data, file_fs = sf.read(TEMPLATE_FILE)
            if len(data.shape) > 1: data = np.mean(data, axis=1)
            self.template_raw = data
            self.p = pyaudio.PyAudio()
            wasapi = self.p.get_host_api_info_by_type(pyaudio.paWASAPI)

            # Original Device Search logic
            self.dev = None
            for i in range(self.p.get_device_count()):
                d = self.p.get_device_info_by_index(i)
                if d["hostApi"] == wasapi["index"] and "MAJOR III" in d["name"].upper() and d.get("isLoopbackDevice"):
                    self.dev = d
                    break
            if not self.dev:
                def_out = self.p.get_device_info_by_index(wasapi["defaultOutputDevice"])
                for i in range(self.p.get_device_count()):
                    d = self.p.get_device_info_by_index(i)
                    if d["name"] == def_out["name"] and d.get("isLoopbackDevice"):
                        self.dev = d
                        break

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
            print(f"[Fishing] Init Error: {e}")

    def poll(self):
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