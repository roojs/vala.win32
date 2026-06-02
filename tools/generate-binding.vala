/*
 * win32json → vapi/win32-ui.vapi
 */

int main (string[] args) {
	var opt_metadata = "metadata/win32json";
	var opt_filter = "metadata/filters/gui.filter";
	var opt_out = "vapi";
	var opt_basename = "win32-ui.generated.vapi";
	var opt_debug = false;
	var opt_debug_critical = false;

	var options = new OptionEntry[7];
	options[0] = { "metadata", 'm', 0, OptionArg.STRING, ref opt_metadata, "Vendored win32json root (api/ subdir)", "DIR" };
	options[1] = { "filter", 'f', 0, OptionArg.STRING, ref opt_filter, "Symbol filter file", "FILE" };
	options[2] = { "out", 'o', 0, OptionArg.STRING, ref opt_out, "Output directory", "DIR" };
	options[3] = { "basename", 'b', 0, OptionArg.STRING, ref opt_basename, "Output vapi filename", "FILE" };
	options[4] = { "debug", 'd', 0, OptionArg.NONE, ref opt_debug, "Enable debug output", null };
	options[5] = { "debug-critical", 0, 0, OptionArg.NONE, ref opt_debug_critical,
		"Treat critical warnings as errors", null };
	options[6] = { null };

	try {
		var ctx = new OptionContext ("Generate win32-ui.vapi from vendored win32json");
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

	var files = new Gee.ArrayList<Generate.Parse.ApiFileEntry> ();
	try {
		var dir = GLib.Dir.open (api_dir, 0);
		string? name;
		while ((name = dir.read_name ()) != null) {
			if (!name.has_suffix (".json")) {
				continue;
			}
			var path = GLib.Path.build_filename (api_dir, name);
			var doc = Generate.Parse.ApiFile.load_from_file (path);
			files.add (new Generate.Parse.ApiFileEntry (name, doc));
		}
	} catch (GLib.Error e) {
		stderr.printf ("load: %s\n", e.message);
		return 1;
	}

	if (files.size == 0) {
		stderr.printf ("no JSON in %s\n", api_dir);
		return 1;
	}

	var emitter = new Generate.VapiEmitter (filter);
	var vapi_text = emitter.emit_all (files);

	GLib.DirUtils.create_with_parents (opt_out, 0755);
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
