# WinUI3 metadata (WinMD source)

WinUI3 starts from Windows Runtime metadata, not from a `WebView2.h`-style COM
header scrape. Stage the pinned Windows App SDK WinUI package with:

```bash
./scripts/vendor-winui3-sdk.sh
```

That writes the source metadata under `build/vendor/winui3/`:

| File | Role |
|------|------|
| `metadata/Microsoft.UI.Xaml.winmd` | WinUI3 XAML runtime metadata |
| `metadata/Microsoft.UI.Text.winmd` | Text-related WinUI metadata referenced by XAML |
| `include/microsoft.ui.xaml.window.h` | Small native header for `Microsoft.UI.Xaml.Window` ABI helpers |
| `include/microsoft.ui.xaml.hosting.referencetracker.h` | Native hosting/reference tracking ABI declarations |
| `include/microsoft.ui.xaml.media.dxinterop.h` | DirectX interop declarations |

The existing `generate-binding` pipeline consumes win32json-shaped JSON
(`Enum`, `Struct`, `Com`, `FunctionPointer` records). It does not parse binary
WinMD files yet, so `metadata/filters/winui3.filter` is a seed allowlist for the
first converter or hand-written JSON shard rather than an active regen target.

Pinned package: `Microsoft.WindowsAppSDK.WinUI`
version `2.1.0` (`../winui3-sdk-ref.txt`).

See `docs/plans/11. phase 9 winui3 winmd hand binding.md` for the first binding
plan.
