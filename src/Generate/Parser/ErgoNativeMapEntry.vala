/*
 * One row in profiles.WebView2.ergo_native_map(metadata/widget-conventions.json).
 */

namespace Generate.Parse {
	public class ErgoNativeMapEntry : Base {
		public string kind { get; set; default = ""; }
		public string ergo { get; set; default = ""; }
		public string glue { get; set; default = ""; }
		public string com { get; set; default = ""; }
		public string status { get; set; default = ""; }
		public Gee.ArrayList<SyncComSpec> sync_com { get; set; default = new Gee.ArrayList<SyncComSpec> (); }

		public override bool deserialize_property(
			string property_name,
			out Value value,
			ParamSpec pspec,
			Json.Node property_node
		) {
			if (property_name != "sync_com") {
				return default_deserialize_property(property_name, out value, pspec, property_node);
			}
			this.sync_com = deserialize_sync_com(property_node);
			value = new Value(typeof (Gee.ArrayList));
			value.set_object(this.sync_com);
			return true;
		}

		public static Gee.ArrayList<SyncComSpec> deserialize_sync_com(Json.Node? node) {
			var specs = new Gee.ArrayList<SyncComSpec> ();
			if (node == null) {
				return specs;
			}
			if (node.get_node_type() == Json.NodeType.ARRAY) {
				var arr = node.get_array();
				for (uint i = 0; i < arr.get_length(); i++) {
					var el = arr.get_element(i);
					if (el != null && el.get_node_type() == Json.NodeType.OBJECT) {
						specs.add(read_sync_com_spec(el.get_object()));
					}
				}
				return specs;
			}
			if (node.get_node_type() == Json.NodeType.OBJECT) {
				specs.add(read_sync_com_spec(node.get_object()));
				return specs;
			}
			if (node.get_node_type() == Json.NodeType.VALUE && node.get_value_type() == typeof (bool) && node.get_boolean()) {
				specs.add(new SyncComSpec());
			}
			return specs;
		}

		static SyncComSpec read_sync_com_spec(Json.Object obj) {
			var spec = new SyncComSpec();
			spec.glue = read_optional_string(obj, "glue");
			spec.com = read_optional_string(obj, "com");
			spec.host = read_optional_string(obj, "host");
			spec.vala_call = read_optional_string(obj, "vala_call");
			if (spec.vala_call == null) {
				spec.vala_call = read_optional_string(obj, "vala-call");
			}
			return spec;
		}

		static string? read_optional_string(Json.Object obj, string name) {
			var node = obj.get_member(name);
			if (node != null && node.get_value_type() == typeof (string)) {
				return node.get_string();
			}
			return null;
		}
	}
}
