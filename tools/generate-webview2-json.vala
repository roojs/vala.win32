/*
 * Scrape vendored WebView2.h → win32json-shaped metadata/webview2/api/WebView2.json
 * (Phase 7i). Bash regen: ./scripts/regen-webview2-json.sh
 */

using Json;

int main (string[] args) {
	var header_path = "";
	var out_path = "";
	var prefix = "ICoreWebView2";

	var options = new OptionEntry[4];
	options[0] = { "header", 'h', 0, OptionArg.STRING, ref header_path, "Path to WebView2.h", "FILE" };
	options[1] = { "out", 'o', 0, OptionArg.STRING, ref out_path, "Output WebView2.json", "FILE" };
	options[2] = { "prefix", 'p', 0, OptionArg.STRING, ref prefix, "Interface name prefix", "PREFIX" };
	options[3] = { null };

	try {
		var ctx = new OptionContext ("generate-webview2-json");
		ctx.set_help_enabled (true);
		ctx.add_main_entries (options, null);
		ctx.parse (ref args);
	} catch (OptionError e) {
		stderr.printf ("%s\n", e.message);
		return 1;
	}

	if (header_path.length == 0 || out_path.length == 0) {
		stderr.printf ("Usage: generate-webview2-json --header PATH --out PATH [--prefix ICoreWebView2]\n");
		return 1;
	}

	string text;
	try {
		GLib.FileUtils.get_contents (header_path, out text);
	} catch (GLib.FileError e) {
		stderr.printf ("%s\n", e.message);
		return 1;
	}

	var root = new Json.Object ();
	var types = new Json.Array ();

	scrape_enums (text, types);
	scrape_interfaces (text, prefix, types);

	root.set_array_member ("Constants", new Json.Array ());
	root.set_array_member ("Types", types);
	root.set_array_member ("Functions", new Json.Array ());
	root.set_array_member ("UnicodeAliases", new Json.Array ());

	var gen = new Json.Generator ();
	gen.set_root (new Json.Node.alloc ().init_object (root));
	gen.set_pretty (true);
	gen.set_indent (1);

	var dir = GLib.Path.get_dirname (out_path);
	if (dir.length > 0 && dir != ".") {
		GLib.DirUtils.create_with_parents (dir, 0755);
	}

	try {
		gen.to_file (out_path);
	} catch (GLib.Error e) {
		stderr.printf ("%s\n", e.message);
		return 1;
	}

	stdout.printf ("Wrote %u types to %s\n", types.get_length (), out_path);
	return 0;
}

static Json.Object api_ref (string name, bool com = false, string api = "WebView2") {
	var o = new Json.Object ();
	o.set_string_member ("Kind", "ApiRef");
	o.set_string_member ("Name", name);
	o.set_string_member ("TargetKind", com ? "Com" : "Default");
	o.set_string_member ("Api", api);
	o.set_array_member ("Parents", new Json.Array ());
	return o;
}

static Json.Object? parse_method_line (string line) {
	if (!line.has_prefix ("virtual")) {
		return null;
	}
	var rest = line.substring ("virtual".length).strip ();
	if (rest.has_prefix ("/*")) {
		var close = rest.index_of ("*/");
		if (close < 0) {
			return null;
		}
		rest = rest.substring (close + 2).strip ();
	}
	if (!rest.has_prefix ("HRESULT STDMETHODCALLTYPE ")) {
		return null;
	}
	rest = rest.substring ("HRESULT STDMETHODCALLTYPE ".length);
	var paren = rest.index_of ("(");
	if (paren <= 0) {
		return null;
	}
	var mname = rest.substring (0, paren).strip ();
	if (mname == "QueryInterface" || mname == "AddRef" || mname == "Release") {
		return null;
	}
	var method = new Json.Object ();
	method.set_string_member ("Name", mname);
	method.set_boolean_member ("SetLastError", false);
	method.set_object_member ("ReturnType", api_ref ("HRESULT", false, "Foundation"));
	method.set_array_member ("ReturnAttrs", new Json.Array ());
	method.set_array_member ("Architectures", new Json.Array ());
	method.set_null_member ("Platform");
	method.set_array_member ("Attrs", new Json.Array ());
	method.set_array_member ("Params", new Json.Array ());
	return method;
}

static int find_matching_brace (string text, int open_pos) {
	int depth = 0;
	for (int i = open_pos; i < text.length; i++) {
		if (text[i] == '{') {
			depth++;
		} else if (text[i] == '}') {
			depth--;
			if (depth == 0) {
				return i;
			}
		}
	}
	return -1;
}

static void scrape_enum_body (string body, Json.Array values) {
	foreach (var line in body.split ("\n")) {
		var s = line.strip ().replace ("\t", "");
		if (!s.has_prefix ("COREWEBVIEW2_")) {
			continue;
		}
		var eq = s.index_of ("=");
		if (eq < 0) {
			continue;
		}
		var name = s.substring (0, eq).strip ();
		var rhs = s.substring (eq + 1).strip ();
		if (rhs.has_suffix (",")) {
			rhs = rhs.substring (0, rhs.length - 1).strip ();
		}
		int64 val = 0;
		if (rhs.has_prefix ("0x")) {
			uint64 parsed = 0;
			if (uint64.try_parse (rhs, out parsed)) {
				val = (int64) parsed;
			}
		} else {
			var space = rhs.index_of (" ");
			var num = space >= 0 ? rhs.substring (0, space) : rhs;
			int64 parsed = 0;
			if (int64.try_parse (num, out parsed)) {
				val = parsed;
			}
		}
		var ev = new Json.Object ();
		ev.set_string_member ("Name", name);
		ev.set_int_member ("Value", (int) val);
		values.add_object_element (ev);
	}
}

static void scrape_enums (string text, Json.Array types) {
	const string marker = "enum COREWEBVIEW2_";
	int pos = 0;
	while (true) {
		int idx = text.index_of (marker, pos);
		if (idx < 0) {
			break;
		}
		int name_start = idx + "enum ".length;
		int brace = text.index_of ("{", name_start);
		if (brace < 0 || brace <= name_start) {
			pos = idx + 1;
			continue;
		}
		var ename = text.substring (name_start, brace - name_start).strip ();
		int close = find_matching_brace (text, brace);
		if (close < 0 || close <= brace) {
			pos = idx + 1;
			continue;
		}
		var body = text.substring (brace + 1, close - brace - 1);
		var values = new Json.Array ();
		scrape_enum_body (body, values);
		if (values.get_length () == 0) {
			pos = close + 1;
			continue;
		}
		var t = new Json.Object ();
		t.set_string_member ("Name", ename);
		t.set_array_member ("Architectures", new Json.Array ());
		t.set_null_member ("Platform");
		t.set_string_member ("Kind", "Enum");
		t.set_boolean_member ("Flags", ename.contains ("FLAGS"));
		t.set_string_member ("IntegerBase", "Int32");
		t.set_array_member ("Values", values);
		types.add_object_element (t);
		pos = close + 1;
	}
}

static bool is_valid_iface_name (string name, string prefix) {
	if (!name.has_prefix (prefix)) {
		return false;
	}
	/* Reject typedef forward refs and preprocessor debris (e.g. "ICoreWebView2 ICoreWebView2;"). */
	if (name.index_of_char (' ') >= 0
	    || name.index_of_char (';') >= 0
	    || name.index_of_char ('\r') >= 0
	    || name.index_of_char ('\n') >= 0
	    || name.index_of_char ('#') >= 0) {
		return false;
	}
	return true;
}

static void scrape_interfaces (string text, string prefix, Json.Array types) {
	/* C++ COM decls in WebView2.h: "ICoreWebView2 : public IUnknown" then "{". Skip "typedef interface". */
	const string marker = ": public IUnknown";
	int pos = 0;
	while (true) {
		int idx = text.index_of (marker, pos);
		if (idx < 0) {
			break;
		}
		/* last_index_of(s, start) searches forward from start in Vala/GLib; use prefix only. */
		var line_prefix = text.substring (0, idx);
		int line_start = line_prefix.last_index_of ("\n");
		if (line_start < 0) {
			line_start = 0;
		} else {
			line_start++;
		}
		/* Text before ": public IUnknown" is the interface name (e.g. "ICoreWebView2"). */
		var iname = text.substring (line_start, idx - line_start).strip ();
		if (!is_valid_iface_name (iname, prefix)) {
			pos = idx + 1;
			continue;
		}
		int brace = text.index_of ("{", idx);
		if (brace < 0 || brace - idx > 64) {
			pos = idx + 1;
			continue;
		}
		int close = find_matching_brace (text, brace);
		if (close < 0 || close <= brace) {
			pos = idx + 1;
			continue;
		}
		var block = text.substring (brace + 1, close - brace - 1);
		var methods = new Json.Array ();
		foreach (var body_line in block.split ("\n")) {
			var m = parse_method_line (body_line.strip ());
			if (m != null) {
				methods.add_object_element (m);
			}
		}
		if (methods.get_length () == 0) {
			pos = idx + 1;
			continue;
		}
		var t = new Json.Object ();
		t.set_string_member ("Name", iname);
		t.set_array_member ("Architectures", new Json.Array ());
		t.set_null_member ("Platform");
		t.set_string_member ("Kind", "Com");
		t.set_null_member ("Guid");
		t.set_array_member ("Attrs", new Json.Array ());
		t.set_object_member ("Interface", api_ref ("IUnknown", true, "System.Com"));
		t.set_array_member ("Methods", methods);
		types.add_object_element (t);
		pos = close + 1;
	}
}
