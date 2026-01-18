import soundfile as sf
import numpy as np


def create_master_template():
    print("--- GENERATING MASTER TEMPLATE ---")

    # Load the debug recording you just made
    try:
        data, fs = sf.read("debug_audio.wav")
    except FileNotFoundError:
        print("Error: debug_audio.wav not found! Run the recorder script again.")
        return

    # Convert to Mono
    if len(data.shape) > 1:
        data = np.mean(data, axis=1)

    # We only care about the first 3 seconds where you said the sound is
    max_samples = int(3 * fs)
    data = data[:max_samples]

    # Find the loudest point (The Splash)
    peak_index = np.argmax(np.abs(data))

    # Cut a 1.5 second chunk around that peak
    # (0.2s before peak, 1.3s after peak)
    start = max(0, peak_index - int(0.9 * fs))
    end = min(len(data), start + int(2.0 * fs))

    template_data = data[start:end]

    # Save it
    sf.write("MasterTemplate.wav", template_data, fs)
    print(f"Success! Found splash at {peak_index / fs:.2f}s.")
    print("Saved 'MasterTemplate.wav'. This is your perfect reference sound.")


if __name__ == "__main__":
    create_master_template()