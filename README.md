# learning-projects

Example projects for the **ESP32TV learning library**. Each example is a complete, buildable
project that demonstrates one thing on real hardware — audio, display, camera, on-device ML,
networking — with no cloud dependency unless the example says otherwise.

Examples are written in **C/C++** or in **Rust**. Both kinds live side by side here; each
project's `README.md` and the table below say which one it is, and which ESP-IDF version it is
built against.

## Layout

```
learning-projects/
└── projects/
    └── <example>/          # one self-contained project
        ├── CMakeLists.txt  # C/C++ projects: ESP-IDF project root
        ├── Cargo.toml      # Rust projects: cargo crate root
        ├── main/           # application sources (C/C++)
        ├── sdkconfig.defaults
        └── README.md       # what it does, what it needs, how to run it
```

Every directory under `projects/` is a standalone project: C/C++ examples are plain ESP-IDF
CMake projects, Rust examples are cargo crates. Each can be built, flashed and copied out
without the rest of this repository.

## Projects

| Project | Summary | SoC | Devkit | ESP-IDF |
| --- | --- | --- | --- | --- |
| _none yet_ | | | | |

## Requirements

- **Docker** — no toolchain is ever installed on the host. Every project builds inside an
  official Espressif container, which keeps the compiler and SDK version identical on every
  machine:
  - C/C++ — `espressif/idf:<release-tag>`
  - Rust — `espressif/idf-rust:<target>_<rust-version>`
- **A devkit over USB** — attached to the machine running the container.

Each project's `README.md` records the exact container tag it is built and tested against, and
the devkit it targets.

## Building an example

C/C++:

```bash
cd projects/<example>
docker run --rm -v "$PWD":/project -w /project espressif/idf:<release-tag> idf.py build
```

Rust:

```bash
cd projects/<example>
docker run --rm -v "$PWD":/project -w /project espressif/idf-rust:<target>_<rust-version> \
  cargo build --release
```

The resulting image can then be flashed from the same container (`idf.py -p <port> flash
monitor`, or `espflash flash --monitor <image>`) or with `esptool` from the host.

## Adding an example

1. Create the project under `projects/<example>/` — `idf.py create-project` for C/C++, a cargo
   crate for Rust. Do not hand-write the project skeleton.
2. Pin what the project needs (`sdkconfig.defaults` for C/C++, the manifest for Rust) so a
   clean checkout builds without `menuconfig` or manual edits.
3. Give the project its own `README.md`: what it demonstrates, the devkit and wiring, the
   ESP-IDF version, and the exact build and flash commands.
4. Add a row to the table above, including the ESP-IDF version.

## Simulation

Two simulators, each with a job. Neither replaces hardware for camera or audio examples.

**Wokwi — the learner-facing path.** The ESP-Mosaico board (ESP32-S31, 480×480 AMOLED over a
CO5300 with CST9220 touch) is simulated, display and touch included, so a learner can see the
example run in a browser with nothing installed. ESP32-S31 support is beta and the web editor
cannot compile it: build the firmware locally, or take the release binary, and run it with the
Wokwi VS Code extension or the Wokwi CLI.

**esp-emulator — the CI path.** Apache-2.0, runs locally, no quota. It boots a merged flash image
and is driven from a script (`--timeout`, `--exit-on <string>`, `--inject`), which is what makes it
assertable in a job. It provides a WiFi soft AP and user-mode NAT (`--net user`, no `sudo`, no TAP
device), so firmware gets outbound connectivity and the job can reach it again through `hostfwd`;
BLE runs against a Bumble virtual controller, and two instances link up for Thread. Chips:
C3, C5, C6, H2, P4, S3, with S31 in early bring-up. No display, no touch, no camera, no I2S.

**Not simulated at all: camera and audio.** Those examples are hardware-only and are tested on a
real devkit.

Wokwi's own CI service is a separate thing from the simulator and does not fill the CI role here:
it runs the firmware in Wokwi's cloud (50 minutes per rolling 30 days on the free plan, 5-minute
session cap), its gateway traffic is outbound-only and monitored, and two sessions cannot be
linked, so no device-to-device test.

## Releases

Each project releases its own binaries. They are built by GitHub Actions on a tag — never
uploaded from a developer machine.

- **Tag:** `<project>/v<major>.<minor>.<patch>` — e.g. `tinyml-demo/v1.2.3`. The tag names the
  project, so a release carries that project's images and nothing else.
- **Assets:** the images the build produces, each suffixed with the devkit, plus a `SHA256SUMS`
  file for that build.
- **Provenance:** the build uses the container tag recorded in the project's `README.md`, and the
  project's committed `dependencies.lock`. Commit the lockfile — it is what keeps the component
  set of a release equal to the tested one.
- **Not byte-identical:** ESP-IDF embeds build metadata (compile time, ELF digest) in the image,
  so two builds of the same sources differ. `SHA256SUMS` identifies a build; it is not a rebuild
  check.

## Licence

MIT — see [LICENSE](LICENSE).
