#!/bin/bash
#
# Netscape CEF Browser - Setup Script
# Downloads and configures all dependencies
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THIRD_PARTY_DIR="${SCRIPT_DIR}/third_party"
CEF_VERSION="120.1.10+g3ce3184+chromium-120.0.6099.129"
CEF_PLATFORM="linux64"

echo "========================================"
echo "Netscape CEF Browser Setup"
echo "========================================"
echo

# Check for required tools
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "ERROR: $1 is required but not installed."
        return 1
    fi
    echo "✓ $1 found"
}

echo "Checking dependencies..."
check_command cmake
check_command g++
check_command python3
check_command pip3 || check_command pip

# Check for Qt6
if pkg-config --exists Qt6Core 2>/dev/null; then
    echo "✓ Qt6 found"
elif pkg-config --exists Qt5Core 2>/dev/null; then
    echo "⚠ Qt5 found (Qt6 recommended)"
else
    echo "ERROR: Qt6 development packages not found."
    echo "Install with: sudo apt install qt6-base-dev qt6-tools-dev"
    exit 1
fi

echo

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install --user Pillow || pip install --user Pillow
echo "✓ Pillow installed"
echo

# Create third_party directory
mkdir -p "${THIRD_PARTY_DIR}"

# Download CEF if not present
CEF_DIR="${THIRD_PARTY_DIR}/cef"
if [ ! -d "${CEF_DIR}" ]; then
    echo "Downloading CEF (Chromium Embedded Framework)..."
    echo "This may take a while (~300MB)..."

    CEF_URL="https://cef-builds.spotifycdn.com/cef_binary_${CEF_VERSION}_${CEF_PLATFORM}.tar.bz2"
    CEF_ARCHIVE="${THIRD_PARTY_DIR}/cef.tar.bz2"

    # Try curl first, then wget
    if command -v curl &> /dev/null; then
        curl -L -o "${CEF_ARCHIVE}" "${CEF_URL}"
    elif command -v wget &> /dev/null; then
        wget -O "${CEF_ARCHIVE}" "${CEF_URL}"
    else
        echo "ERROR: curl or wget required to download CEF"
        exit 1
    fi

    echo "Extracting CEF..."
    cd "${THIRD_PARTY_DIR}"
    tar -xjf cef.tar.bz2
    mv cef_binary_*_${CEF_PLATFORM} cef
    rm cef.tar.bz2

    echo "✓ CEF downloaded and extracted"
else
    echo "✓ CEF already present"
fi
echo

# Build CEF wrapper library
CEF_WRAPPER_BUILD="${CEF_DIR}/build_wrapper"
if [ ! -f "${CEF_WRAPPER_BUILD}/libcef_dll_wrapper/libcef_dll_wrapper.a" ]; then
    echo "Building CEF wrapper library..."
    mkdir -p "${CEF_WRAPPER_BUILD}"
    cd "${CEF_WRAPPER_BUILD}"
    cmake -DCMAKE_BUILD_TYPE=Release ../
    make -j$(nproc) libcef_dll_wrapper
    echo "✓ CEF wrapper built"
else
    echo "✓ CEF wrapper already built"
fi
echo

# Prepare assets
echo "Preparing graphical assets..."
cd "${SCRIPT_DIR}"
python3 tools/prepare_assets.py
echo "✓ Assets prepared"
echo

# Create build directory
BUILD_DIR="${SCRIPT_DIR}/build"
mkdir -p "${BUILD_DIR}"

echo "========================================"
echo "Setup complete!"
echo "========================================"
echo
echo "To build the browser:"
echo "  cd build"
echo "  cmake .."
echo "  make -j\$(nproc)"
echo
echo "To run:"
echo "  ./netscape-browser"
echo
