# learning-projects

Example projects for the ESP32TV learning show. Each example is a complete, buildable
ESP-IDF project that demonstrates one thing on real hardware — audio, display, camera,
on-device ML, networking — with no cloud dependency unless the example says otherwise.

## Layout

```
learning-projects/
└── projects/
    └── <example>/          # one self-contained ESP-IDF project
        ├── CMakeLists.txt  # project root — build from this directory
        ├── main/           # application sources
        ├── sdkconfig.defaults
        └── README.md       # what it does, what it needs, how to run it
```

Every directory under `projects/` is a standalone ESP-IDF project. It has its own
`CMakeLists.txt`, its own `main/`, and its own `sdkconfig.defaults`, so it can be built,
flashed and copied out without the rest of this repository.

## Projects

| Project | Summary | SoC | Devkit |
| --- | --- | --- | --- |
| _none yet_ | | | |

## Requirements

- **Docker** — the ESP-IDF toolchain is never installed on the host. Every project builds
  inside the official `espressif/idf` container, which keeps the compiler and SDK version
  identical on every machine.
- **A devkit over USB** — attached to the machine running the container.

Each project's `README.md` states the ESP-IDF version it is built and tested against, and
the devkit it targets.

## Building an example

```bash
cd projects/<example>
docker run --rm -v "$PWD":/project -w /project espressif/idf:<version> idf.py build
```

The resulting image can then be flashed with `idf.py -p <port> flash monitor` from the same
container, or with `esptool` from the host.

## Adding an example

1. Create the project under `projects/<example>/` with `idf.py create-project` — do not
   write `CMakeLists.txt` or `main/` by hand.
2. Pin what the project needs in `sdkconfig.defaults` so a clean checkout builds without
   `menuconfig`.
3. Give the project its own `README.md`: what it demonstrates, the devkit and wiring, the
   ESP-IDF version, and the exact build and flash commands.
4. Add a row to the table above.

## Licence

MIT — see [LICENSE](LICENSE).
