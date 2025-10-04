
#!/usr/bin/env bash
set -euo pipefail

AUDIO_OUT_FLDR="audio_out"         # input .wav files
POST_AUDIO_FLDR="audio_out_post"   # renamed + processed files go here
POST_AUDIO_SPLIT_FLDR="split"      # segments go here

mkdir -p "${POST_AUDIO_FLDR}"
mkdir -p "${POST_AUDIO_FLDR}/${POST_AUDIO_SPLIT_FLDR}"

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found in PATH"; exit 1; }

# Bash glob behavior: no-match => empty array instead of literal pattern
shopt -s nullglob

# ------------------------------------------------------------------------------
# 1) Rename input files to a clean, sequential set: audio_0000.wav, ...
# ------------------------------------------------------------------------------
counter=0
# snapshot of inputs
inputs=( "${AUDIO_OUT_FLDR}"/*.wav )
if ((${#inputs[@]} == 0)); then
  echo "No .wav files found in ${AUDIO_OUT_FLDR}"
  exit 0
fi

for file in "${inputs[@]}"; do
  dest="${POST_AUDIO_FLDR}/audio_$(printf '%04d' "$counter").wav"
  # -v for visibility; -- to stop option parsing
  mv -v -- "$file" "$dest"
  counter=$((counter+1))
done
echo "Renamed ${#inputs[@]} file(s) into ${POST_AUDIO_FLDR}"

# ------------------------------------------------------------------------------
# 2) Remove trailing silence from the *renamed* files.
#    Writes alongside each file: audio_0000_nosilence.wav
# ------------------------------------------------------------------------------
# snapshot only the *base* renamed wavs (exclude any *_nosilence.wav if present)
to_trim=( "${POST_AUDIO_FLDR}"/audio_*.wav )
# filter out *_nosilence.wav just in case
tmp=()
for f in "${to_trim[@]}"; do
  [[ "$f" == *_nosilence.wav ]] && continue
  tmp+=( "$f" )
done
to_trim=( "${tmp[@]}" )

if ((${#to_trim[@]} == 0)); then
  echo "No base files found in ${POST_AUDIO_FLDR} to trim."
else
  for file in "${to_trim[@]}"; do
    base="${file%.wav}"
    out="${base}_nosilence.wav"
    ffmpeg -hide_banner -loglevel warning -y \
      -i "$file" \
      -af "silenceremove=stop_periods=-1:stop_duration=3:stop_threshold=-20dB" \
      "$out"
  done
fi

# ------------------------------------------------------------------------------
# 3) Split *_nosilence.wav into 15s chunks to audio_out_post/split/...
# ------------------------------------------------------------------------------
trimmed=( "${POST_AUDIO_FLDR}"/*_nosilence.wav )
if ((${#trimmed[@]} == 0)); then
  echo "No *_nosilence.wav files found to split."
else
  for file in "${trimmed[@]}"; do
    name="$(basename "$file")"             # e.g., audio_0000_nosilence.wav
    stem="${name%.*}"                      # e.g., audio_0000_nosilence
    out_tpl="${POST_AUDIO_FLDR}/${POST_AUDIO_SPLIT_FLDR}/${stem}_%03d.wav"
    ffmpeg -hide_banner -loglevel warning -y \
      -i "$file" \
      -f segment -segment_time 15 -c copy \
      "$out_tpl"
  done
fi

echo "Done. Segments in: ${POST_AUDIO_FLDR}/${POST_AUDIO_SPLIT_FLDR}"

