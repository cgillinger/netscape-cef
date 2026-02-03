# CEF-Based Netscape Navigator Recreation

## Architecture Document

**Target:** Faithful recreation of Netscape Navigator 3.x/4.x UI using Chromium Embedded Framework (CEF) for rendering with Qt for native desktop UI.

---

## 1. ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Application Layer                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Qt Main Window                            │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │              Netscape Menu Bar                       │    │   │
│  │  │  File  Edit  View  Go  Communicator  Help           │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │           Navigation Toolbar (Qt Widget)             │    │   │
│  │  │  [Back] [Forward] [Reload] [Home] [Search] [N-Logo] │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │              Location Toolbar                        │    │   │
│  │  │  Bookmarks ▼  [Location: http://_______________▼]   │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │                                                      │    │   │
│  │  │              CEF Browser View                        │    │   │
│  │  │           (CefBrowserHost widget)                    │    │   │
│  │  │                                                      │    │   │
│  │  │                                                      │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │  Status Bar: [🔒] Document: Done                     │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         CEF Layer                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ CefClient    │  │ CefApp       │  │ CefBrowserProcessHandler │  │
│  │ - Display    │  │ - Init       │  │ - OnContextCreated       │  │
│  │ - Load       │  │ - Shutdown   │  │ - OnBeforeCommandLine    │  │
│  │ - Request    │  │              │  │                          │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Chromium Core                                  │
│         Blink Renderer │ V8 │ Network Stack │ Security              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. COMPONENT BREAKDOWN

### 2.1 Main Window (`NetscapeMainWindow`)

```cpp
class NetscapeMainWindow : public QMainWindow {
    // Classic Netscape window chrome
    NetscapeMenuBar*      m_menuBar;
    NavigationToolbar*    m_navToolbar;
    LocationToolbar*      m_locationToolbar;
    PersonalToolbar*      m_personalToolbar;  // Bookmarks bar
    CefBrowserWidget*     m_browserView;
    NetscapeStatusBar*    m_statusBar;
    ThrobberWidget*       m_throbber;

    // State
    BrowserState          m_state;
};
```

### 2.2 Navigation Toolbar (`NavigationToolbar`)

```cpp
class NavigationToolbar : public QWidget {
    // Buttons with original Netscape 3D appearance
    NetscapeButton* m_backBtn;      // TB_Back.gif
    NetscapeButton* m_forwardBtn;   // TB_Forward.gif
    NetscapeButton* m_reloadBtn;    // TB_Reload.gif
    NetscapeButton* m_homeBtn;      // TB_Home.gif
    NetscapeButton* m_searchBtn;    // TB_Search.gif
    NetscapeButton* m_printBtn;     // TB_Print.gif
    NetscapeButton* m_securityBtn;  // TB_Secure.gif / TB_Unsecure.gif
    NetscapeButton* m_stopBtn;      // TB_Stop.gif

    ThrobberWidget* m_throbber;     // AnimHuge00-29.gif
};
```

### 2.3 Custom Button Widget (`NetscapeButton`)

```cpp
class NetscapeButton : public QAbstractButton {
    // Four-state button matching Netscape visual style
    QPixmap m_normal;     // .gif - default state
    QPixmap m_hover;      // .mo.gif - mouse over
    QPixmap m_pressed;    // .md.gif - mouse down
    QPixmap m_disabled;   // .i.gif - inactive/disabled

    // 3D border rendering
    void paintEvent(QPaintEvent*) override {
        // Draw classic Windows 3.1/95 style beveled border
        // Light top-left, dark bottom-right for raised
        // Inverted for pressed state
    }
};
```

### 2.4 Throbber Animation (`ThrobberWidget`)

```cpp
class ThrobberWidget : public QWidget {
    QVector<QPixmap> m_frames;  // AnimHuge00-29.gif loaded
    QTimer*          m_timer;
    int              m_currentFrame;
    bool             m_loading;

public:
    void startAnimation();  // Called on load start
    void stopAnimation();   // Called on load complete, shows frame 0

private:
    void nextFrame();       // Timer callback, 100ms interval
};
```

### 2.5 Location Bar (`LocationToolbar`)

```cpp
class LocationToolbar : public QWidget {
    QLabel*         m_locationLabel;   // "Location:" or "Go To:"
    QComboBox*      m_urlCombo;        // Editable with history
    QLabel*         m_securityIcon;    // Padlock state

    // Classic sunken 3D appearance
    void paintEvent(QPaintEvent*) override;
};
```

### 2.6 Status Bar (`NetscapeStatusBar`)

```cpp
class NetscapeStatusBar : public QWidget {
    QLabel*          m_statusText;     // "Document: Done", hover links
    QLabel*          m_securityIcon;   // TB_Secure/Unsecure small
    QProgressBar*    m_progressBar;    // Classic segmented style

    // Security indicator area (bottom-left padlock)
    SecurityIndicator* m_secIndicator;
};
```

### 2.7 CEF Integration (`CefBrowserWidget`)

```cpp
class CefBrowserWidget : public QWidget, public CefClient {
    CefRefPtr<CefBrowser> m_browser;

    // CefClient interface implementations
    CefRefPtr<CefDisplayHandler>   GetDisplayHandler() override;
    CefRefPtr<CefLoadHandler>      GetLoadHandler() override;
    CefRefPtr<CefRequestHandler>   GetRequestHandler() override;

    // Qt integration
    void resizeEvent(QResizeEvent*) override;
    QPaintEngine* paintEngine() const override { return nullptr; }
};
```

---

## 3. ASSET MAPPING

### 3.1 Toolbar Button Mapping

| UI Element | Normal | Hover (.mo) | Pressed (.md) | Disabled (.i) |
|------------|--------|-------------|---------------|---------------|
| Back | `TB_Back.gif` | `TB_Back.mo.gif` | `TB_Back.md.gif` | `TB_Back.i.gif` |
| Forward | `TB_Forward.gif` | `TB_Forward.mo.gif` | `TB_Forward.md.gif` | `TB_Forward.i.gif` |
| Reload | `TB_Reload.gif` | `TB_Reload.mo.gif` | `TB_Reload.md.gif` | `TB_Reload.i.gif` |
| Stop | `TB_Stop.gif` | `TB_Stop.mo.gif` | `TB_Stop.md.gif` | `TB_Stop.i.gif` |
| Home | `TB_Home.gif` | `TB_Home.mo.gif` | `TB_Home.md.gif` | `TB_Home.i.gif` |
| Search | `TB_Search.gif` | `TB_Search.mo.gif` | `TB_Search.md.gif` | `TB_Search.i.gif` |
| Print | `TB_Print.gif` | `TB_Print.mo.gif` | `TB_Print.md.gif` | `TB_Print.i.gif` |
| Security | `TB_Secure.gif` | `TB_Secure.mo.gif` | — | `TB_Unsecure.gif` |

### 3.2 Throbber Animation Mapping

| State | Assets | Frame Count | Interval |
|-------|--------|-------------|----------|
| Loading (Large) | `AnimHuge00.gif` - `AnimHuge29.gif` | 30 | 100ms |
| Loading (Small) | `AnimSm00.gif` - `AnimSm29.gif` | 30 | 100ms |
| Idle | `AnimHuge00.gif` (static) | 1 | — |

### 3.3 Security Indicator Mapping

| State | Toolbar Icon | Status Bar Icon | Color |
|-------|--------------|-----------------|-------|
| HTTPS Valid | `TB_Secure.gif` | `Dash_Secure.gif` | Blue bar |
| HTTP | `TB_Unsecure.gif` | — | Gray |
| Mixed Content | `TB_MixSecurity.gif` | — | Yellow bar |
| Certificate Error | `TB_Unsecure.gif` | — | Red bar |

### 3.4 Cursor Mapping

| Context | Asset | Usage |
|---------|-------|-------|
| Link hover | `hand1.cur` | Over clickable elements |
| Text select | Standard Qt | In text areas |
| Drag URL | `dragurl.cur` | Dragging from address bar |

### 3.5 Menu & Bookmark Icons

| Element | Asset |
|---------|-------|
| Bookmark item | `BM_Bookmark.gif` |
| Bookmark folder (closed) | `BM_Folder.gif` |
| Bookmark folder (open) | `BM_FolderO.gif` |
| Personal folder | `BM_PersonalFolder.gif` |

---

## 4. ASSET SCALING PIPELINE

### 4.1 DPI Detection Strategy

```cpp
class AssetScaler {
public:
    enum ScaleMode {
        SCALE_1X,      // 96 DPI - Original assets
        SCALE_1_5X,    // 144 DPI - 150%
        SCALE_2X,      // 192 DPI - 200% (Retina/HiDPI)
        SCALE_3X       // 288 DPI - 300% (4K+)
    };

    static ScaleMode detectScaleMode(QScreen* screen) {
        qreal dpr = screen->devicePixelRatio();
        if (dpr <= 1.0) return SCALE_1X;
        if (dpr <= 1.5) return SCALE_1_5X;
        if (dpr <= 2.0) return SCALE_2X;
        return SCALE_3X;
    }
};
```

### 4.2 Scaling Approach: Integer-Nearest with Preprocessing

**Problem:** Original assets are 24x24 to 40x40 pixels. Direct scaling causes blur.

**Solution:** Multi-stage pipeline prioritizing pixel-perfect rendering.

```cpp
class LegacyAssetLoader {
public:
    QPixmap loadScaled(const QString& path, ScaleMode mode) {
        QImage original(path);

        switch (mode) {
        case SCALE_1X:
            return QPixmap::fromImage(original);

        case SCALE_2X:
            // Integer scale - pixel doubling (nearest neighbor)
            return QPixmap::fromImage(
                original.scaled(original.size() * 2,
                    Qt::KeepAspectRatio,
                    Qt::FastTransformation)  // Nearest neighbor
            );

        case SCALE_1_5X:
            // Fractional: scale to 2x, then down to 1.5x with smoothing
            return scaleWithIntermediate(original, 1.5);

        case SCALE_3X:
            // Integer scale with optional edge enhancement
            return QPixmap::fromImage(
                scaleWithEdgeEnhance(original, 3)
            );
        }
    }

private:
    QImage scaleWithIntermediate(const QImage& src, qreal factor) {
        // Step 1: Integer upscale (2x or 3x)
        int intScale = qCeil(factor);
        QImage upscaled = src.scaled(
            src.size() * intScale,
            Qt::KeepAspectRatio,
            Qt::FastTransformation
        );

        // Step 2: Smooth downscale to target
        QSize target = src.size() * factor;
        return upscaled.scaled(target,
            Qt::KeepAspectRatio,
            Qt::SmoothTransformation
        );
    }

    QImage scaleWithEdgeEnhance(const QImage& src, int factor) {
        // Scale3x or hqx algorithm for better edges
        // Preserves pixel art characteristics
        return applyScale3x(src);
    }
};
```

### 4.3 Asset Cache Structure

```
assets/
├── 1x/                    # Original assets (96 DPI)
│   ├── toolbar/
│   │   ├── TB_Back.png
│   │   ├── TB_Back.mo.png
│   │   └── ...
│   ├── throbber/
│   │   ├── AnimHuge00.png
│   │   └── ...
│   └── icons/
│       └── ...
├── 2x/                    # Pre-scaled 2x (generated at build)
│   └── ...
└── 3x/                    # Pre-scaled 3x (generated at build)
    └── ...
```

### 4.4 Build-Time Asset Processing

```cmake
# CMakeLists.txt asset processing
add_custom_command(
    OUTPUT ${ASSET_2X_DIR}
    COMMAND python3 ${CMAKE_SOURCE_DIR}/tools/scale_assets.py
        --input ${ASSET_1X_DIR}
        --output ${ASSET_2X_DIR}
        --scale 2
        --algorithm nearest
    DEPENDS ${ASSET_1X_FILES}
)
```

```python
# tools/scale_assets.py
from PIL import Image
import os

def scale_nearest(input_path, output_path, scale):
    """Scale using nearest neighbor for pixel-perfect enlargement"""
    img = Image.open(input_path)
    new_size = (img.width * scale, img.height * scale)
    scaled = img.resize(new_size, Image.NEAREST)
    scaled.save(output_path, 'PNG')

def process_assets(input_dir, output_dir, scale):
    for root, dirs, files in os.walk(input_dir):
        for f in files:
            if f.endswith(('.gif', '.png', '.bmp')):
                in_path = os.path.join(root, f)
                rel_path = os.path.relpath(in_path, input_dir)
                out_path = os.path.join(output_dir, rel_path)
                out_path = os.path.splitext(out_path)[0] + '.png'
                os.makedirs(os.path.dirname(out_path), exist_ok=True)
                scale_nearest(in_path, out_path, scale)
```

### 4.5 Runtime Scale Selection

```cpp
class AssetManager {
    QHash<QString, QPixmap> m_cache;
    ScaleMode m_currentScale;

public:
    AssetManager() {
        m_currentScale = AssetScaler::detectScaleMode(
            QGuiApplication::primaryScreen()
        );
    }

    QPixmap getAsset(const QString& name) {
        QString key = QString("%1@%2x").arg(name).arg(scaleToInt(m_currentScale));

        if (!m_cache.contains(key)) {
            QString path = getAssetPath(name, m_currentScale);
            m_cache[key] = QPixmap(path);
        }

        return m_cache[key];
    }

private:
    QString getAssetPath(const QString& name, ScaleMode scale) {
        // Try exact scale first
        QString path = QString(":/assets/%1x/%2.png")
            .arg(scaleToInt(scale))
            .arg(name);

        if (QFile::exists(path)) return path;

        // Fallback to 1x
        return QString(":/assets/1x/%2.png").arg(name);
    }
};
```

---

## 5. EVENT FLOW: CEF ↔ UI

### 5.1 Navigation Events

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  User clicks     │     │   Qt Signal      │     │   CEF Call       │
│  Back button     │────▶│  backClicked()   │────▶│  browser->       │
│                  │     │                  │     │  GoBack()        │
└──────────────────┘     └──────────────────┘     └──────────────────┘
                                                           │
                                                           ▼
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Update toolbar  │     │  Qt Slot         │     │  CefLoadHandler  │
│  button states   │◀────│  onLoadStart()   │◀────│  OnLoadingState  │
│                  │     │                  │     │  Change()        │
└──────────────────┘     └──────────────────┘     └──────────────────┘
```

### 5.2 Load Handler Implementation

```cpp
class NetscapeLoadHandler : public CefLoadHandler {
    QPointer<NetscapeMainWindow> m_window;

public:
    void OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                              bool isLoading,
                              bool canGoBack,
                              bool canGoForward) override {
        // Must post to Qt thread
        QMetaObject::invokeMethod(m_window, [=]() {
            // Update throbber
            if (isLoading) {
                m_window->throbber()->startAnimation();
            } else {
                m_window->throbber()->stopAnimation();
            }

            // Update navigation buttons
            m_window->navToolbar()->setBackEnabled(canGoBack);
            m_window->navToolbar()->setForwardEnabled(canGoForward);

            // Update stop/reload visibility
            m_window->navToolbar()->setStopVisible(isLoading);
            m_window->navToolbar()->setReloadVisible(!isLoading);
        });
    }

    void OnLoadStart(CefRefPtr<CefBrowser> browser,
                     CefRefPtr<CefFrame> frame,
                     TransitionType transition_type) override {
        if (frame->IsMain()) {
            QMetaObject::invokeMethod(m_window, [=]() {
                m_window->statusBar()->setText("Connecting...");
                m_window->progressBar()->setValue(0);
                m_window->progressBar()->setVisible(true);
            });
        }
    }

    void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                   CefRefPtr<CefFrame> frame,
                   int httpStatusCode) override {
        if (frame->IsMain()) {
            QMetaObject::invokeMethod(m_window, [=]() {
                m_window->statusBar()->setText("Document: Done");
                m_window->progressBar()->setVisible(false);
            });
        }
    }

    void OnLoadError(CefRefPtr<CefBrowser> browser,
                     CefRefPtr<CefFrame> frame,
                     ErrorCode errorCode,
                     const CefString& errorText,
                     const CefString& failedUrl) override {
        // Show Netscape-style error page
        QMetaObject::invokeMethod(m_window, [=]() {
            QString html = generateNetscapeErrorPage(
                QString::fromStdString(errorText.ToString()),
                QString::fromStdString(failedUrl.ToString())
            );
            frame->LoadURL(CefString(
                ("data:text/html," + html.toUtf8().toPercentEncoding()).toStdString()
            ));
        });
    }
};
```

### 5.3 Display Handler Implementation

```cpp
class NetscapeDisplayHandler : public CefDisplayHandler {
    QPointer<NetscapeMainWindow> m_window;

public:
    void OnAddressChange(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         const CefString& url) override {
        if (frame->IsMain()) {
            QMetaObject::invokeMethod(m_window, [=]() {
                m_window->locationBar()->setUrl(
                    QString::fromStdString(url.ToString())
                );
            });
        }
    }

    void OnTitleChange(CefRefPtr<CefBrowser> browser,
                       const CefString& title) override {
        QMetaObject::invokeMethod(m_window, [=]() {
            QString windowTitle = QString::fromStdString(title.ToString());
            if (windowTitle.isEmpty()) {
                windowTitle = "Netscape";
            } else {
                windowTitle += " - Netscape";
            }
            m_window->setWindowTitle(windowTitle);
        });
    }

    void OnStatusMessage(CefRefPtr<CefBrowser> browser,
                         const CefString& value) override {
        // Link hover text in status bar
        QMetaObject::invokeMethod(m_window, [=]() {
            QString status = QString::fromStdString(value.ToString());
            if (status.isEmpty()) {
                m_window->statusBar()->setText("Document: Done");
            } else {
                m_window->statusBar()->setText(status);
            }
        });
    }

    bool OnConsoleMessage(CefRefPtr<CefBrowser> browser,
                          cef_log_severity_t level,
                          const CefString& message,
                          const CefString& source,
                          int line) override {
        // Suppress or log - Netscape didn't have console
        return true;  // Handled, don't show
    }
};
```

### 5.4 Security State Handler

```cpp
class NetscapeRequestHandler : public CefRequestHandler {
public:
    bool OnCertificateError(CefRefPtr<CefBrowser> browser,
                            cef_errorcode_t cert_error,
                            const CefString& request_url,
                            CefRefPtr<CefSSLInfo> ssl_info,
                            CefRefPtr<CefCallback> callback) override {
        // Update UI to show security warning
        QMetaObject::invokeMethod(m_window, [=]() {
            m_window->setSecurityState(SecurityState::CertError);

            // Show Netscape-style certificate dialog
            NetscapeCertDialog dialog(m_window, ssl_info);
            if (dialog.exec() == QDialog::Accepted) {
                callback->Continue();
            } else {
                callback->Cancel();
            }
        });

        return true;  // Handled asynchronously
    }
};
```

### 5.5 Complete Event Flow Diagram

```
USER ACTION                 QT LAYER                    CEF LAYER
═══════════════════════════════════════════════════════════════════════

Click Back Button
        │
        ▼
[NetscapeButton::clicked]
        │
        ├──────────────────────────────────────────▶ browser->GoBack()
        │                                                   │
        │                                                   ▼
        │                                          [Navigation starts]
        │                                                   │
        │    ◀─────────────────────────────────── OnLoadingStateChange
        │                                          (isLoading=true)
        ▼
[throbber.startAnimation()]
[backBtn.setEnabled(canGoBack)]
[stopBtn.setVisible(true)]
        │
        │    ◀─────────────────────────────────── OnLoadStart
        │                                          (frame, type)
        ▼
[statusBar.setText("Connecting...")]
[progressBar.show()]
        │
        │    ◀─────────────────────────────────── OnAddressChange
        │                                          (url)
        ▼
[locationBar.setUrl(url)]
        │
        │    ◀─────────────────────────────────── OnTitleChange
        │                                          (title)
        ▼
[window.setWindowTitle(title)]
        │
        │    ◀─────────────────────────────────── OnLoadEnd
        │                                          (httpStatus)
        ▼
[statusBar.setText("Document: Done")]
[progressBar.hide()]
        │
        │    ◀─────────────────────────────────── OnLoadingStateChange
        │                                          (isLoading=false)
        ▼
[throbber.stopAnimation()]
[stopBtn.setVisible(false)]
[reloadBtn.setVisible(true)]

═══════════════════════════════════════════════════════════════════════
```

---

## 6. UI COMPONENT RENDERING

### 6.1 Classic 3D Border Style

```cpp
void NetscapeButton::paintBorder(QPainter* painter, bool raised) {
    QRect r = rect();

    // Classic Windows 3.1/95 style beveled border
    QColor light = raised ? QColor(255, 255, 255) : QColor(128, 128, 128);
    QColor dark = raised ? QColor(128, 128, 128) : QColor(255, 255, 255);
    QColor darkest = QColor(0, 0, 0);

    // Outer border
    painter->setPen(light);
    painter->drawLine(r.left(), r.top(), r.right() - 1, r.top());
    painter->drawLine(r.left(), r.top(), r.left(), r.bottom() - 1);

    painter->setPen(darkest);
    painter->drawLine(r.right(), r.top(), r.right(), r.bottom());
    painter->drawLine(r.left(), r.bottom(), r.right(), r.bottom());

    // Inner border
    painter->setPen(raised ? QColor(223, 223, 223) : dark);
    painter->drawLine(r.left() + 1, r.top() + 1, r.right() - 2, r.top() + 1);
    painter->drawLine(r.left() + 1, r.top() + 1, r.left() + 1, r.bottom() - 2);

    painter->setPen(dark);
    painter->drawLine(r.right() - 1, r.top() + 1, r.right() - 1, r.bottom() - 1);
    painter->drawLine(r.left() + 1, r.bottom() - 1, r.right() - 1, r.bottom() - 1);
}

void NetscapeButton::paintEvent(QPaintEvent*) {
    QPainter painter(this);

    // Background
    painter.fillRect(rect().adjusted(2, 2, -2, -2), QColor(192, 192, 192));

    // Border
    bool raised = !isDown() && isEnabled();
    paintBorder(&painter, raised);

    // Icon
    QPixmap icon;
    if (!isEnabled()) {
        icon = m_disabled;
    } else if (isDown()) {
        icon = m_pressed;
    } else if (underMouse()) {
        icon = m_hover;
    } else {
        icon = m_normal;
    }

    QRect iconRect = icon.rect();
    iconRect.moveCenter(rect().center());
    if (isDown()) {
        iconRect.translate(1, 1);  // Press offset
    }

    painter.drawPixmap(iconRect, icon);
}
```

### 6.2 Toolbar Background

```cpp
void NavigationToolbar::paintEvent(QPaintEvent*) {
    QPainter painter(this);

    // Classic toolbar gray with subtle pattern
    painter.fillRect(rect(), QColor(192, 192, 192));

    // Top highlight line
    painter.setPen(QColor(255, 255, 255));
    painter.drawLine(0, 0, width(), 0);

    // Bottom shadow line
    painter.setPen(QColor(128, 128, 128));
    painter.drawLine(0, height() - 1, width(), height() - 1);

    // Optional: grip handle on left
    drawGripHandle(&painter, QRect(2, 2, 8, height() - 4));
}
```

### 6.3 Status Bar Rendering

```cpp
void NetscapeStatusBar::paintEvent(QPaintEvent*) {
    QPainter painter(this);

    // Sunken panel appearance
    painter.fillRect(rect(), QColor(192, 192, 192));

    // Sunken border
    painter.setPen(QColor(128, 128, 128));
    painter.drawLine(0, 0, width(), 0);
    painter.drawLine(0, 0, 0, height());

    painter.setPen(QColor(255, 255, 255));
    painter.drawLine(width() - 1, 0, width() - 1, height());
    painter.drawLine(0, height() - 1, width(), height() - 1);

    // Security indicator area (sunken)
    QRect secRect(4, 3, 20, height() - 6);
    drawSunkenRect(&painter, secRect);
    painter.drawPixmap(secRect.adjusted(2, 2, -2, -2), m_securityIcon);

    // Status text
    painter.setPen(Qt::black);
    painter.drawText(30, 0, width() - 30, height(),
                     Qt::AlignVCenter | Qt::AlignLeft, m_statusText);
}
```

---

## 7. PROJECT STRUCTURE

```
netscape-cef/
├── CMakeLists.txt
├── src/
│   ├── main.cpp
│   ├── app/
│   │   ├── NetscapeApp.h           # CefApp implementation
│   │   ├── NetscapeApp.cpp
│   │   └── NetscapeSchemeHandler.h # ns:// protocol handler
│   ├── browser/
│   │   ├── CefBrowserWidget.h      # Qt widget hosting CEF
│   │   ├── CefBrowserWidget.cpp
│   │   ├── NetscapeClient.h        # CefClient implementation
│   │   ├── NetscapeLoadHandler.cpp
│   │   ├── NetscapeDisplayHandler.cpp
│   │   └── NetscapeRequestHandler.cpp
│   ├── ui/
│   │   ├── NetscapeMainWindow.h
│   │   ├── NetscapeMainWindow.cpp
│   │   ├── NavigationToolbar.h
│   │   ├── NavigationToolbar.cpp
│   │   ├── LocationToolbar.h
│   │   ├── LocationToolbar.cpp
│   │   ├── NetscapeStatusBar.h
│   │   ├── NetscapeStatusBar.cpp
│   │   ├── NetscapeMenuBar.h
│   │   ├── NetscapeMenuBar.cpp
│   │   └── widgets/
│   │       ├── NetscapeButton.h
│   │       ├── NetscapeButton.cpp
│   │       ├── ThrobberWidget.h
│   │       ├── ThrobberWidget.cpp
│   │       └── SecurityIndicator.h
│   └── assets/
│       └── AssetManager.h          # Asset loading and caching
├── assets/
│   ├── 1x/                         # Original Netscape assets
│   │   ├── toolbar/
│   │   ├── throbber/
│   │   ├── icons/
│   │   └── cursors/
│   ├── 2x/                         # Pre-scaled 2x
│   └── 3x/                         # Pre-scaled 3x
├── tools/
│   ├── scale_assets.py             # Build-time asset scaler
│   └── convert_gif_to_png.py       # GIF→PNG converter
└── resources/
    └── netscape.qrc                # Qt resource file
```

---

## 8. BUILD CONFIGURATION

### 8.1 CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.16)
project(NetscapeCEF VERSION 1.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Find packages
find_package(Qt6 REQUIRED COMPONENTS Widgets Core Gui)
find_package(CEF REQUIRED)

# Asset preprocessing
set(ASSET_1X_DIR "${CMAKE_SOURCE_DIR}/assets/1x")
set(ASSET_2X_DIR "${CMAKE_BINARY_DIR}/assets/2x")
set(ASSET_3X_DIR "${CMAKE_BINARY_DIR}/assets/3x")

add_custom_target(scale_assets
    COMMAND python3 ${CMAKE_SOURCE_DIR}/tools/scale_assets.py
        --input ${ASSET_1X_DIR} --output ${ASSET_2X_DIR} --scale 2
    COMMAND python3 ${CMAKE_SOURCE_DIR}/tools/scale_assets.py
        --input ${ASSET_1X_DIR} --output ${ASSET_3X_DIR} --scale 3
)

# Sources
set(SOURCES
    src/main.cpp
    src/app/NetscapeApp.cpp
    src/browser/CefBrowserWidget.cpp
    src/browser/NetscapeLoadHandler.cpp
    src/browser/NetscapeDisplayHandler.cpp
    src/browser/NetscapeRequestHandler.cpp
    src/ui/NetscapeMainWindow.cpp
    src/ui/NavigationToolbar.cpp
    src/ui/LocationToolbar.cpp
    src/ui/NetscapeStatusBar.cpp
    src/ui/NetscapeMenuBar.cpp
    src/ui/widgets/NetscapeButton.cpp
    src/ui/widgets/ThrobberWidget.cpp
    src/assets/AssetManager.cpp
)

# Resources
qt6_add_resources(RESOURCES resources/netscape.qrc)

# Executable
add_executable(netscape-browser ${SOURCES} ${RESOURCES})
add_dependencies(netscape-browser scale_assets)

target_link_libraries(netscape-browser
    Qt6::Widgets
    Qt6::Core
    Qt6::Gui
    CEF::libcef_dll_wrapper
)

# CEF helper process (required for multi-process)
add_executable(netscape-helper src/helper/main_helper.cpp)
target_link_libraries(netscape-helper CEF::libcef_dll_wrapper)
```

---

## 9. KEY IMPLEMENTATION NOTES

### 9.1 Thread Safety

```cpp
// CEF callbacks run on CEF UI thread, not Qt main thread
// ALWAYS use QMetaObject::invokeMethod for cross-thread UI updates

void NetscapeLoadHandler::OnLoadEnd(...) {
    // WRONG - crashes or undefined behavior
    // m_window->statusBar()->setText("Done");

    // CORRECT - marshals to Qt thread
    QMetaObject::invokeMethod(m_window, [=]() {
        m_window->statusBar()->setText("Done");
    }, Qt::QueuedConnection);
}
```

### 9.2 CEF Message Loop Integration

```cpp
// main.cpp
int main(int argc, char* argv[]) {
    // CEF initialization (must be before QApplication)
    CefMainArgs mainArgs(argc, argv);
    CefRefPtr<NetscapeApp> app(new NetscapeApp);

    int exitCode = CefExecuteProcess(mainArgs, app, nullptr);
    if (exitCode >= 0) {
        return exitCode;  // Sub-process
    }

    CefSettings settings;
    settings.multi_threaded_message_loop = true;  // Let CEF run own loop
    CefInitialize(mainArgs, settings, app, nullptr);

    // Qt initialization
    QApplication qtApp(argc, argv);

    NetscapeMainWindow window;
    window.show();

    int result = qtApp.exec();

    CefShutdown();
    return result;
}
```

### 9.3 Window Handle Integration (Platform-Specific)

```cpp
// CefBrowserWidget.cpp
void CefBrowserWidget::createBrowser(const QString& url) {
    CefWindowInfo windowInfo;

#ifdef Q_OS_WIN
    HWND hwnd = (HWND)winId();
    RECT rect;
    GetClientRect(hwnd, &rect);
    windowInfo.SetAsChild(hwnd, rect);
#endif

#ifdef Q_OS_LINUX
    windowInfo.SetAsChild(winId(), CefRect(0, 0, width(), height()));
#endif

#ifdef Q_OS_MAC
    windowInfo.SetAsChild((CefWindowHandle)winId(), 0, 0, width(), height());
#endif

    CefBrowserSettings browserSettings;

    m_browser = CefBrowserHost::CreateBrowserSync(
        windowInfo,
        m_client.get(),
        url.toStdString(),
        browserSettings,
        nullptr,
        nullptr
    );
}
```

### 9.4 Asset Conversion Notes

| Original Format | Issue | Solution |
|-----------------|-------|----------|
| GIF | Transparency may be palette-based | Convert to PNG with alpha |
| BMP | No transparency, large files | Convert to PNG |
| XPM | X11-only format | Convert to PNG |
| ICO | Multi-resolution container | Extract each size to PNG |

```bash
# Batch convert all assets
for f in *.gif; do
    convert "$f" -background none "${f%.gif}.png"
done

for f in *.bmp; do
    convert "$f" "${f%.bmp}.png"
done
```

### 9.5 Behavioral Fidelity Notes

| Feature | Netscape Behavior | Implementation |
|---------|-------------------|----------------|
| Throbber | Animates during ANY network activity | Hook `OnLoadingStateChange` |
| Stop button | Immediately halts all loading | `browser->StopLoad()` |
| Status bar | Shows link URL on hover | Hook `OnStatusMessage` |
| Progress | Segmented bar, not smooth | Custom `QProgressBar` style |
| Error pages | "Netscape is unable to..." | Custom HTML error templates |
| Window title | "Page Title - Netscape" | Format in `OnTitleChange` |

### 9.6 Missing Features for MVP

These are **not** implemented in MVP but noted for future:

- Bookmarks sidebar
- History panel
- View Source window
- Print preview
- Find in page (Ctrl+F)
- Multiple windows
- Java/Plugin support (impossible in modern CEF)

---

## 10. TESTING CHECKLIST

### Visual Fidelity
- [ ] Toolbar buttons match original 3D appearance
- [ ] Throbber animation runs at correct speed (100ms/frame)
- [ ] Status bar shows correct security indicators
- [ ] Window chrome matches Netscape 4.x style
- [ ] Fonts match original (MS Sans Serif / Helvetica)

### Behavioral Fidelity
- [ ] Throbber starts/stops correctly with page loads
- [ ] Back/Forward buttons enable/disable correctly
- [ ] Stop and Reload toggle visibility during load
- [ ] Status bar shows hover link URLs
- [ ] Address bar updates during navigation
- [ ] Window title follows "Title - Netscape" format

### DPI Scaling
- [ ] Assets crisp at 100% (96 DPI)
- [ ] Assets crisp at 200% (192 DPI)
- [ ] No blur at 150% (fractional scaling)
- [ ] Layout doesn't break at high DPI

---

## 11. SUMMARY

This architecture provides a faithful Netscape Navigator 4.x recreation using:

- **CEF** for modern web rendering (Blink + V8)
- **Qt** for native desktop UI with classic styling
- **Original assets** scaled appropriately for modern displays
- **Event-driven architecture** cleanly separating UI from browser engine

The result is a browser that *looks and feels* like 1998 Netscape while rendering modern web content with full HTML5/CSS3/JavaScript support.

**Estimated complexity:** ~5,000-8,000 lines of C++/Qt code for MVP.
