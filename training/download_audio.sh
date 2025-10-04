#!/bin/sh
# download_audio_from_csv.sh
# POSIX /bin/sh version (no bashisms).
#
# Usage:
#   sh download_audio_from_csv.sh urls.csv [out_dir] [audio_format] [quality]
# Examples:
#   sh download_audio_from_csv.sh urls.csv
#   sh download_audio_from_csv.sh urls.csv out m4a
#   sh download_audio_from_csv.sh urls.csv out opus 192k

set -eu

CSV_FILE="${1:-urls.csv}"
OUT_DIR="${2:-audio_out}"
AUDIO_FORMAT="${3:-mp3}"     # mp3|m4a|opus|flac|wav|aac|alac
AUDIO_QUALITY="${4:-0}"      # mp3: 0(best)–9(worst). For opus/aac/etc you can use bitrate like 192k.

# ---- Dependency checks --------------------------------------------------------
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: '$1' is required but not found in PATH." >&2
    exit 1
  }
}
need_cmd yt-dlp
need_cmd ffmpeg
need_cmd sort
need_cmd sed
need_cmd tr

# ---- Inputs ------------------------------------------------------------------
if [ ! -f "$CSV_FILE" ]; then
  echo "Error: CSV file not found: $CSV_FILE" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# ---- Normalize CSV to a unique URL list --------------------------------------
# - Replace commas and CRs with newlines
# - Trim leading/trailing whitespace
# - Drop empty lines
# - Deduplicate
TMP_URLS="$(mktemp)"
trap 'rm -f "$TMP_URLS"' EXIT

tr ',\r' '\n' < "$CSV_FILE" \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | sed '/^$/d' \
  | sort -u > "$TMP_URLS"

if [ ! -s "$TMP_URLS" ]; then
  echo "No URLs found in $CSV_FILE"
  exit 0
fi

COUNT="$(wc -l < "$TMP_URLS" | tr -d '[:space:]')"
echo "Found $COUNT unique URL(s). Saving audio to: $OUT_DIR"
echo

# ---- Download loop ------------------------------------------------------------
# -N 4             : up to 4 connections per download (faster)
# -f bestaudio/best: choose best available audio
# --extract-audio  : extract audio only
# --audio-format   : target audio format (mp3/m4a/opus/...)
# --audio-quality  : encoder quality (varies by format)
# --no-playlist    : don't expand playlists accidentally
# -o template      : unique filename with title + video id
while IFS= read -r url; do
  echo ">>> Downloading: $url"
  if ! yt-dlp \
      -N 4 \
      -f bestaudio/best \
      --extract-audio \
      --audio-format "$AUDIO_FORMAT" \
      --audio-quality "$AUDIO_QUALITY" \
      --no-playlist \
      -o "$OUT_DIR/%(title)s [%(id)s].%(ext)s" \
      "$url"
  then
    echo "!!! Failed: $url" >&2
  fi
  echo
done < "$TMP_URLS"

echo "All done. Files saved in: $OUT_DIR"

