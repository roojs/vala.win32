# Phase 6a — Ergonomic example coverage

Track B demos: `using GLib`, `Win32.Window`, widget classes, **signals/properties** — no `create_window_ex` / `send_message` in application code. Regenerate: `meson compile -C build coverage-report`. Details: [6e-gap-report.md](6e-gap-report.md).

**Parent plan:** [08 - phase 6 full api coverage.md](../plans/08%20-%20phase%206%20full%20api%20coverage.md)

## Ergonomic examples (`examples/ergonomic-*.vala`)

| Build | Source | `Win32.*` used | Signals / API style | Notes |
|-------|--------|----------------|----------------------|-------|
| `ergonomic-button-demo.exe` | [examples/ergonomic-button-demo.vala](../../examples/ergonomic-button-demo.vala) | `Window`, `Label`, `Edit`, `Button`, `ListBox`, `ComboBox`, `ScrollBar`, `ProgressBar` | `.clicked`, `.changed`, `.selection_changed`, `.value_changed`; `.text` on `Edit` | Canonical WM_COMMAND set; best starter |
| `ergonomic-widgets-demo.exe` | [examples/ergonomic-widgets-demo.vala](../../examples/ergonomic-widgets-demo.vala) | above + `GroupBox`, `ListView`, `TreeView`, `TabControl`, `MonthCalendar`, `Toolbar`, `DateTimePicker`, `ToolTips` | WM_NOTIFY signals; `add_column` / `append_row`, `add_root` / `add_child`, `add_page`; status via `Label.text` | Integration showcase; shells (toolbar, tooltips) may not behave fully on Wine |
| `ergonomic-dialog-demo.exe` | [examples/ergonomic-dialog-demo.vala](../../examples/ergonomic-dialog-demo.vala) | `Window` | `frame.show_message (...)` → `NativeDialogs` | Modal message box only |
| `ergonomic-common-dialog-demo.exe` | [examples/ergonomic-common-dialog-demo.vala](../../examples/ergonomic-common-dialog-demo.vala) | `Window`, `Button` | `NativeDialogs.try_open_file`, `try_choose_color` + button `.clicked` | Common dialogs shard |
| `ergonomic-menu-demo.exe` | [examples/ergonomic-menu-demo.vala](../../examples/ergonomic-menu-demo.vala) | `Window`, `MenuBar`, `MenuPopup` | `.activated` on menu bar | Menus (template shell, not catalog WC_*) |
| `ergonomic-error-demo.exe` | [examples/ergonomic-error-demo.vala](../../examples/ergonomic-error-demo.vala) | — (no widget UI) | `win32_bool_ok` + `WideString` (CLI smoke, not a layout demo) | Error helpers only; console exit 0 |

## Widget → ergonomic example

Which **ergo** demo exercises each generated widget (Track A `*-demo.vala` ignored).

| Widget | Ergo example | Signals? | Notes |
|--------|--------------|----------|-------|
| Button | ergonomic-button-demo (+ widgets-demo for some) | yes | Profiled |
| ComboBox | ergonomic-button-demo (+ widgets-demo for some) | yes | Profiled |
| ComboBoxEx32 | — | no | **No ergo example yet** |
| DateTimePicker | ergonomic-widgets-demo | no | Shell only in widgets-demo |
| Edit | ergonomic-button-demo (+ widgets-demo for some) | yes | Single-line; multiline not in any ergo demo |
| GroupBox | ergonomic-widgets-demo | — | Template helper (layout frame) |
| Label | ergonomic-button-demo (+ widgets-demo for some) | yes | Profiled |
| ListBox | ergonomic-button-demo (+ widgets-demo for some) | yes | Profiled |
| ListView | ergonomic-widgets-demo | yes | Profiled |
| MonthCalendar | ergonomic-widgets-demo | no | Shell only in widgets-demo |
| NativeFontCtl | — | no | **No ergo example yet** |
| ProgressBar | ergonomic-button-demo (+ widgets-demo for some) | yes | Profiled |
| ScrollBar | ergonomic-button-demo (+ widgets-demo for some) | yes | Profiled |
| SysHeader32 | — | no | **No ergo example yet** |
| SysIPAddress32 | — | no | **No ergo example yet** |
| SysLink | — | no | **No ergo example yet** |
| SysListView32 | — | no | **No ergo example yet** |
| SysPager | — | no | **No ergo example yet** |
| SysTreeView32 | — | no | **No ergo example yet** |
| TabControl | ergonomic-widgets-demo | yes | Profiled |
| ToolTips | ergonomic-widgets-demo | no | In demo; hover tips need profile + `TTM_ADDTOOL` |
| Toolbar | ergonomic-widgets-demo | no | In demo; empty bar without TB buttons |
| TreeView | ergonomic-widgets-demo | yes | Profiled |

### Template APIs (not catalog widgets)

| API | Ergo example | Notes |
|-----|--------------|-------|
| `Window`, `Window.title`, `Window.run` | all UI demos | Top-level frame |
| `NativeDialogs.show_message` | ergonomic-dialog-demo | MessageBox |
| `NativeDialogs.try_open_file` / `try_choose_color` | ergonomic-common-dialog-demo | File/color picker |
| `MenuBar` / `MenuPopup` | ergonomic-menu-demo | Not from `UI.Controls` catalog |
| `win32_bool_ok` | ergonomic-error-demo | `generated/win32-errors.vala` |

## Not in ergonomic format yet

These matter for product UX but have **no** `examples/ergonomic-*.vala` story (vapi or shell only):

| Want | Suggested next step |
|------|---------------------|
| Multiline edit | `MultilineEdit` profile or extend `Edit`; add to button or widgets demo |
| Rich text | `RichEdit` widget + `win32-ui-controls-richedit`; new `ergonomic-richtext-demo` |
| Working tooltips | `ToolTips.attach(control, text)` profile; wire on button-demo |
| Header, IP address, link, combo ex, pager, … | Profile + one line in widgets-demo or dedicated ergo demo |
| Track A `button-demo` etc. | Legacy raw vapi — **not** ergo format; ignore unless debugging generator |

## Run ergonomic builds

```bash
meson setup build && meson compile -C build
wine build/ergonomic-button-demo.exe
wine build/ergonomic-widgets-demo.exe
# WIN32_WIDGET_DEBUG=1 wine build/ergonomic-widgets-demo.exe
```

Build all Track B exes: `meson compile -C build` (needs MinGW + `scripts/setup-mingw-libs.sh`). This report does **not** record Wine pass/fail (**6f**).

## Generator snapshot

- **6** ergonomic `.exe` targets (see `meson.build` `ergonomic_apps`)
- **10 / 22** catalog widgets profiled; **12** shells without signals
- Full gap list: [6e-gap-report.md](6e-gap-report.md)
