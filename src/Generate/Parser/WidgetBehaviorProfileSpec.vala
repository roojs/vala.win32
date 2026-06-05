/*
 * One Track B profile entry in metadata/widget-conventions.json (Json.Serializable).
 */

namespace Generate.Parse {
	public class WidgetBehaviorProfileSpec : Base {
		public string dispatch_route { get; set; default = "NONE"; }
		public string? signal_name { get; set; }
		public string? wm_notify_const { get; set; }
		public string? wm_notify_code_expr { get; set; }
		public bool init_common_controls { get; set; default = false; }
		public bool uses_control_id { get; set; default = true; }
		public Gee.ArrayList<string> window_style_tokens { get; set; default = new Gee.ArrayList<string> (); }
		public Gee.ArrayList<string> control_style_tokens { get; set; default = new Gee.ArrayList<string> (); }
		public Gee.ArrayList<string> style_literal_exprs { get; set; default = new Gee.ArrayList<string> (); }
		public bool text_property { get; set; default = false; }
		public bool selection_helpers { get; set; default = false; }
		public bool scroll_value_property { get; set; default = false; }
		public bool progress_value_property { get; set; default = false; }
		public bool list_view_helpers { get; set; default = false; }
		public bool tree_view_helpers { get; set; default = false; }
		public bool tab_page_helpers { get; set; default = false; }
		public Gee.ArrayList<ErgoNativeMapEntry> ergo_native_map { get; private set; default = new Gee.ArrayList<ErgoNativeMapEntry> (); }

		public Generate.WidgetBehaviorProfile to_profile (string wc_symbol) throws GLib.Error {
			Generate.WidgetBehaviorProfile result = {};
			result.dispatch_route = parse_dispatch_route (wc_symbol, dispatch_route);
			result.signal_name = signal_name;
			result.wm_notify_const = wm_notify_const;
			result.wm_notify_code_expr = wm_notify_code_expr;
			result.init_common_controls = init_common_controls;
			result.uses_control_id = uses_control_id;
			result.window_style_tokens = window_style_tokens.to_array ();
			result.control_style_tokens = control_style_tokens.to_array ();
			result.style_literal_exprs = style_literal_exprs.to_array ();
			result.text_property = text_property;
			result.selection_helpers = selection_helpers;
			result.scroll_value_property = scroll_value_property;
			result.progress_value_property = progress_value_property;
			result.list_view_helpers = list_view_helpers;
			result.tree_view_helpers = tree_view_helpers;
			result.tab_page_helpers = tab_page_helpers;
			return result;
		}

		static Generate.WidgetDispatchRoute parse_dispatch_route (string wc_symbol, string name) throws GLib.Error {
			switch (name) {
			case "NONE":
				return Generate.WidgetDispatchRoute.NONE;
			case "WM_COMMAND":
				return Generate.WidgetDispatchRoute.WM_COMMAND;
			case "WM_SCROLL":
				return Generate.WidgetDispatchRoute.WM_SCROLL;
			case "WM_NOTIFY":
				return Generate.WidgetDispatchRoute.WM_NOTIFY;
			default:
				throw new GLib.IOError.FAILED (
					"profile %s: unknown dispatch_route %s",
					wc_symbol,
					name
				);
			}
		}

		public override bool deserialize_property (
			string property_name,
			out Value value,
			ParamSpec pspec,
			Json.Node property_node
		) {
			switch (property_name) {
			case "window_style_tokens":
			case "window-style-tokens":
				this.window_style_tokens = Base.deserialize_string_list (property_node);
				value = new Value (typeof (Gee.ArrayList));
				value.set_object (this.window_style_tokens);
				return true;
			case "control_style_tokens":
			case "control-style-tokens":
				this.control_style_tokens = Base.deserialize_string_list (property_node);
				value = new Value (typeof (Gee.ArrayList));
				value.set_object (this.control_style_tokens);
				return true;
			case "style_literal_exprs":
			case "style-literal-exprs":
				this.style_literal_exprs = Base.deserialize_string_list (property_node);
				value = new Value (typeof (Gee.ArrayList));
				value.set_object (this.style_literal_exprs);
				return true;
			case "ergo_native_map":
				this.ergo_native_map = new Gee.ArrayList<ErgoNativeMapEntry> ();
				if (property_node.get_node_type () == Json.NodeType.ARRAY) {
					var arr = property_node.get_array ();
					for (uint i = 0; i < arr.get_length (); i++) {
						var entry = Json.gobject_deserialize (
							typeof (ErgoNativeMapEntry),
							arr.get_element (i)
						) as ErgoNativeMapEntry;
						if (entry != null) {
							this.ergo_native_map.add (entry);
						}
					}
				}
				value = new Value (typeof (Gee.ArrayList));
				value.set_object (this.ergo_native_map);
				return true;
			default:
				return default_deserialize_property (property_name, out value, pspec, property_node);
			}
		}
	}
}
