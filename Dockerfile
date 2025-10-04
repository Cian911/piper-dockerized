FROM nvidia/cuda:12.9.0-base-ubuntu22.04 AS build

RUN apt-get update -y && \
    apt-get install -y python3 pip python3-venv cmake build-essential ninja-build ffmpeg espeak-ng wget less

RUN mkdir -p /piper

COPY . /piper

WORKDIR /piper/src/python

RUN python3 -m pip install pip==23.3.1 && \
    pip install numpy==1.24.4 && \
    pip install torchmetrics==0.11.4 && \
    pip install -U openai-whisper

RUN pip3 install --upgrade wheel setuptools && \
    pip3 install -e .

RUN sh -c ./build_monotonic_align.sh

