# Phase 6b — Filter / shard trials

**Status:** **✅** Done (trial 1 complete; trial 2 deferred)

**Parent:** [8. phase 6 full api coverage.md](../plans/8.%20phase%206%20full%20api%20coverage.md)

`gui.filter` and `win32json-api.files` were **unchanged**. The measurable bump is **control-class catalog scope** (commctrl `*_CLASS` / `TOOLBARCLASSNAME` strings), which feeds `generated/win32-ui-control-strings.vala` and catalog shells in `generated/win32-widgets.vala`.

## Trial 1 — Four commctrl class strings **✅**

| Change | Detail |
|--------|--------|
| Generator | `VapiEmitter.is_control_class_string` also accepts `TOOLBARCLASSNAME`, `MONTHCAL_CLASS`, `DATETIMEPICK_CLASS`, `TOOLTIPS_CLASS` |
| Conventions | `metadata/widget-conventions.json` class overrides → `Toolbar`, `MonthCalendar`, `DateTimePicker`, `ToolTips` |
| Tooling | `scripts/compile-check.sh` + `meson compile -C build compile-check` |
| Filter / API list | No change |

| Metric | Before | After |
|--------|-------:|------:|
| Widget catalog classes | 16 | **20** |
| Track B profiles | 7 | 7 (shell-only for the four new classes) |
| `win32-ui-control-strings.vala` | ~3.0 KiB | **3.7 KiB** (+4 constants) |
| `win32-widgets.vala` | ~27 KiB | **~30 KiB** |
| `win32-ui-controls.vapi` | 13314 lines | **unchanged** (symbols already in shard) |

**Verification (2026-06-03, Linux)**

| Step | Result | Time (approx.) |
|------|--------|----------------|
| `meson compile -C build generate-binding` | ok | ~1.4 s |
| `meson compile -C build check-regen` | ok (no vapi drift) | ~1.4 s |
| `meson compile -C build compile-check` | ok (6 Track A apps → C) | ~2.2 s |
| `meson compile -C build` | ok (all cross exes) | ~4 s incremental |

**Notes**

- Vapi already exposed these APIs; only the **widget / control-string pipeline** was narrow (`WC_*` only).
- Runtime for toolbar / monthcal / datetime / tooltips still needs `InitCommonControlsEx` + correct styles (**6d** / **6e**); catalog shells are compile-only convenience.
- Deferred (still out of catalog): `TRACKBAR_CLASS`, `UPDOWN_CLASS`, `STATUSCLASSNAME`, `REBARCLASSNAME`, `ANIMATE_CLASS`, `HOTKEY_CLASS`.

## Trial 2 — Optional JSON shards **💩** deferred

Commented entries in `metadata/win32json-api.files` (`UI.Ribbon.json`, `UI.Wpf.json`, …) left for post–WebView2 or explicit need. No shard-size regression data collected.

## Commands (repeat)

```bash
meson compile -C build generate-binding
meson compile -C build check-regen
meson compile -C build compile-check
meson compile -C build
meson compile -C build coverage-report   # refresh 6a matrix
# Gap report (6e): docs/coverage/6e-gap-report.md
```
