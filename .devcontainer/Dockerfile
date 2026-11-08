# Development container for every project in this repository.
#
# It carries the Rust toolchains and espflash for all current ESP32 chips, which is
# what a Rust example needs to build and flash. ESP-IDF is not baked in: each
# project fetches the IDF version pinned in its own .cargo/config.toml
# (ESP_IDF_VERSION) into that project's .embuild/ on the first build. That is what
# lets two projects sit on different IDF tags without fighting over one container.
#
# A C/C++ example needs an IDF tree on PATH, which this image does not have. When
# the first one lands, either add an IDF stage here and have Rust projects unset
# IDF_PATH, or give that project its own .devcontainer/. See README.md.
#
# Pinned by digest. `espressif/idf-rust:all_1.95.0.0` is the tag a human reads;
# this digest is the image the tested container was built from.
FROM espressif/idf-rust:all_1.95.0.0@sha256:1e78286d8e88da2624ad003b7c05c8db0a75e6a819b1e45662a1011a0d6d18c0

USER root

# Host packages the esp-idf-sys build and espflash need, matching what the upstream
# esp-idf-template container installs.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        pkg-config \
        curl \
        gcc \
        clang \
        libudev-dev \
        unzip \
        xz-utils \
        git \
        wget \
        flex \
        bison \
        gperf \
        python3 \
        python3-pip \
        python3-venv \
        cmake \
        ninja-build \
        ccache \
        libffi-dev \
        libssl-dev \
        dfu-util \
        libusb-1.0-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER esp

# The toolchains the image ships are already on PATH for the esp user; sourcing this
# adds the installed GCC for Xtensa chips.
RUN echo 'source /home/esp/export-esp.sh' >> /home/esp/.bashrc
