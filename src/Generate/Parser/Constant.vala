/*
 * win32json constant (ApiFile.Constants[]).
 */

namespace Generate.Parse {
	/** Named constant from win32metadata JSON. */
	public class Constant : Base {
		public string Name { get; set; default = ""; }
		public TypeRef Type { get; set; default = new TypeRef (); }
		public string ValueType { get; set; default = ""; }
		public int64 Value { get; set; default = 0; }
		public string ValueText { get; set; default = ""; }
		public Gee.ArrayList<string> Attrs { get; set; default = new Gee.ArrayList<string> (); }

		public override bool deserialize_property (
			string property_name,
			out Value value,
			ParamSpec pspec,
			Json.Node property_node
		) {
			if (property_name == "Attrs") {
				this.Attrs = Base.deserialize_string_list (property_node);
				value = GLib.Value (typeof (Gee.ArrayList));
				value.set_object (this.Attrs);
				return true;
			}
			if (property_name == "Value") {
				this.Value = 0;
				this.ValueText = "";
				if (property_node.get_node_type () == Json.NodeType.VALUE) {
					if (property_node.get_value_type () == typeof (string)) {
						this.ValueText = property_node.get_string ();
					} else if (property_node.get_value_type () == typeof (int64)) {
						this.Value = property_node.get_int ();
					} else if (property_node.get_value_type () == typeof (double)) {
						this.Value = (int64) property_node.get_double ();
					}
				}
				value = GLib.Value (typeof (int64));
				value.set_int64 (this.Value);
				return true;
			}
			if (property_name == "Type") {
				this.Type = Json.gobject_deserialize (typeof (TypeRef), property_node) as TypeRef;
				if (this.Type == null) {
					this.Type = new TypeRef ();
				}
				value = GLib.Value (typeof (TypeRef));
				value.set_object (this.Type);
				return true;
			}
			return default_deserialize_property (property_name, out value, pspec, property_node);
		}
	}
}
