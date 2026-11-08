# hello_world

A minimal Rust example for the ESP32-C3. It boots, prints which crate version, which chip target
and which ESP-IDF it was built against, greets once, and returns from `app_main`.

It exists to prove the release path of this repository on one small project: a merged image
anybody can download, flash and boot on a board they did not build it on.

Expected console output:

```
I (45) hello_world: hello_world 0.1.0 targeting esp32c3
I (45) hello_world: built against ESP-IDF v6.1
I (45) hello_world: Hello, world!
```

## Versions

| Component | Version | Where it is pinned |
| --- | --- | --- |
| Rust container | `espressif/idf-rust:esp32c3_1.95.0.0`, digest `sha256:bb4c85481f98f1f00a38f1bf4f3d15451e61b55f7038b74a600994d630d21750` | `README.md`, `.github/workflows/release.yml` |
| Rust toolchain | `nightly-2026-04-26` | `rust-toolchain.toml` |
| ESP-IDF | `v6.1` | `ESP_IDF_VERSION` in `.cargo/config.toml` |
| Target | `riscv32imc-esp-espidf` | `.cargo/config.toml` |
| Rust crates | `esp-idf-svc` 0.53.0 and 187 more | `Cargo.lock` |

`esp-idf-sys` clones ESP-IDF at the pinned tag and installs its host tools into `.embuild/` on the
first build. That directory holds about 2.8 GB and is not committed.

The version appears twice: `version` in `Cargo.toml`, which the example prints, and
`CONFIG_APP_PROJECT_VER` in `sdkconfig.defaults`, which the ESP-IDF application descriptor prints as
`App version`. The release workflow fails when the two disagree, and when either disagrees with the
tag.

## Build

No toolchain is installed on the host:

```bash
docker run --rm -v "$PWD":/project -w /project -e USER=esp \
  espressif/idf-rust@sha256:bb4c85481f98f1f00a38f1bf4f3d15451e61b55f7038b74a600994d630d21750 \
  bash -lc 'source /home/esp/export-esp.sh && cargo build --release --locked'
```

The first build takes several minutes because of the ESP-IDF install. Later builds reuse
`.embuild/`.

## Flash

Over USB from the same container, with the board attached:

```bash
docker run --rm -v "$PWD":/project -w /project --device=/dev/ttyUSB0 \
  espressif/idf-rust@sha256:bb4c85481f98f1f00a38f1bf4f3d15451e61b55f7038b74a600994d630d21750 \
  bash -lc 'source /home/esp/export-esp.sh && espflash flash --monitor target/riscv32imc-esp-espidf/release/hello_world'
```

## Release image

Each release carries `hello_world-esp32c3.bin`, a merged image holding the bootloader, the
partition table and the application. It is written at `0x0`:

```bash
curl -LO https://github.com/ESP32TV/learning-projects/releases/download/hello_world/v0.1.0/hello_world-esp32c3.bin
curl -LO https://github.com/ESP32TV/learning-projects/releases/download/hello_world/v0.1.0/SHA256SUMS
sha256sum -c SHA256SUMS
esptool --chip esp32c3 -p /dev/ttyUSB0 -b 460800 write-flash 0x0 hello_world-esp32c3.bin
```

`SHA256SUMS` identifies the build. ESP-IDF embeds build metadata in the image, so a rebuild from
the same sources is functionally identical, not byte-identical.

## Run without hardware

The merged image boots in [esp-emulator](https://github.com/espressif/esp-emulator), which is also
what the release workflow checks before publishing:

```bash
esp-emu --chip esp32c3 --firmware hello_world-esp32c3.bin --timeout 60s --exit-on 'Hello, world!'
```

## Layout

| File | Purpose |
| --- | --- |
| `Cargo.toml` | crate `hello_world`, `esp-idf-svc` 0.53 |
| `Cargo.lock` | the resolved dependency set, the pin for this binary |
| `build.rs` | `embuild::espidf::sysenv::output()` |
| `rust-toolchain.toml` | Xtensa and RISC-V need specific toolchains; this pins `nightly-2026-04-26` with `rust-src` for `build-std` |
| `.cargo/config.toml` | target, `MCU`, `ESP_IDF_VERSION`, and `ESP_IDF_TOOLS_INSTALL_DIR=workspace` |
| `sdkconfig.defaults` | stack sizes the Rust main task needs |
| `src/main.rs` | the example |
