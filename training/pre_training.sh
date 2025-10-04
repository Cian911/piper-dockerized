#!/usr/bin/env bash
set -euo pipefail

python3 -m piper_train.preprocess \
  --language en-us \
  --input-dir ./ \
  --output-dir ./complete \
  --dataset-format ljspeech \
  --single-speaker \
  --sample-rate 22050
