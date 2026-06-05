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
	append_event_registration_token (types);

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

static string normalize_attr (string a) {
	if (a.length == 0) {
		return a;
	}
	return a.substring (0, 1).up () + a.substring (1).down ();
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

static string strip_c_comments (string s) {
	var sb = new StringBuilder ();
	int i = 0;
	while (i < s.length) {
		if (i + 1 < s.length && s[i:i+2] == "/*") {
			var close = s.index_of ("*/", i + 2);
			if (close < 0) {
				break;
			}
			i = close + 2;
			continue;
		}
		sb.append_c (s[i]);
		i++;
	}
	return sb.str.strip ();
}

static Json.Array extract_param_attrs (string raw) {
	var attrs = new Json.Array ();
	var pos = 0;
	while (true) {
		var open = raw.index_of ("/*", pos);
		if (open < 0) {
			break;
		}
		var close = raw.index_of ("*/", open + 2);
		if (close < 0) {
			break;
		}
		var body = raw.substring (open + 2, close - open - 2).strip ();
		var bracket = body.index_of ("[");
		if (bracket >= 0) {
			body = body.substring (bracket + 1);
		}
		if (body.has_suffix ("]")) {
			body = body.substring (0, body.length - 1);
		}
		foreach (var attr in body.split (",")) {
			var a = attr.strip ();
			if (a.has_prefix ("[")) {
				a = a.substring (1);
			}
			if (a.has_suffix ("]")) {
				a = a.substring (0, a.length - 1);
			}
			a = a.strip ();
			if (a.length > 0) {
				attrs.add_string_element (normalize_attr (a));
			}
		}
		pos = close + 2;
	}
	return attrs;
}

static int find_matching_paren (string text, int open_pos) {
	int depth = 0;
	for (int i = open_pos; i < text.length; i++) {
		if (text[i] == '(') {
			depth++;
		} else if (text[i] == ')') {
			depth--;
			if (depth == 0) {
				return i;
			}
		}
	}
	return -1;
}

static bool is_com_iface_type (string ctype) {
	return ctype.has_prefix ("I") && ctype.index_of_char (' ') < 0 && ctype.index_of_char ('*') < 0;
}

static Json.Object type_from_c (string raw_ctype, bool com = false) {
	var ctype = raw_ctype.strip ();
	var stars = 0;
	while (ctype.has_suffix ("*")) {
		stars++;
		ctype = ctype.substring (0, ctype.length - 1).strip ();
	}
	Json.Object leaf;
	if (is_com_iface_type (ctype)) {
		leaf = api_ref (ctype, true);
	} else {
		leaf = api_ref (ctype, false, ctype == "RECT" ? "Foundation" : "WebView2");
	}
	var node = leaf;
	for (int i = 0; i < stars; i++) {
		var ptr = new Json.Object ();
		ptr.set_string_member ("Kind", "PointerTo");
		ptr.set_object_member ("Child", node);
		node = ptr;
	}
	return node;
}

static string[] split_param_list (string s) {
	string[] out = {};
	int depth = 0;
	int start = 0;
	for (int i = 0; i < s.length; i++) {
		if (s[i] == '(') {
			depth++;
		} else if (s[i] == ')') {
			depth--;
		} else if (s[i] == ',' && depth == 0) {
			out += s.substring (start, i - start).strip ();
			start = i + 1;
		}
	}
	if (start < s.length) {
		out += s.substring (start).strip ();
	}
	return out;
}

static Json.Object? parse_param (string raw) {
	if (raw.length == 0) {
		return null;
	}
	var attrs = extract_param_attrs (raw);
	var cleaned = strip_c_comments (raw);
	if (cleaned.length == 0) {
		return null;
	}
	var space = cleaned.last_index_of (" ");
	if (space <= 0) {
		return null;
	}
	var ctype = cleaned.substring (0, space).strip ();
	var pname = cleaned.substring (space + 1).strip ();
	while (pname.has_prefix ("*")) {
		ctype += "*";
		pname = pname.substring (1).strip ();
	}
	var param = new Json.Object ();
	param.set_string_member ("Name", pname);
	param.set_object_member ("Type", type_from_c (ctype));
	param.set_array_member ("Attrs", attrs);
	return param;
}

static Json.Object? parse_method_blob (string blob) {
	var s = blob.strip ();
	if (!s.has_prefix ("virtual")) {
		return null;
	}
	s = strip_c_comments (s);
	var marker = "HRESULT STDMETHODCALLTYPE ";
	var hr = s.index_of (marker);
	if (hr < 0) {
		return null;
	}
	var rest = s.substring (hr + marker.length);
	var paren = rest.index_of ("(");
	if (paren <= 0) {
		return null;
	}
	var mname = rest.substring (0, paren).strip ();
	if (mname == "QueryInterface" || mname == "AddRef" || mname == "Release") {
		return null;
	}
	var close_paren = find_matching_paren (rest, paren);
	if (close_paren < 0) {
		return null;
	}
	var params_str = rest.substring (paren + 1, close_paren - paren - 1);
	var method = new Json.Object ();
	method.set_string_member ("Name", mname);
	method.set_boolean_member ("SetLastError", false);
	method.set_object_member ("ReturnType", api_ref ("HRESULT", false, "Foundation"));
	method.set_array_member ("ReturnAttrs", new Json.Array ());
	method.set_array_member ("Architectures", new Json.Array ());
	method.set_null_member ("Platform");
	method.set_array_member ("Attrs", new Json.Array ());
	var params = new Json.Array ();
	foreach (var part in split_param_list (params_str)) {
		var p = parse_param (part);
		if (p != null) {
			params.add_object_element (p);
		}
	}
	method.set_array_member ("Params", params);
	return method;
}

static void collect_methods (string block, Json.Array methods) {
	int pos = 0;
	while (true) {
		int vidx = block.index_of ("virtual", pos);
		if (vidx < 0) {
			break;
		}
		int end = block.index_of ("= 0;", vidx);
		if (end < 0) {
			break;
		}
		end += "= 0;".length;
		var blob = block.substring (vidx, end - vidx);
		var m = parse_method_blob (blob);
		if (m != null) {
			methods.add_object_element (m);
		}
		pos = end;
	}
}

static void append_event_registration_token (Json.Array types) {
	for (uint i = 0; i < types.get_length (); i++) {
		var t = types.get_object_element (i);
		if (t.get_string_member ("Name") == "EventRegistrationToken") {
			return;
		}
	}
	var value_field = new Json.Object ();
	value_field.set_string_member ("Name", "value");
	value_field.set_object_member ("Type", api_ref ("Int64", false, "Foundation"));
	value_field.set_array_member ("Attrs", new Json.Array ());
	var fields = new Json.Array ();
	fields.add_object_element (value_field);
	var st = new Json.Object ();
	st.set_string_member ("Name", "EventRegistrationToken");
	st.set_array_member ("Architectures", new Json.Array ());
	st.set_null_member ("Platform");
	st.set_string_member ("Kind", "Struct");
	st.set_int_member ("Size", 8);
	st.set_int_member ("PackingSize", 8);
	st.set_array_member ("Fields", fields);
	types.add_object_element (st);
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
		collect_methods (block, methods);
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
