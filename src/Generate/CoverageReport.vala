/*
 * Phase 6a — coverage matrix centered on Track B ergonomic examples.
 */

namespace Generate {

	private struct ErgoExampleRow {
		public string exe;
		public string source;
		public string widgets;
		public string patterns;
		public string notes;
	}

	public class CoverageReport : Object {
		const string REGEN_CMD = "meson compile -C build coverage-report";

		SymbolFilter filter;
		WidgetCodegen? widget_codegen;
		string project_root;

		public CoverageReport(
			SymbolFilter filter,
			WidgetCodegen? widget_codegen,
			string vapidir,
			string project_root
		) {
			this.filter = filter;
			this.widget_codegen = widget_codegen;
			this.project_root = project_root;
		}

		public string emit_markdown(Parse.ApiFileEntry[] files) {
			var sb = new GLib.StringBuilder();
			sb.append("# Phase 6a — Ergonomic example coverage\n\n");
			sb.append(
				"Track B demos: `using GLib`, `Win32.Window`, widget classes, **signals/properties** — "
			);
			sb.append("no `create_window_ex` / `send_message` in application code. Regenerate: `");
			sb.append(REGEN_CMD);
			sb.append("`. Details: [6e-gap-report.md](6e-gap-report.md).\n\n");
			sb.append("**Parent plan:** [8. phase 6 full api coverage.md](../plans/8.%20phase%206%20full%20api%20coverage.md)\n\n");

			append_ergo_examples(sb);
			append_widget_by_ergo_demo(sb);
			append_not_in_ergo_format(sb);
			append_run(sb);
			append_gaps(sb);
			return sb.str;
		}

		static ErgoExampleRow[] ergo_examples() {
			return {
				ErgoExampleRow() {
					exe = "hello-window",
					source = "examples/hello-window.vala",
					widgets = "`Window`",
					patterns = "`Window.run`",
					notes = "Top-level hello; start here",
				},
				ErgoExampleRow() {
					exe = "button-demo",
					source = "examples/button-demo.vala",
					widgets = "`Window`, `Label`, `Edit`, `Button`, `ListBox`, `ComboBox`, `ScrollBar`, `ProgressBar`",
					patterns = "`.clicked`, `.changed`, `.selection_changed`, `.value_changed`; `.text` on `Edit`",
					notes = "Canonical WM_COMMAND set; best starter",
				},
				ErgoExampleRow() {
					exe = "widgets-demo",
					source = "examples/widgets-demo.vala",
					widgets = "above + `GroupBox`, `ListView`, `TreeView`, `TabControl`, `MonthCalendar`, `Toolbar`, `DateTimePicker`, `ToolTips`",
					patterns = "WM_NOTIFY signals; `add_column` / `append_row`, `add_root` / `add_child`, `add_page`; status via `Label.text`",
					notes = "Integration showcase; shells(toolbar, tooltips) may not behave fully on Wine",
				},
				ErgoExampleRow() {
					exe = "dialog-demo",
					source = "examples/dialog-demo.vala",
					widgets = "`Window`",
					patterns = "`frame.show_message(...)` → `NativeDialogs`",
					notes = "Modal message box only",
				},
				ErgoExampleRow() {
					exe = "common-dialog-demo",
					source = "examples/common-dialog-demo.vala",
					widgets = "`Window`, `Button`",
					patterns = "`NativeDialogs.try_open_file`, `try_choose_color` + button `.clicked`",
					notes = "Common dialogs shard",
				},
				ErgoExampleRow() {
					exe = "menu-demo",
					source = "examples/menu-demo.vala",
					widgets = "`Window`, `MenuBar`, `MenuPopup`",
					patterns = "`.activated` on menu bar",
					notes = "Menus(template shell, not catalog WC_*)",
				},
				ErgoExampleRow() {
					exe = "error-demo",
					source = "examples/error-demo.vala",
					widgets = "— (no widget UI)",
					patterns = "`win32_bool_ok` + `WideString` (CLI smoke, not a layout demo)",
					notes = "Error helpers only; console exit 0",
				},
			};
		}

		void append_ergo_examples(GLib.StringBuilder sb) {
			sb.append("## Ergonomic examples(`examples/*.vala`; raw Win32 in `examples/native/`)\n\n");
			sb.append(
				"| Build | Source | `Win32.*` used | Signals / API style | Notes |\n"
			);
			sb.append(
				"|-------|--------|----------------|----------------------|-------|\n"
			);
			foreach (var row in ergo_examples()) {
				var link = "../../" + row.source;
				sb.append_printf(
					"| `%s.exe` | [%s](%s) | %s | %s | %s |\n",
					row.exe,
					row.source,
					link,
					row.widgets,
					row.patterns,
					row.notes
				);
			}
		}

		void append_widget_by_ergo_demo(GLib.StringBuilder sb) {
			sb.append("\n## Widget → ergonomic example\n\n");
			sb.append(
				"Which **ergo** demo exercises each generated widget(Track A `*-demo.vala` ignored).\n\n"
			);
			sb.append("| Widget | Ergo example | Signals? | Notes |\n");
			sb.append("|--------|--------------|----------|-------|\n");

			if (widget_codegen == null) {
				return;
			}

			var names = new Gee.ArrayList<string> ();
			foreach (var d in widget_codegen.catalog_controls()) {
				if (d != null) {
					names.add(d.class_name());
				}
			}
			names.add("GroupBox");
			names.add("ControlFont");
			names.sort();

			foreach (var class_name in names) {
				string? wc = wc_for_class(class_name);
				if (class_name == "GroupBox") {
					sb.append(
						"| GroupBox | widgets-demo | — | Template helper(layout frame) |\n"
					);
					continue;
				}
				if (class_name == "ControlFont") {
					continue;
				}
				if (wc == null) {
					continue;
				}
				WidgetControlDescriptor? d = descriptor_for_wc(wc);
				if (d == null) {
					continue;
				}
				var ergo = ergo_demo_for_wc(wc);
				var signals = d.has_track_b_profile() ? "yes" : "no";
				sb.append_printf(
					"| %s | %s | %s | %s |\n",
					d.class_name(),
					ergo,
					signals,
					ergo_runtime_note(wc, d.has_track_b_profile(), ergo)
				);
			}

			sb.append("\n### Template APIs(not catalog widgets)\n\n");
			sb.append("| API | Ergo example | Notes |\n");
			sb.append("|-----|--------------|-------|\n");
			sb.append(
				"| `Window`, `Window.title`, `Window.run` | all UI demos | Top-level frame |\n"
			);
			sb.append(
				"| `NativeDialogs.show_message` | dialog-demo | MessageBox |\n"
			);
			sb.append(
				"| `NativeDialogs.try_open_file` / `try_choose_color` | common-dialog-demo | File/color picker |\n"
			);
			sb.append(
				"| `MenuBar` / `MenuPopup` | menu-demo | Not from `UI.Controls` catalog |\n"
			);
			sb.append(
				"| `win32_bool_ok` | error-demo | `generated/win32-errors.vala` |\n"
			);
		}

		WidgetControlDescriptor? descriptor_for_wc(string wc) {
			foreach (var d in widget_codegen.catalog_controls()) {
				if (d != null && d.wc_symbol == wc) {
					return d;
				}
			}
			return null;
		}

		string? wc_for_class(string class_name) {
			foreach (var d in widget_codegen.catalog_controls()) {
				if (d != null && d.class_name() == class_name) {
					return d.wc_symbol;
				}
			}
			return null;
		}

		static string ergo_demo_for_wc(string wc_symbol) {
			if (wc_symbol == "WC_BUTTON"
				|| wc_symbol == "WC_EDIT"
				|| wc_symbol == "WC_STATIC"
				|| wc_symbol == "WC_LISTBOX"
				|| wc_symbol == "WC_COMBOBOX"
				|| wc_symbol == "WC_SCROLLBAR"
				|| wc_symbol == "PROGRESS_CLASS") {
				return "button-demo(+ widgets-demo for some)";
			}
			switch (wc_symbol) {
			case "WC_LISTVIEW":
			case "WC_TREEVIEW":
			case "WC_TABCONTROL":
			case "TOOLBARCLASSNAME":
			case "MONTHCAL_CLASS":
			case "DATETIMEPICK_CLASS":
			case "TOOLTIPS_CLASS":
				return "widgets-demo";
			default:
				return "—";
			}
		}

		static string ergo_runtime_note(string wc, bool profiled, string ergo) {
			if (ergo == "—") {
				return "**No ergo example yet**";
			}
			switch (wc) {
			case "TOOLTIPS_CLASS":
				return "In demo; hover tips need profile + `TTM_ADDTOOL`";
			case "TOOLBARCLASSNAME":
				return "In demo; empty bar without TB buttons";
			case "WC_EDIT":
				return "Single-line; multiline not in any ergo demo";
			default:
				if (profiled) {
					return "Profiled";
				}
				return "Shell only in widgets-demo";
			}
		}

		void append_not_in_ergo_format(GLib.StringBuilder sb) {
			sb.append("\n## Not in ergonomic format yet\n\n");
			sb.append(
				"These matter for product UX but have **no** ergonomic example yet(vapi or shell only):\n\n"
			);
			sb.append("| Want | Suggested next step |\n");
			sb.append("|------|---------------------|\n");
			sb.append(
				"| Multiline edit | `MultilineEdit` profile or extend `Edit`; add to button or widgets demo |\n"
			);
			sb.append(
				"| Rich text | `RichEdit` widget + `win32-ui-controls-richedit`; new `richtext-demo` |\n"
			);
			sb.append(
				"| Working tooltips | `ToolTips.attach(control, text)` profile; wire on button-demo |\n"
			);
			sb.append(
				"| Header, IP address, link, combo ex, pager, … | Profile + one line in widgets-demo or dedicated ergo demo |\n"
			);
			sb.append(
				"| Track A `examples/native/*` | Raw generated vapi — `*-native` exes; debugging generator |\n"
			);
		}

		void append_run(GLib.StringBuilder sb) {
			sb.append("\n## Run ergonomic builds\n\n");
			sb.append("```bash\n");
			sb.append("meson setup build && meson compile -C build\n");
			sb.append("wine build/hello-window.exe\n");
			sb.append("wine build/button-demo.exe\n");
			sb.append("wine build/widgets-demo.exe\n");
			sb.append("# WIN32_WIDGET_DEBUG=1 wine build/widgets-demo.exe\n");
			sb.append("```\n\n");
			sb.append(
				"Build all Track B exes: `meson compile -C build` (needs MinGW + `scripts/setup-mingw-libs.sh`). "
			);
			sb.append("This report does **not** record Wine pass/fail(**6f**).\n");
		}

		void append_gaps(GLib.StringBuilder sb) {
			uint shells = 0;
			uint profiled = 0;
			if (widget_codegen != null) {
				shells = widget_codegen.catalog_size() - widget_codegen.profiled_size();
				profiled = widget_codegen.profiled_size();
			}
			sb.append("\n## Generator snapshot\n\n");
			sb.append_printf(
				"- **%u** ergonomic `.exe` targets(see `meson.build` `ergonomic_apps`)\n",
				ergo_examples().length
			);
			sb.append_printf(
				"- **%u / %u** catalog widgets profiled; **%u** shells without signals\n",
				profiled,
				profiled + shells,
				shells
			);
			sb.append(
				"- Full gap list: [6e-gap-report.md](6e-gap-report.md)\n"
			);
		}

		public static void write_to_file(string path, string markdown) throws GLib.Error {
			var dir = GLib.Path.get_dirname(path);
			GLib.DirUtils.create_with_parents(dir, 0755);
			GLib.FileUtils.set_contents(path, markdown);
		}
	}
}