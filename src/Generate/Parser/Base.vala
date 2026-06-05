/*
 * Shared Json.Serializable glue for win32json model types.
 */

namespace Generate.Parse {
	/**
	 * Base for types deserialized from vendored win32json via Json.gobject_deserialize.
	 */
	public abstract class Base : Object, Json.Serializable {
		public unowned ParamSpec? find_property(string name) {
			return this.get_class().find_property(name);
		}

		public new void Json.Serializable.set_property(ParamSpec pspec, Value value) {
			base.set_property(pspec.get_name(), value);
		}

		public new Value Json.Serializable.get_property(ParamSpec pspec) {
			Value val = Value(pspec.value_type);
			base.get_property(pspec.get_name(), ref val);
			return val;
		}

		public virtual bool deserialize_property(
			string property_name,
			out Value value,
			ParamSpec pspec,
			Json.Node property_node
		) {
			return default_deserialize_property(property_name, out value, pspec, property_node);
		}

		/**
		 * win32json string arrays may mix plain strings and objects(e.g. MemorySize attrs).
		 */
		public static Gee.ArrayList<string> deserialize_string_list(Json.Node property_node) {
			var list = new Gee.ArrayList<string> ();
			if (property_node.get_node_type() != Json.NodeType.ARRAY) {
				return list;
			}
			var arr = property_node.get_array();
			for (uint i = 0; i < arr.get_length(); i++) {
				var el = arr.get_element(i);
				if (el == null) {
					continue;
				}
				switch (el.get_node_type()) {
				case Json.NodeType.VALUE:
					if (el.get_value_type() == typeof (string)) {
						list.add(el.get_string());
					}
					break;
				case Json.NodeType.OBJECT:
					var obj = el.get_object();
					var kind = obj.get_member("Kind");
					if (kind != null && kind.get_value_type() == typeof (string)) {
						list.add(kind.get_string());
					}
					break;
				default:
					break;
				}
			}
			return list;
		}
	}
}