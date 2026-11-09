# learning-projects

Example projects for the **ESP32TV learning library**. Each example is a complete, buildable
project that demonstrates one thing on real hardware: audio, display, camera, on-device ML or
networking. An example has no cloud dependency unless its own README says otherwise.

Examples are written in **C/C++** or in **Rust**. Both kinds live side by side here. Each project's
`README.md`, and the table below, record which language it uses and which ESP-IDF version it builds
against.

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

Every directory under `projects/` is a standalone project. C/C++ examples are plain ESP-IDF CMake
projects and Rust examples are cargo crates. Each one can be built, flashed and copied out without
the rest of this repository.

## Projects

| Project | Summary | SoC | Devkit | ESP-IDF |
| --- | --- | --- | --- | --- |
| [`hello_world`](projects/hello_world) | Rust greeting that prints its crate version, its chip target and the ESP-IDF it was built against, released as one merged flash image | ESP32-C3 | ESP32-C3 devkit | v6.1 |

## Requirements

- **Docker.** No toolchain is installed on the host. Every project builds inside an official
  Espressif container, which keeps the compiler and SDK version identical on every machine:
  - C/C++: `espressif/idf:<release-tag>`
  - Rust: `espressif/idf-rust:<target>_<rust-version>`
- **A devkit over USB**, attached to the machine running the container.

Each project's `README.md` records the container tag it is built and tested against, and the devkit
it targets.

## Local development in a container

The repository ships one development container in `.devcontainer/`, so a clone needs nothing
installed on the host:

1. Open the repository folder in VS Code.
2. Run `Dev Containers: Reopen in Container`.
3. Build a project from the integrated terminal, with the command in that project's `README.md`.

The container carries the Rust toolchains and `espflash` for every current ESP32 chip. ESP-IDF is
not baked into it: each project fetches the IDF version pinned in its own `.cargo/config.toml` into
its `.embuild/` directory on the first build, which is what allows two projects to sit on different
IDF versions.

A project gets its own `.devcontainer/` only when the shared one cannot serve it, for example a
C/C++ example that needs an IDF tree on `PATH`, or a project pinned to a toolchain the shared image
does not carry. The shared container stays the default for everything else.

The container starts with device cgroup rules for `ttyUSB` and `ttyACM`, so a board plugged into the
host appears at `/dev/ttyUSB0` or `/dev/ttyACM0` inside without restarting the container.

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

Flash the resulting image from the same container (`idf.py -p <port> flash monitor`, or
`espflash flash --monitor <image>`), or with `esptool` from the host.

## Adding an example

1. Create the project under `projects/<example>/`: `idf.py create-project` for C/C++, a cargo crate
   for Rust. Do not hand-write the project skeleton.
2. Pin what the project needs (`sdkconfig.defaults` for C/C++, the manifest for Rust) so a clean
   checkout builds without `menuconfig` or manual edits.
3. Give the project its own `README.md`: what it demonstrates, the devkit and wiring, the ESP-IDF
   version, and the exact build and flash commands.
4. Add a row to the table above, including the ESP-IDF version.

## Simulation

Two simulators, each with a job. Neither replaces hardware for camera or audio examples.

**Wokwi is the learner-facing path.** The ESP-Mosaico board (ESP32-S31, 480×480 AMOLED over a
CO5300 with CST9220 touch) is simulated, display and touch included, so a learner can watch the
example run in a browser with nothing installed. ESP32-S31 support is beta and the web editor
cannot compile it: build the firmware locally, or take the release binary, and run it with the
Wokwi VS Code extension or the Wokwi CLI.

**esp-emulator is the CI path.** Apache-2.0, runs locally, no quota. It boots a merged flash image
and is driven from a script (`--timeout`, `--exit-on <string>`, `--inject`), which is what makes it
assertable in a job. It provides a WiFi soft AP and user-mode NAT (`--net user`, no `sudo`, no TAP
device), so firmware gets outbound connectivity and the job can reach it again through `hostfwd`.
BLE runs against a Bumble virtual controller, and two instances link up for Thread. Chips: C3, C5,
C6, H2, P4, S3, with S31 in early bring-up. Display, touch, camera and I2S are not modelled.

**Camera and audio are not simulated anywhere.** Those examples are hardware-only and are tested on
a real devkit.

Wokwi's own CI service is separate from the simulator and does not fill the CI role here. It runs
the firmware in Wokwi's cloud (50 minutes per rolling 30 days on the free plan, 5-minute session
cap), its gateway traffic is outbound-only and monitored, and two sessions cannot be linked, so a
device-to-device test is impossible.

## Releases

Each project releases its own binaries, built by GitHub Actions on a tag. Nothing is uploaded from a
developer machine.

- **Tag:** `<project>/v<major>.<minor>.<patch>`, for example `tinyml-demo/v1.2.3`. The tag names the
  project, so a release carries that project's images only.
- **One workflow, with no build knowledge in it:** `.github/workflows/release.yml` serves every
  project. It takes the project from the tag, or from the `project` input of a manual run, and reads
  that project's `ci.json`: which container to use (the repository devcontainer, or an image such as
  an IDF release), the environment for the build, what to cache, the command that prints the version,
  the files the build produces, and whether esp-emulator can boot the result. The build steps are the
  project's own `ci.sh`. A C/C++ project therefore names its own IDF image and runs `idf.py` there
  without an edit to the workflow.
- **Manual run:** Actions, `release`, `Run workflow`, `project: <directory name>`. It builds and runs
  the same checks and stops before publishing.
- **Assets:** the files `ci.json` declares, each suffixed with the devkit or the chip, plus a
  `SHA256SUMS` file covering them.
- **Boot check:** a project whose `ci.json` names an emulator chip is booted in
  [esp-emulator](https://github.com/espressif/esp-emulator) after it builds, and the release does not
  publish unless the image produces the expected console output.
- **Provenance:** the build uses the repository devcontainer, whose base image is pinned by digest in
  `.devcontainer/Dockerfile`, and the versions each project pins: `Cargo.lock` for Rust, the
  committed `idf_component.yml` manifests for C/C++. Anything the component
  manager generates (`managed_components/`, `dependencies.lock`) is build output: it is not
  committed, and it is reproducible from the config files a clean checkout already carries.
- **Builds are not byte-identical:** ESP-IDF embeds build metadata (compile time, ELF digest) in the
  image, so two builds of the same sources differ. `SHA256SUMS` identifies a build; it is not a
  rebuild check.

## Licence

MIT. See [LICENSE](LICENSE).
