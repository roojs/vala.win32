/*
 * win32json → vapi shards(Phase 2) or monolith(Phase 1 --monolith).
 */

int main(string[] args) {
	var opt_metadata = "metadata/win32json";
	var opt_filter = "metadata/filters/gui.filter";
	var opt_api_list = "metadata/win32json-api.files";
	var opt_out = "vapi";
	var opt_basename = "win32-ui.generated.vapi";
	var opt_monolith = false;
	var opt_debug = false;
	var opt_debug_critical = false;
	var opt_coverage_report = "";
	var opt_coverage_only = false;
	var opt_symbol_prefix = "Windows.Win32";
	var opt_no_basename_in_symbol = false;
	var opt_cheader = "windows.h";
	var opt_vala_namespace = "";
	var opt_vapi_only = false;

	var options = new OptionEntry[16];
	options[0] = { "metadata", 'm', 0, OptionArg.STRING, ref opt_metadata, "Vendored win32json root(api/ subdir)", "DIR" };
	options[1] = { "filter", 'f', 0, OptionArg.STRING, ref opt_filter, "Symbol filter file", "FILE" };
	options[2] = { "api-list", 'l', 0, OptionArg.STRING, ref opt_api_list, "JSON basename list(win32json-api.files)", "FILE" };
	options[3] = { "out", 'o', 0, OptionArg.STRING, ref opt_out, "Output directory", "DIR" };
	options[4] = { "basename", 'b', 0, OptionArg.STRING, ref opt_basename, "Monolith output filename(--monolith)", "FILE" };
	options[5] = { "monolith", 0, 0, OptionArg.NONE, ref opt_monolith, "Emit single monolith vapi(Phase 1)", null };
	options[6] = { "debug", 'd', 0, OptionArg.NONE, ref opt_debug, "Enable debug output", null };
	options[7] = { "debug-critical", 0, 0, OptionArg.NONE, ref opt_debug_critical,
		"Treat critical warnings as errors", null };
	options[8] = { "coverage-report", 0, 0, OptionArg.STRING, ref opt_coverage_report,
		"Write Phase 6a coverage matrix markdown to PATH", "FILE" };
	options[9] = { "coverage-only", 0, 0, OptionArg.NONE, ref opt_coverage_only,
		"Only write --coverage-report(skip vapi / generated emit)", null };
	options[10] = { "symbol-prefix", 0, 0, OptionArg.STRING, ref opt_symbol_prefix,
		"Metadata symbol prefix(default Windows.Win32)", "PREFIX" };
	options[11] = { "no-basename-in-symbol", 0, 0, OptionArg.NONE, ref opt_no_basename_in_symbol,
		"Omit JSON basename from symbol names(WebView2)", null };
	options[12] = { "cheader", 0, 0, OptionArg.STRING, ref opt_cheader,
		"C header for [CCode(cheader_filename=…)]", "FILE" };
	options[13] = { "vala-namespace", 0, 0, OptionArg.STRING, ref opt_vala_namespace,
		"Override Vala namespace for shard output", "NS" };
	options[14] = { "vapi-only", 0, 0, OptionArg.NONE, ref opt_vapi_only,
		"Emit vapi shards only(skip generated/*.vala)", null };
	options[15] = { null };

	try {
		var ctx = new OptionContext("Generate Win32 vapi from vendored win32json");
		ctx.set_help_enabled(true);
		ctx.add_main_entries(options, null);
		ctx.parse(ref args);
	} catch (OptionError e) {
		stderr.printf("%s\n", e.message);
		return 1;
	}

	Generate.debug_on = opt_debug;
	Generate.debug_critical_enabled = opt_debug_critical;

	GLib.Log.set_default_handler((dom, lvl, msg) => {
		Generate.ApplicationInterface.debug_log("generate-binding", dom, lvl, msg);
	});

	var api_dir = GLib.Path.build_filename(opt_metadata, "api");
	if (!GLib.FileUtils.test(api_dir, GLib.FileTest.IS_DIR)) {
		stderr.printf("missing %s — run ./scripts/vendor-win32json.sh\n", api_dir);
		return 1;
	}

	Generate.SymbolFilter filter;
	try {
		filter = new Generate.SymbolFilter.from_file(opt_filter);
	} catch (GLib.Error e) {
		stderr.printf("filter: %s\n", e.message);
		return 1;
	}

	Generate.Parse.ApiFileEntry[] files;
	try {
		var loaded = Generate.ApiFileList.load_entries(api_dir, opt_api_list);
		files = loaded.to_array();
	} catch (GLib.Error e) {
		stderr.printf("load: %s\n", e.message);
		return 1;
	}

	if (files.length == 0) {
		stderr.printf("no entries in %s\n", opt_api_list);
		return 1;
	}

	var project_root = GLib.Path.get_dirname(GLib.Path.get_dirname(opt_metadata));

	Generate.Parse.ApiFileEntry? controls_entry = null;
	foreach (var file_entry in files) {
		if (file_entry.basename == "UI.Controls.json") {
			controls_entry = file_entry;
			break;
		}
	}

	var conventions_path = GLib.Path.build_filename(project_root, "metadata", "widget-conventions.json");
	Generate.WidgetCodegen? widget_codegen = null;
	Generate.Parse.WidgetConventionsFile? conventions = null;
	try {
		conventions = Generate.Parse.WidgetConventionsFile.load_from_file(conventions_path);
		widget_codegen = new Generate.WidgetCodegen(filter, conventions);
		if (controls_entry != null) {
			widget_codegen.load_catalog(controls_entry);
		}
	} catch (GLib.Error e) {
		stderr.printf("widget conventions: %s\n", e.message);
		return 1;
	}

	if (opt_coverage_report.length > 0) {
		var report_path = opt_coverage_report;
		if (!GLib.Path.is_absolute(report_path)) {
			report_path = GLib.Path.build_filename(project_root, report_path);
		}
		var coverage = new Generate.CoverageReport(filter, widget_codegen, opt_out, project_root);
		var markdown = coverage.emit_markdown(files);
		try {
			Generate.CoverageReport.write_to_file(report_path, markdown);
		} catch (GLib.Error e) {
			stderr.printf("coverage report: %s\n", e.message);
			return 1;
		}
		print("wrote %s(%u bytes)\n", report_path, markdown.length);
	}

	if (opt_coverage_only) {
		return 0;
	}

	GLib.DirUtils.create_with_parents(opt_out, 0755);
	var emitter = new Generate.VapiEmitter(filter);
	emitter.symbol_prefix = opt_symbol_prefix;
	emitter.basename_in_symbol = !opt_no_basename_in_symbol;
	emitter.cheader_filename = opt_cheader;
	emitter.vala_namespace_override = opt_vala_namespace;

	if (opt_monolith) {
		var vapi_text = emitter.emit_all(files);
		var out_path = GLib.Path.build_filename(opt_out, opt_basename);
		try {
			GLib.FileUtils.set_contents(out_path, vapi_text);
		} catch (GLib.Error e) {
			stderr.printf("write %s: %s\n", out_path, e.message);
			return 1;
		}
		print("wrote %s(%u bytes)\n", out_path, vapi_text.length);
		return 0;
	}

	var shards = emitter.emit_all_shards(files);
	foreach (var entry in shards) {
		var pkg_id = entry.key;
		var text = entry.value;
		var out_path = GLib.Path.build_filename(opt_out, pkg_id + ".vapi");
		try {
			GLib.FileUtils.set_contents(out_path, text);
		} catch (GLib.Error e) {
			stderr.printf("write %s: %s\n", out_path, e.message);
			return 1;
		}
		print("wrote %s(%u bytes)\n", out_path, text.length);
	}

	if (opt_vapi_only) {
		return 0;
	}

	var generated_dir = GLib.Path.build_filename(project_root, "generated");
	GLib.DirUtils.create_with_parents(generated_dir, 0755);

	if (controls_entry != null) {
		var literals = emitter.emit_control_class_strings(controls_entry);
		var literals_path = GLib.Path.build_filename(generated_dir, "win32-ui-control-strings.vala");
		try {
			GLib.FileUtils.set_contents(literals_path, literals);
		} catch (GLib.Error e) {
			stderr.printf("write %s: %s\n", literals_path, e.message);
			return 1;
		}
		print("wrote %s(%u bytes)\n", literals_path, literals.length);
	}

	if (widget_codegen != null) {
		print(
			"widget catalog: %u control classes, %u Track B profiles(%s)\n",
			widget_codegen.catalog_size(),
			widget_codegen.profiled_size(),
			conventions_path
		);
	}

	var wide_strings_template = GLib.Path.build_filename(
		project_root, "src", "Generate", "templates", "win32-wide-strings.vala"
	);
	var wide_strings_emitter = new Generate.WideStringsEmitter();
	try {
		var wide_text = wide_strings_emitter.emit_from_template(wide_strings_template);
		var wide_path = GLib.Path.build_filename(generated_dir, "win32-wide-strings.vala");
		GLib.FileUtils.set_contents(wide_path, wide_text);
		print("wrote %s(%u bytes)\n", wide_path, wide_text.length);
	} catch (GLib.Error e) {
		stderr.printf("wide-strings emit: %s\n", e.message);
		return 1;
	}

	var widget_emitter = new Generate.WidgetEmitter();
	var widgets_template = GLib.Path.build_filename(
		project_root, "src", "Generate", "templates", "win32-widgets.vala"
	);

	try {
		var widgets = widget_emitter.emit(widget_codegen, widgets_template);
		var widgets_path = GLib.Path.build_filename(generated_dir, "win32-widgets.vala");
		GLib.FileUtils.set_contents(widgets_path, widgets);
		print(
			"wrote %s(%u bytes, %u widget classes)\n",
			widgets_path,
			widgets.length,
			widget_codegen.catalog_size()
		);
	} catch (GLib.Error e) {
		stderr.printf("widgets emit: %s\n", e.message);
		return 1;
	}

	try {
		var webview2_json_path = GLib.Path.build_filename(project_root, "metadata", "webview2", "api", "WebView2.json");
		var webview2_sync_emitter = new Generate.WebView2ComSyncEmitter();
		webview2_sync_emitter.load_from_files(conventions_path, webview2_json_path);
		var webview2_sync_c = webview2_sync_emitter.emit_c();
		var webview2_sync_h = webview2_sync_emitter.emit_h();
		var webview2_sync_vala = webview2_sync_emitter.emit_vala_externs();
		var webview2_sync_c_path = GLib.Path.build_filename(generated_dir, "win32-ui-webview2-com-sync.c");
		var webview2_sync_h_path = GLib.Path.build_filename(generated_dir, "win32-ui-webview2-com-sync.h");
		var webview2_sync_vala_path = GLib.Path.build_filename(generated_dir, "win32-ui-webview2-com-sync.vala");
		GLib.FileUtils.set_contents(webview2_sync_c_path, webview2_sync_c);
		GLib.FileUtils.set_contents(webview2_sync_h_path, webview2_sync_h);
		GLib.FileUtils.set_contents(webview2_sync_vala_path, webview2_sync_vala);
		print("wrote %s(%u bytes)\n", webview2_sync_c_path, webview2_sync_c.length);
		print("wrote %s(%u bytes)\n", webview2_sync_h_path, webview2_sync_h.length);
		print("wrote %s(%u bytes)\n", webview2_sync_vala_path, webview2_sync_vala.length);

		var webview2_glue_emitter = new Generate.WebView2GlueEmitter();
		webview2_glue_emitter.set_sync_emitter(webview2_sync_emitter);
		var webview2_glue = webview2_glue_emitter.emit_from_file(conventions_path);
		var webview2_glue_path = GLib.Path.build_filename(generated_dir, "win32-ui-webview2-host-glue.vala");
		GLib.FileUtils.set_contents(webview2_glue_path, webview2_glue);
		print("wrote %s(%u bytes)\n", webview2_glue_path, webview2_glue.length);
	} catch (GLib.Error e) {
		stderr.printf("webview2 emit: %s\n", e.message);
		return 1;
	}

	var errors_emitter = new Generate.ErrorEmitter();
	var errors_path = GLib.Path.build_filename(generated_dir, "win32-errors.vala");
	try {
		var errors_text = errors_emitter.emit();
		GLib.FileUtils.set_contents(errors_path, errors_text);
		print("wrote %s(%u bytes)\n", errors_path, errors_text.length);
	} catch (GLib.Error e) {
		stderr.printf("errors emit: %s\n", e.message);
		return 1;
	}

	return 0;
}