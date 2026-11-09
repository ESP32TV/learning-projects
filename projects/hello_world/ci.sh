#!/usr/bin/env bash
# Build steps for hello_world.
#
# The release workflow runs this inside the container named in ci.json, with this
# directory as the working directory, and it is the same command a developer runs
# locally. Everything language-specific lives here, so the workflow holds no Rust
# knowledge.
#
# Expects APP, CHIP and RUST_TARGET in the environment, exported from ci.json.
set -euo pipefail

: "${APP:?APP is required}"
: "${CHIP:?CHIP is required}"
: "${RUST_TARGET:?RUST_TARGET is required}"

# The version appears in Cargo.toml, which the example prints, and in
# sdkconfig.defaults, which the ESP-IDF application descriptor prints. An image that
# advertises two versions is a defect, so the build refuses to make one.
crate_version="$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)"
descriptor_version="$(sed -n 's/^CONFIG_APP_PROJECT_VER="\(.*\)"/\1/p' sdkconfig.defaults | head -1)"
if [ "${crate_version}" != "${descriptor_version}" ]; then
    echo "CONFIG_APP_PROJECT_VER is '${descriptor_version}' but Cargo.toml says '${crate_version}'" >&2
    exit 1
fi
echo "version ${crate_version}: Cargo.toml and the IDF application descriptor agree"

cargo build --release --locked

# One file, written at 0x0: bootloader, partition table and application. Padding is
# skipped so the download is the image rather than a 4 MB flash window.
espflash save-image --chip "${CHIP}" --merge --skip-padding \
    "target/${RUST_TARGET}/release/${APP}" "${APP}-${CHIP}.bin"

ls -l "${APP}-${CHIP}.bin"
