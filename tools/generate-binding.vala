/*
 * win32json → vapi shards (Phase 2) or monolith (Phase 1 --monolith).
 */

int main (string[] args) {
	var opt_metadata = "metadata/win32json";
	var opt_filter = "metadata/filters/gui.filter";
	var opt_api_list = "metadata/win32json-api.files";
	var opt_out = "vapi";
	var opt_basename = "win32-ui.generated.vapi";
	var opt_monolith = false;
	var opt_debug = false;
	var opt_debug_critical = false;

	var options = new OptionEntry[9];
	options[0] = { "metadata", 'm', 0, OptionArg.STRING, ref opt_metadata, "Vendored win32json root (api/ subdir)", "DIR" };
	options[1] = { "filter", 'f', 0, OptionArg.STRING, ref opt_filter, "Symbol filter file", "FILE" };
	options[2] = { "api-list", 'l', 0, OptionArg.STRING, ref opt_api_list, "JSON basename list (win32json-api.files)", "FILE" };
	options[3] = { "out", 'o', 0, OptionArg.STRING, ref opt_out, "Output directory", "DIR" };
	options[4] = { "basename", 'b', 0, OptionArg.STRING, ref opt_basename, "Monolith output filename (--monolith)", "FILE" };
	options[5] = { "monolith", 0, 0, OptionArg.NONE, ref opt_monolith, "Emit single monolith vapi (Phase 1)", null };
	options[6] = { "debug", 'd', 0, OptionArg.NONE, ref opt_debug, "Enable debug output", null };
	options[7] = { "debug-critical", 0, 0, OptionArg.NONE, ref opt_debug_critical,
		"Treat critical warnings as errors", null };
	options[8] = { null };

	try {
		var ctx = new OptionContext ("Generate Win32 vapi from vendored win32json");
		ctx.set_help_enabled (true);
		ctx.add_main_entries (options, null);
		ctx.parse (ref args);
	} catch (OptionError e) {
		stderr.printf ("%s\n", e.message);
		return 1;
	}

	Generate.debug_on = opt_debug;
	Generate.debug_critical_enabled = opt_debug_critical;

	GLib.Log.set_default_handler ((dom, lvl, msg) => {
		Generate.ApplicationInterface.debug_log ("generate-binding", dom, lvl, msg);
	});

	var api_dir = GLib.Path.build_filename (opt_metadata, "api");
	if (!GLib.FileUtils.test (api_dir, GLib.FileTest.IS_DIR)) {
		stderr.printf ("missing %s — run ./scripts/vendor-win32json.sh\n", api_dir);
		return 1;
	}

	Generate.SymbolFilter filter;
	try {
		filter = new Generate.SymbolFilter.from_file (opt_filter);
	} catch (GLib.Error e) {
		stderr.printf ("filter: %s\n", e.message);
		return 1;
	}

	Generate.Parse.ApiFileEntry[] files;
	try {
		var loaded = Generate.ApiFileList.load_entries (api_dir, opt_api_list);
		files = loaded.to_array ();
	} catch (GLib.Error e) {
		stderr.printf ("load: %s\n", e.message);
		return 1;
	}

	if (files.length == 0) {
		stderr.printf ("no entries in %s\n", opt_api_list);
		return 1;
	}

	GLib.DirUtils.create_with_parents (opt_out, 0755);
	var emitter = new Generate.VapiEmitter (filter);

	if (opt_monolith) {
		var vapi_text = emitter.emit_all (files);
		var out_path = GLib.Path.build_filename (opt_out, opt_basename);
		try {
			GLib.FileUtils.set_contents (out_path, vapi_text);
		} catch (GLib.Error e) {
			stderr.printf ("write %s: %s\n", out_path, e.message);
			return 1;
		}
		print ("wrote %s (%u bytes)\n", out_path, vapi_text.length);
		return 0;
	}

	var shards = emitter.emit_all_shards (files);
	foreach (var entry in shards) {
		var pkg_id = entry.key;
		var text = entry.value;
		var out_path = GLib.Path.build_filename (opt_out, pkg_id + ".vapi");
		try {
			GLib.FileUtils.set_contents (out_path, text);
		} catch (GLib.Error e) {
			stderr.printf ("write %s: %s\n", out_path, e.message);
			return 1;
		}
		print ("wrote %s (%u bytes)\n", out_path, text.length);
	}

	var project_root = GLib.Path.get_dirname (GLib.Path.get_dirname (opt_metadata));
	var generated_dir = GLib.Path.build_filename (project_root, "generated");
	GLib.DirUtils.create_with_parents (generated_dir, 0755);

	foreach (var file_entry in files) {
		if (file_entry.basename != "UI.Controls.json") {
			continue;
		}
		var literals = emitter.emit_control_class_strings (file_entry);
		var literals_path = GLib.Path.build_filename (generated_dir, "win32-ui-control-strings.vala");
		try {
			GLib.FileUtils.set_contents (literals_path, literals);
		} catch (GLib.Error e) {
			stderr.printf ("write %s: %s\n", literals_path, e.message);
			return 1;
		}
		print ("wrote %s (%u bytes)\n", literals_path, literals.length);
		break;
	}

	var widget_emitter = new Generate.WidgetEmitter ();
	var widgets_template = GLib.Path.build_filename (
		project_root, "src", "Generate", "templates", "win32-widgets.vala"
	);
	try {
		var widgets = widget_emitter.emit_from_template (widgets_template);
		var widgets_path = GLib.Path.build_filename (generated_dir, "win32-widgets.vala");
		GLib.FileUtils.set_contents (widgets_path, widgets);
		print ("wrote %s (%u bytes)\n", widgets_path, widgets.length);
	} catch (GLib.Error e) {
		stderr.printf ("widgets emit: %s\n", e.message);
		return 1;
	}

	return 0;
}
