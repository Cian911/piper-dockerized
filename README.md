# Piper (Dockerized) — End-to-End Voice Training

Train a custom Piper TTS voice using Docker, with helper scripts to gather, process, split, transcribe, and train.

> Inspired by [NetworkChuck’s workflow](https://blog.networkchuck.com/posts/how-to-clone-a-voice/?utm_source=chatgpt.com) (record/YouTube → local processing → Piper training).

Repo note: Upstream Piper development has moved to [OHF-Voice/piper1-gpl](https://github.com/OHF-Voice/piper1-gpl), but this project packages the classic pipeline in a Docker workflow.
---

## Prereqs

- NVIDIA GPU + drivers + nvidia-container-toolkit
- Docker & Compose v2
- This repo cloned:

```bash
git clone https://github.com/Cian911/piper-dockerized.git
cd piper-dockerized
```
---

## Quickstart

```bash
# 0) (Recommended) Use the Docker training image from repo root
docker compose build
docker compose run --rm --gpus all training bash
cd training

# 1) Download audio from a CSV list of URLs (YouTube, etc.)
#    CSV can be comma or newline separated.
./download_audio.sh urls.csv audio_out m4a

# 2) Post-process: rename -> trim trailing silence -> split into 15s chunks
./post_process_audio.sh
# outputs into audio_out_post/ and audio_out_post/split/

# 3) Transcribe split WAVs to Piper-style metadata.csv
python3 transcribe_audio.py \
  --audio-dir audio_out_post/split \
  --output-csv metadata.csv \
  --model large

# 4) Preprocess to Piper dataset (creates ./complete with cache)
./pre_training.sh

# 5) Train (example hyperparams — tune for your GPU/data)
python3 -m piper_train \
  --dataset-dir ./ \
  --accelerator gpu \
  --batch-size 16 \
  --validation-split 0.0 \
  --num-test-examples 0 \
  --max_epochs 5000 \
  --checkpoint-epochs 1 \
  --quality medium \
  --max-phoneme-ids 400 \
  --resume_from_checkpoint checkpoint/last.ckpt

# 6) (Optional) Export to ONNX for fast runtime + test synthesis
# (Use your export method or piper’s tools; see “Export” below.)

```
---

## Step-By-Step

**(Optional - but highly recommended) Get a baseline checkpoint**

You can start from a known checkpoint to speed convergence.

```bash
mkdir -p checkpoint
wget -O checkpoint/lessac-medium.ckpt \
  "https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/main/en/en_US/lessac/medium/epoch%3D2164-step%3D1355540.ckpt"
```

You can then pass `--resume_from_checkpoint checkpoint/lessac-medium.ckpt` at training time.
---

### 1. Download Audio (download_audio.sh)

```bash
# Usage:
# ./download_audio.sh urls.csv [out_dir] [audio_format] [quality]

# Examples:
./download_audio.sh urls.csv               # -> audio_out/*.wav (VBR 0)
./download_audio.sh urls.csv audio_out m4a # -> audio_out/*.wav
./download_audio.sh urls.csv audio_out opus 192k
```

- Accepts CSV with commas/newlines; dedupes URLs.
- Uses yt-dlp to grab best audio and extract to your chosen format.
- For best results, ensure to download in `.wav` format.
---

### 2. Post-process and split (post_process_audio.sh)

```bash
./post_process_audio.sh
```

What it does:

- **Rename** `audio_out/*.wav` → `audio_out_post/audio_0000.wav`, `audio_0001.wav`, …
- **Trim** trailing silence (silenceremove with 3s @ −20 dB) → writes `*_nosilence.wav`.
- **Split** each `*_nosilence.wav` into **15s segments** → `audio_out_post/split/<stem>_000.wav`, etc.
---

### 3. Transcribe to `metadata.csv` (`transscribe_audio.py`)

```bash
python3 transcribe_audio.py \
  --audio-dir audio_out_post/split \
  --output-csv metadata.csv \
  --model large
```

- Loads Whisper, transcribes each WAV, and writes pipe-separated lines.
---

### 4. Preprocess to Piper dataset (`pre_training.sh`)

```bash
./pre_training.sh
```

This runs:

```bash
python3 -m piper_train.preprocess \
  --language en-us \
  --input-dir ./ \
  --output-dir ./complete \
  --dataset-format ljspeech \
  --single-speaker \
  --sample-rate 22050
```

- It consumes your **LJSpeech-style** layout (i.e., `metadata.csv` in the cwd) and produces a complete dataset folder with cached features under `./complete/cache/22050/*.pt`.
- Keep your `metadata.csv` in the same directory you run this from (here: `training/`).
---

### 5. Train

```bash
python3 -m piper_train \
  --dataset-dir ./ \
  --accelerator gpu \
  --batch-size 16 \
  --validation-split 0.0 \
  --num-test-examples 0 \
  --max_epochs 5000 \
  --checkpoint-epochs 1 \
  --quality medium \
  --max-phoneme-ids 400 \
  --resume_from_checkpoint checkpoint/lessac-medium.ckpt
`
```

- If you see **Skipped N utterances**, inspect outliers in `metadata.csv` (very short/long clips, empty text).
- If you hit **FileNotFoundError** for `complete/cache/...pt`, re-run preprocess (Step 4) and verify you’re launching from the folder that contains `metadata.csv` and `complete/`.
---

### 6. Export & Test

Export using ONNX, then synthesize:

```bash
piper --model export/my_voice/model.onnx \
      --output_file out.wav \
      --text "Alright, alright, alright. Time is a flat pond."
```

### Troubleshooting & tips

- **Docker GPU**: If Compose doesn’t auto-expose GPU, run with --gpus all (as shown).
- **Dataloader speed**: consider adding --num-workers 8 to training if IO bound.
- **Audio quality**: cleaner > more. Avoid music/overlapping speech. Keep segments ~1–12 s.
- **Sample rate**: 22050 Hz is a solid trade-off for training + runtime speed.
- **Safe moves**: post_process_audio.sh moves original WAVs from audio_out/ to audio_out_post/. If you want to keep originals, copy instead.
