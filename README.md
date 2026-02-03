# Netscape Navigator CEF Browser

A faithful recreation of the classic Netscape Navigator 4.x browser interface using:
- **Qt6** for native desktop UI with classic Windows 95-style appearance
- **CEF (Chromium Embedded Framework)** for modern web rendering

![Netscape Navigator](docs/screenshot.png)

## Features

- Classic Netscape Navigator 4.x user interface
- Original graphical assets (throbber animation, toolbar icons)
- Modern web rendering via Chromium
- Full HTML5, CSS3, JavaScript support
- HiDPI display support with pixel-perfect scaling

## Requirements

### System Requirements
- Linux x86_64 (Ubuntu 22.04+ recommended)
- 2GB RAM minimum
- 2GB disk space

### Build Dependencies

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    qt6-base-dev \
    qt6-tools-dev \
    libgl1-mesa-dev \
    libxkbcommon-dev \
    libx11-dev \
    python3 \
    python3-pip

# Install Pillow for asset processing
pip3 install Pillow
```

### For other distributions:

**Fedora:**
```bash
sudo dnf install cmake gcc-c++ qt6-qtbase-devel mesa-libGL-devel python3-pillow
```

**Arch Linux:**
```bash
sudo pacman -S cmake qt6-base mesa python-pillow
```

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/example/netscape-cef.git
cd netscape-cef

# Run setup script (downloads CEF ~300MB)
chmod +x setup.sh
./setup.sh
```

### 2. Build

```bash
cd build
cmake ..
make -j$(nproc)
```

### 3. Run

```bash
./netscape-browser
```

## Manual Setup

If you prefer manual setup:

### Download CEF

1. Go to https://cef-builds.spotifycdn.com/index.html
2. Download "Standard Distribution" for Linux 64-bit
3. Extract to `third_party/cef/`

### Build CEF Wrapper

```bash
cd third_party/cef
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ../
make -j$(nproc) libcef_dll_wrapper
```

### Prepare Assets

```bash
python3 tools/prepare_assets.py
```

### Build Browser

```bash
mkdir build && cd build
cmake -DCEF_ROOT=../third_party/cef ..
make -j$(nproc)
```

## Project Structure

```
netscape-cef/
├── src/
│   ├── main.cpp              # Entry point
│   ├── app/                  # CEF application
│   ├── browser/              # CEF browser integration
│   │   ├── CefBrowserWidget  # Qt widget hosting CEF
│   │   ├── NetscapeClient    # CEF client handlers
│   │   └── Handlers          # Load, Display, Request
│   ├── ui/                   # Qt UI components
│   │   ├── NetscapeMainWindow
│   │   ├── NavigationToolbar
│   │   ├── LocationToolbar
│   │   ├── NetscapeStatusBar
│   │   └── widgets/          # Custom widgets
│   └── assets/               # Asset manager
├── assets/
│   ├── 1x/                   # Original resolution
│   ├── 2x/                   # HiDPI 2x
│   └── 3x/                   # HiDPI 3x
├── tools/
│   ├── prepare_assets.py     # Asset converter
│   └── scale_assets.py       # HiDPI scaler
├── third_party/
│   └── cef/                  # CEF SDK
├── CMakeLists.txt
├── setup.sh
└── README.md
```

## Configuration

### Home Page

Edit `src/ui/NetscapeMainWindow.cpp`:
```cpp
QString m_homeUrl = "https://www.example.com";
```

### User Agent

Edit `src/main.cpp`:
```cpp
CefString(&settings.user_agent).FromASCII(
    "Mozilla/5.0 (X11; Linux x86_64) Netscape/4.8"
);
```

## Troubleshooting

### CEF not found

Ensure CEF is extracted to `third_party/cef/` and contains `include/cef_version.h`.

### Qt6 not found

Install Qt6 development packages:
```bash
sudo apt install qt6-base-dev
```

### Assets not loading

Run the asset preparation script:
```bash
python3 tools/prepare_assets.py
```

### Black screen / no rendering

Ensure you have OpenGL drivers installed:
```bash
sudo apt install libgl1-mesa-dri
```

## Architecture

```
┌─────────────────────────────────────────┐
│              Qt6 UI Layer               │
│  ┌─────────────────────────────────┐   │
│  │      NavigationToolbar          │   │
│  │  [Back][Fwd][Reload][Home] [N]  │   │
│  ├─────────────────────────────────┤   │
│  │      LocationToolbar            │   │
│  │  Location: [________________]   │   │
│  ├─────────────────────────────────┤   │
│  │                                 │   │
│  │       CefBrowserWidget          │   │
│  │    (Chromium Rendering)         │   │
│  │                                 │   │
│  ├─────────────────────────────────┤   │
│  │  StatusBar: Document: Done  🔒  │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│         CEF (Chromium Core)             │
│   Blink │ V8 │ Network │ Security       │
└─────────────────────────────────────────┘
```

## License

This project uses original Netscape Navigator graphical assets for educational and historical preservation purposes.

- Netscape Navigator was a product of Netscape Communications Corporation
- CEF is BSD-licensed
- Qt is LGPL-licensed

## Credits

- Original Netscape Navigator by Netscape Communications Corporation
- Chromium Embedded Framework by Marshall Greenblatt
- Qt Framework by The Qt Company

## Contributing

Contributions welcome! Areas of interest:
- Additional toolbar buttons
- Bookmark management
- History panel
- Print preview
- Find in page

Please open an issue first to discuss changes.
