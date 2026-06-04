# WebView2 capture investigation (closed)

Notes from a one-off probe (`webview2-host-demo --spike`). Not a shipped feature.

## What we wanted to test

| Goal | WebView2 API | Spike (`--spike`)? |
|------|--------------|-------------------|
| Scroll programmatically (e.g. load lazy images) | `ExecuteScript` — `window.scrollTo(...)` | Yes |
| Screenshot of visible area | `CapturePreview` → PNG file | Yes |
| Scroll back to top | `ExecuteScript` | Yes |
| Wider layout before capture | `ICoreWebView2Controller::put_Bounds` | Optional `--spike-wide` |
| Hide / off-screen host | Win32 window placement | No |
| Full-page image (entire scroll height) | Not one call — scroll + viewport shots + merge (same idea as GTK tile capture) | No |

`CapturePreview` is **viewport only**, not full document height.

## Run the spike (Windows)

After `scripts/build-win.sh`:

```text
build-win/webview2-host-demo.exe "<url>" --spike
```

Writes `webview2-spike-01-after-scroll-bottom.png` and `webview2-spike-02-at-top.png` next to the exe.

Implementation: `src/webview2-capture-spike.c` (not part of the long-term binding).
