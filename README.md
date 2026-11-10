# GraspIt! for Ubuntu 24.04

[GraspIt!](https://graspit-simulator.github.io/) is a simulator for planning
and evaluating robotic grasps: hands, objects, contacts, grasp quality
metrics (epsilon, volume) and the EigenGrasp planner, with a GUI and a C++
API (`libgraspit`) that can be extended with plugins.

The official project has not been updated since 2021 and does not build or
run correctly on Ubuntu 24.04. This branch (`ubuntu-24.04`) is the official
**`qt5`** branch with the fixes needed to build it against the
**stock Ubuntu 24.04 packages**. You don't need any PPAs, vendored libraries or
custom builds of Coin/SoQt/Qhull.

## What changed compared to upstream `qt5`

| Change | Why |
|---|---|
| `qh_QHpointer` is no longer defined (`CMakeMacros/FindQhull.cmake`) | Ubuntu 24.04 ships Qhull 2020.2, whose `libqhull` does not use that mode. With it, GraspIt segfaulted as soon as it computed grasp quality (e.g. when planning). |
| `qh NOerrexit = False` before every `qh_initflags()` (`src/gws.cpp`, `src/Collision/collisionInterface.cpp`) | Qhull ≥ 2020 aborts the program otherwise (error `QH6245`, "NOerrexit was not cleared"). |
| Tests build against the system GTest and are registered with CTest | The upstream test rules depended on a `googletest` target that no longer exists. |
| `install.sh` | One-command build and install into your home directory. |

The original README is kept as [README.upstream.md](README.upstream.md).

## Tested with

Ubuntu 24.04 (X11), GCC 13.3, CMake 3.28, and these apt packages:

| Library | Package | Version |
|---|---|---|
| Qt 5 | `qtbase5-dev`, `libqt5opengl5-dev` | 5.15.13 |
| Coin3D | `libcoin-dev` | 4.0.2 |
| SoQt | `libsoqt520-dev` | 1.6.0 |
| Qhull | `libqhull-dev` | 2020.2 |
| LAPACK / BLAS | `liblapack-dev`, `libblas-dev` | 3.12.0 |
| Eigen | `libeigen3-dev` | 3.4.0 |
| GoogleTest (optional) | `libgtest-dev` | 1.14.0 |

## Installation

### Quick install

```bash
git clone -b ubuntu-24.04 https://github.com/ItzMeJP/graspit.git
cd graspit
./install.sh
```

`install.sh`:

1. installs any missing apt packages (this is the only step that uses `sudo`);
2. builds GraspIt! in `./build`;
3. installs it **in your home directory**, without touching `/usr`:

| What | Default location | Change with |
|---|---|---|
| program, `libgraspit`, headers, CMake config | `~/.local/opt/graspit` | `PREFIX=...` |
| models, worlds, images | `~/.graspit` | `GRASPIT_DATA_DIR=...` |

Other options: `BUILD_TYPE=RelWithDebInfo` (keeps debug symbols),
`BUILD_TESTS=ON`, `BUILD_DIR=...`, `JOBS=...`. For example:

```bash
PREFIX=$HOME/opt/graspit BUILD_TESTS=ON ./install.sh
```

The script is safe to run again: after a `git pull` it only rebuilds what
changed.

### Environment

Add the following to your `~/.bashrc` (`install.sh` prints these lines with your
actual paths), then open a new terminal:

```bash
export GRASPIT="$HOME/.graspit"                      # models and worlds (required)
export PATH="$HOME/.local/opt/graspit/bin:$PATH"
export CMAKE_PREFIX_PATH="$HOME/.local/opt/graspit${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
```

GraspIt! will not start without `GRASPIT`. It looks for `models/` and
`worlds/` there.

### Manual build (without the script)

```bash
sudo apt install build-essential cmake qtbase5-dev libqt5opengl5-dev \
    libcoin-dev libsoqt520-dev libqhull-dev liblapack-dev libblas-dev libeigen3-dev

cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$HOME/.local/opt/graspit \
    -DCMAKE_INSTALL_RPATH=$HOME/.local/opt/graspit/lib \
    -DGRASPIT_DATA_DIR=$HOME/.graspit
cmake --build build -j$(nproc)
cmake --install build
```

## Usage

```bash
graspit_simulator                    # open the GUI
graspit_simulator -p libmyplugin     # load a plugin
```

To check that planning works:
*File → Open* → `~/.graspit/worlds/plannerMug.xml`
→ *Grasp → EigenGrasp Planner* → *Init* → *>*.

### Using GraspIt! from your own C++ code

The install includes a CMake package config:

```cmake
find_package(graspit REQUIRED)
include_directories(${GRASPIT_INCLUDE_DIRS})
target_link_libraries(my_target ${GRASPIT_LIBRARIES})
```

See [README.upstream.md](README.upstream.md) for projects that integrate
GraspIt! (e.g. `graspit_interface`). Note that those are ROS 1 packages.

## Tests

```bash
BUILD_TESTS=ON ./install.sh
cd build && ctest --output-on-failure
```

| Test | What it covers |
|---|---|
| `eigen_tests`, `transform_tests` | maths (quaternions, transforms, Jacobian) |
| `graspit_collision_tests` | distances and bounding volumes on `plannerMug.xml` |
| `primative_planner_tests` | the planner finds a valid grasp (~10 s); this exercises the Qhull/GWS code fixed in this branch |

The collision and planner tests start the full GraspIt! GUI, so they need a
display (they do not run on a headless machine without e.g. `xvfb-run`).

## Troubleshooting

- **`Please set the GRASPIT environment variable`**: see
  [Environment](#environment).
- **Crash when planning or computing quality**: make sure you are on this
  branch. If you see `qh_QHpointer` in `build/CMakeCache.txt` or in the
  compile flags, rebuild from a clean `build/` directory. Qhull writes its messages to
  `logfile-qhull` in the directory where GraspIt! was started.
- **Empty or black 3D view under Wayland**: run it through XWayland with
  `QT_QPA_PLATFORM=xcb graspit_simulator`.
- **Laptop with hybrid graphics**: run it on the discrete GPU (e.g.
  `prime-run graspit_simulator`, or the `__NV_PRIME_RENDER_OFFLOAD=1
  __GLX_VENDOR_LIBRARY_NAME=nvidia` variables).
- **Getting a backtrace** (build with `BUILD_TYPE=RelWithDebInfo`):
  `gdb -batch -ex run -ex bt --args graspit_simulator`

## Uninstall

```bash
rm -rf ~/.local/opt/graspit ~/.graspit
```

Then remove the lines from `~/.bashrc`. The apt packages can stay; they are
ordinary Ubuntu libraries.

## License and credits

GraspIt! is © Columbia University and its contributors, and is distributed
under the license in [LICENSE.txt](LICENSE.txt). This branch only adds the
Ubuntu 24.04 fixes described above, under the same license. Upstream:
<https://github.com/graspit-simulator/graspit>.
