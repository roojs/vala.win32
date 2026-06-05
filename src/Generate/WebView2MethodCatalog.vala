/*
 * Derive WebView2 host glue + COM-sync specs from WebView2.json + filter + overrides.
 * Replaces hand-maintained ergo_native_map rows for glue/com-sync emission (Phase A).
 */

namespace Generate {
	public enum WebView2GlueKind {
		SKIP,
		COM_SYNC_ONLY,
		WEBVIEW_VOID,
		WEBVIEW_STRING,
		WEBVIEW_GET_COM_STRING,
		WEBVIEW_GET_BOOL,
		WEBVIEW_GET_DOUBLE,
		WEBVIEW_PUT_BOOL,
		WEBVIEW_PUT_DOUBLE,
		WEBVIEW_STUB,
	}

	public class WebView2CatalogEntry : Object {
		public string iface_name { get; construct set; default = ""; }
		public string com_method_name { get; construct set; default = ""; }
		public string glue_name { get; construct set; default = ""; }
		public string host { get; construct set; default = "webview"; }
		public WebView2GlueKind glue_kind { get; construct set; default = WebView2GlueKind.SKIP; }
		public Parse.Function com_method { get; construct set; }
		public string? vala_call { get; set; default = null; }

		public bool emit_com_sync {
			get {
				return glue_kind != WebView2GlueKind.SKIP && glue_kind != WebView2GlueKind.WEBVIEW_STUB;
			}
		}

		public bool emit_glue {
			get {
				return glue_kind != WebView2GlueKind.SKIP
					&& glue_kind != WebView2GlueKind.COM_SYNC_ONLY;
			}
		}
	}

	public class WebView2HostOverrides : Object {
		public string symbol_prefix { get; set; default = "Microsoft.Web.WebView2.Win32"; }
		public Gee.ArrayList<string> host_interfaces { get; private set; }
		public Gee.HashSet<string> skip { get; private set; }
		public Gee.HashSet<string> glue_hand { get; private set; }
		public Gee.HashSet<string> async_stub_glue { get; private set; }
		public Gee.HashMap<string, string> vala_call { get; private set; }
		public Gee.HashSet<string> ergo_skip { get; private set; }
		public Gee.HashSet<string> ergo_bool_methods { get; private set; }
		public Gee.HashMap<string, string> ergo_property { get; private set; }

		construct {
			host_interfaces = new Gee.ArrayList<string> ();
			skip = new Gee.HashSet<string> ();
			glue_hand = new Gee.HashSet<string> ();
			async_stub_glue = new Gee.HashSet<string> ();
			vala_call = new Gee.HashMap<string, string> ();
			ergo_skip = new Gee.HashSet<string> ();
			ergo_bool_methods = new Gee.HashSet<string> ();
			ergo_property = new Gee.HashMap<string, string> ();
		}

		public static WebView2HostOverrides load_from_file(string path) throws GLib.Error {
			var parser = new Json.Parser();
			parser.load_from_file(path);
			var root = parser.get_root();
			if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
				throw new GLib.IOError.FAILED("overrides root must be object");
			}
			var obj = root.get_object();
			var overrides = new WebView2HostOverrides();
			var prefix_node = obj.get_member("symbol_prefix");
			if (prefix_node != null && prefix_node.get_value_type() == typeof (string)) {
				overrides.symbol_prefix = prefix_node.get_string();
			}
			read_string_array(obj, "host_interfaces", overrides.host_interfaces);
			read_string_set(obj, "skip", overrides.skip);
			read_string_set(obj, "glue_hand", overrides.glue_hand);
			read_string_set(obj, "async_stub_glue", overrides.async_stub_glue);
			read_string_set(obj, "ergo_skip", overrides.ergo_skip);
			read_string_set(obj, "ergo_bool_methods", overrides.ergo_bool_methods);
			var vala_call_node = obj.get_member("vala_call");
			if (vala_call_node != null && vala_call_node.get_node_type() == Json.NodeType.OBJECT) {
				var map = vala_call_node.get_object();
				var names = map.get_members();
				foreach (var name in names) {
					var node = map.get_member(name);
					if (node != null && node.get_value_type() == typeof (string)) {
						overrides.vala_call[name] = node.get_string();
					}
				}
			}
			var ergo_property_node = obj.get_member("ergo_property");
			if (ergo_property_node != null && ergo_property_node.get_node_type() == Json.NodeType.OBJECT) {
				var map = ergo_property_node.get_object();
				foreach (var name in map.get_members()) {
					var node = map.get_member(name);
					if (node != null && node.get_value_type() == typeof (string)) {
						overrides.ergo_property[name] = node.get_string();
					}
				}
			}
			if (overrides.host_interfaces.size == 0) {
				overrides.host_interfaces.add_all_array({
					"ICoreWebView2",
					"ICoreWebView2Controller",
				});
			}
			if (overrides.ergo_bool_methods.size == 0) {
				overrides.ergo_bool_methods.add_all_array({
					"execute_script",
					"post_web_message_as_json",
				});
			}
			if (!overrides.ergo_skip.contains("put_bounds")) {
				overrides.ergo_skip.add("put_bounds");
			}
			return overrides;
		}

		public bool is_ergo_skipped(string glue_name) {
			return ergo_skip.contains(glue_name);
		}

		public bool is_ergo_bool_method(string glue_name) {
			return ergo_bool_methods.contains(glue_name);
		}

		public string ergo_property_name(string glue_name) {
			if (ergo_property.has_key(glue_name)) {
				return ergo_property[glue_name];
			}
			if (glue_name.has_prefix("get_is_")) {
				return glue_name.substring(7);
			}
			if (glue_name.has_prefix("put_is_")) {
				return glue_name.substring(7);
			}
			if (glue_name.has_prefix("get_")) {
				return glue_name.substring(4);
			}
			if (glue_name.has_prefix("put_")) {
				return glue_name.substring(4);
			}
			return glue_name;
		}

		public bool is_skipped(string name) {
			return skip.contains(name);
		}

		public bool is_glue_hand(string glue_name) {
			return glue_hand.contains(glue_name);
		}

		public bool is_async_stub(string glue_name) {
			return async_stub_glue.contains(glue_name);
		}

		static void read_string_array(Json.Object obj, string key, Gee.ArrayList<string> dest) {
			var node = obj.get_member(key);
			if (node == null || node.get_node_type() != Json.NodeType.ARRAY) {
				return;
			}
			var arr = node.get_array();
			for (uint i = 0; i < arr.get_length(); i++) {
				var el = arr.get_element(i);
				if (el != null && el.get_value_type() == typeof (string)) {
					dest.add(el.get_string());
				}
			}
		}

		static void read_string_set(Json.Object obj, string key, Gee.HashSet<string> dest) {
			var node = obj.get_member(key);
			if (node == null || node.get_node_type() != Json.NodeType.ARRAY) {
				return;
			}
			var arr = node.get_array();
			for (uint i = 0; i < arr.get_length(); i++) {
				var el = arr.get_element(i);
				if (el != null && el.get_value_type() == typeof (string)) {
					dest.add(el.get_string());
				}
			}
		}
	}

	public class WebView2MethodCatalog : Object {
		public Gee.ArrayList<WebView2CatalogEntry> entries { get; private set; default = new Gee.ArrayList<WebView2CatalogEntry> (); }
		public WebView2HostOverrides host_overrides { get; private set; }

		public void load(
			string webview2_json_path,
			string filter_path,
			string overrides_path
		) throws GLib.Error {
			entries.clear();
			var filter = new SymbolFilter.from_file(filter_path);
			var overrides = WebView2HostOverrides.load_from_file(overrides_path);
			host_overrides = overrides;
			var com_types = load_com_types(webview2_json_path);
			var seen = new Gee.HashSet<string> ();
			foreach (var iface_name in overrides.host_interfaces) {
				var symbol = overrides.symbol_prefix + "." + iface_name;
				if (!filter.include_symbol(symbol)) {
					continue;
				}
				if (!com_types.has_key(iface_name)) {
					stderr.printf("webview2 catalog: missing interface %s in WebView2.json\n", iface_name);
					continue;
				}
				var com_type = com_types[iface_name];
				foreach (var method in com_type.Methods) {
					var entry = classify_entry(iface_name, method, overrides);
					if (entry == null || entry.glue_kind == WebView2GlueKind.SKIP) {
						continue;
					}
					if (seen.contains(entry.glue_name)) {
						continue;
					}
					seen.add(entry.glue_name);
					entries.add(entry);
				}
			}
			entries.sort((a, b) => a.glue_name.collate(b.glue_name));
		}

		static Gee.HashMap<string, Parse.MetadataType> load_com_types(string json_path) throws GLib.Error {
			var com_types = new Gee.HashMap<string, Parse.MetadataType> ();
			var parser = new Json.Parser();
			parser.load_from_file(json_path);
			var root = parser.get_root();
			if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
				throw new GLib.IOError.FAILED("WebView2.json root must be object");
			}
			var types_node = root.get_object().get_member("Types");
			if (types_node == null || types_node.get_node_type() != Json.NodeType.ARRAY) {
				return com_types;
			}
			var arr = types_node.get_array();
			for (uint i = 0; i < arr.get_length(); i++) {
				var type = Json.gobject_deserialize(typeof (Parse.MetadataType), arr.get_element(i)) as Parse.MetadataType;
				if (type != null && type.Kind == "Com") {
					com_types[type.Name] = type;
				}
			}
			return com_types;
		}

		static WebView2CatalogEntry? classify_entry(
			string iface_name,
			Parse.Function method,
			WebView2HostOverrides overrides
		) {
			var glue_name = NameMapper.com_method_name(method.Name);
			if (overrides.is_skipped(glue_name) || overrides.is_skipped(method.Name)) {
				return null;
			}
			if (method.Name.has_prefix("add_") || method.Name.has_prefix("remove_")) {
				return null;
			}
			WebView2GlueKind kind;
			if (overrides.is_async_stub(glue_name)) {
				kind = WebView2GlueKind.WEBVIEW_STUB;
			} else if (overrides.is_glue_hand(glue_name)) {
				kind = WebView2GlueKind.COM_SYNC_ONLY;
			} else {
				kind = classify_by_signature(method);
			}
			if (kind == WebView2GlueKind.SKIP) {
				return null;
			}
			var entry = new WebView2CatalogEntry() {
				iface_name = iface_name,
				com_method_name = method.Name,
				glue_name = glue_name,
				host = default_host(iface_name),
				glue_kind = kind,
				com_method = method,
			};
			if (overrides.vala_call.has_key(glue_name)) {
				entry.vala_call = overrides.vala_call[glue_name];
			}
			return entry;
		}

		static WebView2GlueKind classify_by_signature(Parse.Function method) {
			if (method.Name.has_prefix("get_")) {
				if (method.Params.size != 1) {
					return WebView2GlueKind.SKIP;
				}
				var out_kind = pointer_out_kind(method.Params[0].Type);
				if (out_kind == "LPWSTR") {
					return WebView2GlueKind.WEBVIEW_GET_COM_STRING;
				}
				if (out_kind == "BOOL") {
					return WebView2GlueKind.WEBVIEW_GET_BOOL;
				}
				if (is_floating_type(out_kind)) {
					return WebView2GlueKind.WEBVIEW_GET_DOUBLE;
				}
				return WebView2GlueKind.SKIP;
			}
			if (method.Name.has_prefix("put_")) {
				if (method.Params.size != 1) {
					return WebView2GlueKind.SKIP;
				}
				var in_kind = value_kind(method.Params[0].Type);
				if (in_kind == "BOOL") {
					return WebView2GlueKind.WEBVIEW_PUT_BOOL;
				}
				if (is_floating_type(in_kind)) {
					return WebView2GlueKind.WEBVIEW_PUT_DOUBLE;
				}
				if (in_kind == "RECT") {
					return WebView2GlueKind.COM_SYNC_ONLY;
				}
				return WebView2GlueKind.SKIP;
			}
			if (method.Params.size == 0) {
				return WebView2GlueKind.WEBVIEW_VOID;
			}
			if (method.Params.size == 1 && value_kind(method.Params[0].Type) == "LPCWSTR") {
				return WebView2GlueKind.WEBVIEW_STRING;
			}
			if (has_handler_param(method)) {
				return WebView2GlueKind.SKIP;
			}
			return WebView2GlueKind.SKIP;
		}

		static bool has_handler_param(Parse.Function method) {
			foreach (var param in method.Params) {
				if (type_is_handler(param.Type)) {
					return true;
				}
			}
			return false;
		}

		static string default_host(string iface_name) {
			if (iface_name.has_prefix("ICoreWebView2Controller")) {
				return "controller";
			}
			return "webview";
		}

		static string? pointer_out_kind(Parse.TypeRef type_ref) {
			if (type_ref.Kind != "PointerTo" || type_ref.Child == null) {
				return null;
			}
			return value_kind(type_ref.Child);
		}

		static string? value_kind(Parse.TypeRef type_ref) {
			if (type_ref.Kind == "ApiRef") {
				return type_ref.Name;
			}
			if (type_ref.Kind == "PointerTo" && type_ref.Child != null) {
				return value_kind(type_ref.Child);
			}
			return null;
		}

		static bool type_is_handler(Parse.TypeRef type_ref) {
			var name = innermost_type_name(type_ref);
			if (name == null) {
				return false;
			}
			return name.has_suffix("EventHandler") || name.has_suffix("CompletedHandler");
		}

		static bool is_floating_type(string? name) {
			return name == "DOUBLE" || name == "double";
		}

		static string? innermost_type_name(Parse.TypeRef type_ref) {
			if (type_ref.Kind == "ApiRef") {
				return type_ref.Name;
			}
			if (type_ref.Kind == "PointerTo" && type_ref.Child != null) {
				return innermost_type_name(type_ref.Child);
			}
			return null;
		}
	}
}
