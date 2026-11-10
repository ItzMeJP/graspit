#!/usr/bin/env bash
# ============================================================
# install.sh: build and install GraspIt! on Ubuntu 24.04
# ------------------------------------------------------------
# Uses only Ubuntu 24.04 packages (Qt 5.15, Coin 4, SoQt 1.6,
# Qhull 2020, LAPACK/BLAS, Eigen 3.4). Installs into your home
# directory by default, so sudo is only used for apt.
#
# Settings (environment variables, all optional):
#   PREFIX            install prefix      (default: ~/.local/opt/graspit)
#   GRASPIT_DATA_DIR  models/worlds/images (default: ~/.graspit)
#   BUILD_TYPE        CMake build type     (default: Release)
#   BUILD_TESTS       ON to build the gtest tests (default: OFF)
#   BUILD_DIR         build directory      (default: ./build)
#   JOBS              parallel jobs        (default: nproc)
#
# Example:  BUILD_TESTS=ON ./install.sh
# Safe to run again: it only rebuilds what changed.
# ============================================================
set -Eeuo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-${HOME}/.local/opt/graspit}"
GRASPIT_DATA_DIR="${GRASPIT_DATA_DIR:-${HOME}/.graspit}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
BUILD_TESTS="${BUILD_TESTS:-OFF}"
BUILD_DIR="${BUILD_DIR:-${SRC_DIR}/build}"
JOBS="${JOBS:-$(nproc)}"

APT_DEPS=(
    build-essential cmake
    qtbase5-dev libqt5opengl5-dev   # Qt 5 (GUI)
    libcoin-dev libsoqt520-dev      # Coin3D / SoQt (Open Inventor 3D viewer)
    libqhull-dev                    # convex hulls (grasp wrench space)
    liblapack-dev libblas-dev       # linear algebra
    libeigen3-dev
)
[[ "${BUILD_TESTS}" == "ON" ]] && APT_DEPS+=(libgtest-dev)

if [[ ${EUID} -eq 0 ]]; then
    echo "Run this as a normal user, not with sudo (sudo is only used for apt)." >&2
    exit 1
fi

# ------------------------------------------------------------
# 1. Check the Ubuntu version (warn only)
# ------------------------------------------------------------
if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
        echo "Warning: this branch targets Ubuntu 24.04; found ${PRETTY_NAME:-unknown}." >&2
    fi
fi

# ------------------------------------------------------------
# 2. Dependencies (apt), only the missing ones
# ------------------------------------------------------------
missing=()
for p in "${APT_DEPS[@]}"; do
    dpkg -s "${p}" >/dev/null 2>&1 || missing+=("${p}")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Installing missing packages: ${missing[*]}"
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
fi

# ------------------------------------------------------------
# 3. Configure, build and install (no sudo)
# ------------------------------------------------------------
generator=()
command -v ninja >/dev/null 2>&1 && generator=(-G Ninja)
launcher=()
command -v ccache >/dev/null 2>&1 && launcher=(
    -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache)

mkdir -p "${GRASPIT_DATA_DIR}"
cmake -S "${SRC_DIR}" -B "${BUILD_DIR}" "${generator[@]}" "${launcher[@]}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_INSTALL_RPATH="${PREFIX}/lib" \
    -DGRASPIT_DATA_DIR="${GRASPIT_DATA_DIR}" \
    -DBUILD_TESTS="${BUILD_TESTS}"
cmake --build "${BUILD_DIR}" -j "${JOBS}"
cmake --install "${BUILD_DIR}"

cat <<EOF

============================================================
GraspIt! installed in ${PREFIX}
Models, worlds and images in ${GRASPIT_DATA_DIR}

Add this to your ~/.bashrc (then open a new terminal):

  export GRASPIT="${GRASPIT_DATA_DIR}"
  export PATH="${PREFIX}/bin:\$PATH"
  export CMAKE_PREFIX_PATH="${PREFIX}\${CMAKE_PREFIX_PATH:+:\$CMAKE_PREFIX_PATH}"

and run:  graspit_simulator
============================================================
EOF
