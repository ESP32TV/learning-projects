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
| Container | the repository devcontainer, base `espressif/idf-rust:all_1.95.0.0`, digest `sha256:1e78286d8e88da2624ad003b7c05c8db0a75e6a819b1e45662a1011a0d6d18c0` | `.devcontainer/Dockerfile` |
| Rust toolchain | `nightly-2026-04-26` | `rust-toolchain.toml` |
| ESP-IDF | `v6.1` | `ESP_IDF_VERSION` in `.cargo/config.toml` |
| Target | `riscv32imc-esp-espidf` | `.cargo/config.toml` |
| Rust crates | `esp-idf-svc` 0.53.0 and 187 more | `Cargo.lock` |

`esp-idf-sys` clones ESP-IDF at the pinned tag and installs its host tools into `.embuild/` on the
first build. That directory holds about 7 GB, it is not committed, and it is what the first build
spends its time on.

The version appears three times: `version` in `Cargo.toml`, which the example prints,
`CONFIG_APP_PROJECT_VER` in `sdkconfig.defaults`, which the ESP-IDF application descriptor prints as
`App version`, and the root package entry in `Cargo.lock`, which `cargo build --locked` requires to
match `Cargo.toml`. All three are declared in `ci.json`, so `bash tools/release.sh hello_world
--bump patch` moves them together. The release workflow fails when any of them disagrees with
another, and when they disagree with the tag.

## Build

No toolchain is installed on the host. The build runs in the repository devcontainer, which is also
what CI builds and uses, so a local result and a CI result come from the same image:

```bash
# from the repository root
docker build -t learning-projects-devcontainer:local .devcontainer
docker run --rm -v "$PWD/projects/hello_world":/project -w /project \
  learning-projects-devcontainer:local bash -lc 'cargo build --release --locked'
```

From VS Code, `Dev Containers: Reopen in Container` then `cargo build --release --locked` in the
project directory does the same.

The first build takes about eleven minutes because of the ESP-IDF install. Later builds reuse
`.embuild/`.

## Flash

Over USB from the same container, with the board attached:

```bash
docker run --rm -v "$PWD/projects/hello_world":/project -w /project --device=/dev/ttyUSB0 \
  learning-projects-devcontainer:local \
  bash -lc 'espflash flash --monitor target/riscv32imc-esp-espidf/release/hello_world'
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

## Building for another ESP32 chip

Nothing in `src/main.rs` is chip-specific, and the devcontainer already carries the toolchain for
every chip. Retargeting means changing two files and one flag: `target` and `MCU` in
`.cargo/config.toml`, `channel` in `rust-toolchain.toml`, and the `--chip` argument you merge and
flash with.

| MCU | Cargo target | Toolchain channel | esp-emulator |
| --- | --- | --- | --- |
| `esp32` | `xtensa-esp32-espidf` | `esp` | no |
| `esp32s2` | `xtensa-esp32s2-espidf` | `esp` | no |
| `esp32s3` | `xtensa-esp32s3-espidf` | `esp` | yes |
| `esp32c2` | `riscv32imc-esp-espidf` | `nightly-2026-04-26` + `rust-src` | no |
| `esp32c3` | `riscv32imc-esp-espidf` | `nightly-2026-04-26` + `rust-src` | yes |
| `esp32c5` | `riscv32imac-esp-espidf` | `nightly-2026-04-26` + `rust-src` | yes |
| `esp32c6` | `riscv32imac-esp-espidf` | `nightly-2026-04-26` + `rust-src` | yes |
| `esp32h2` | `riscv32imac-esp-espidf` | `nightly-2026-04-26` + `rust-src` | yes |
| `esp32p4` | `riscv32imafc-esp-espidf` | `nightly-2026-04-26` + `rust-src` | yes |

ESP-IDF installs the new chip's toolchain into `.embuild/` on the next build, so a retarget pays
that install once. Anything the chip needs configured beyond IDF's defaults goes in
`sdkconfig.defaults`.

The release workflow targets the ESP32-C3 only: its `CHIP` and `RUST_TARGET` environment variables,
the image name and the emulator boot check are set for that chip in
`.github/workflows/release.yml`. ESP32 and ESP32-S2 cannot be booted in esp-emulator, so a retarget
to those needs a board.

## Layout

| File | Purpose |
| --- | --- |
| `Cargo.toml` | crate `hello_world`, `esp-idf-svc` 0.53 |
| `Cargo.lock` | the resolved dependency set, the pin for this binary |
| `build.rs` | `embuild::espidf::sysenv::output()` |
| `rust-toolchain.toml` | Xtensa and RISC-V need specific toolchains; this pins `nightly-2026-04-26` with `rust-src` for `build-std` |
| `.cargo/config.toml` | target, `MCU`, `ESP_IDF_VERSION`, and `ESP_IDF_TOOLS_INSTALL_DIR=workspace` |
| `sdkconfig.defaults` | stack sizes the Rust main task needs, and the version for the IDF application descriptor |
| `ci.json` | release metadata: container, build environment, cache, version files, artifacts, emulator chip |
| `ci.sh` | the build steps. CI runs this file inside the container above, and it is the same command a developer runs |
| `src/main.rs` | the example |
