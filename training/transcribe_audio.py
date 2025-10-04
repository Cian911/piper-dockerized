
import os
import whisper
import argparse

parser = argparse.ArgumentParser(
    description="Transcribe a folder of .wav files into a Piper-compatible metadata.csv",
    formatter_class=argparse.ArgumentDefaultsHelpFormatter
)

parser.add_argument(
    "--audio-dir",
    required=True,
    help="Directory containing .wav files."
)
parser.add_argument(
    "--output-csv",
    required=True,
    help="Path to output the generated csv file."
)
parser.add_argument(
    "--model",
    default="base",
    choices=["tiny","base","small","medium","large"],
    help="Which Whisper model to use."
)

args = parser.parse_args()

audio_dir = args.audio_dir
output_csv = args.output_csv

# Initialize Whisper model
print(f"Loading Whisper model: {args.model}")
model = whisper.load_model(args.model)

# List all .wav files in the directory
audio_files = [f for f in os.listdir(audio_dir) if f.lower().endswith(".wav")]
audio_files.sort()

# Open the CSV file for writing
with open(output_csv, "w", encoding="utf-8") as f:
    for audio_file in audio_files:
        audio_path = os.path.join(audio_dir, audio_file)

        print(f"Transcribing: {audio_file}")
        result = model.transcribe(audio_path)

        transcription = result["text"].strip()
        file_id = os.path.splitext(audio_file)[0]
        f.write(f"{file_id}|{transcription}\n")

print(f"Transcriptions complete! Metadata saved to {output_csv}")

