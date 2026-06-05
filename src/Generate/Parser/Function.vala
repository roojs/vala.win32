/*
 * win32json P/Invoke function(ApiFile.Functions[]).
 */

namespace Generate.Parse {
	/** Win32 API function exported from a namespace JSON file. */
	public class Function : Base {
		public string Name { get; set; default = ""; }
		public bool SetLastError { get; set; default = false; }
		public string DllImport { get; set; default = ""; }
		public TypeRef ReturnType { get; set; default = new TypeRef(); }
		public string? Platform { get; set; default = null; }
		public Gee.ArrayList<string> Architectures { get; set; default = new Gee.ArrayList<string> (); }
		public Gee.ArrayList<string> Attrs { get; set; default = new Gee.ArrayList<string> (); }
		public Gee.ArrayList<string> ReturnAttrs { get; set; default = new Gee.ArrayList<string> (); }
		public Gee.ArrayList<Parameter> Params { get; set; default = new Gee.ArrayList<Parameter> (); }

		public override bool deserialize_property(
			string property_name,
			out Value value,
			ParamSpec pspec,
			Json.Node property_node
		) {
			switch (property_name) {
			case "Architectures":
			case "Attrs":
			case "ReturnAttrs": {
				var list = Base.deserialize_string_list(property_node);
				if (property_name == "Architectures") {
					this.Architectures = list;
				} else if (property_name == "Attrs") {
					this.Attrs = list;
				} else {
					this.ReturnAttrs = list;
				}
				value = Value(typeof (Gee.ArrayList));
				value.set_object(list);
				return true;
			}
			case "Params": {
				this.Params = new Gee.ArrayList<Parameter> ();
				if (property_node.get_node_type() == Json.NodeType.ARRAY) {
					var arr = property_node.get_array();
					for (uint i = 0; i < arr.get_length(); i++) {
						var item = Json.gobject_deserialize(typeof (Parameter), arr.get_element(i)) as Parameter;
						if (item != null) {
							this.Params.add(item);
						}
					}
				}
				value = Value(typeof (Gee.ArrayList));
				value.set_object(this.Params);
				return true;
			}
			case "ReturnType": {
				this.ReturnType = Json.gobject_deserialize(typeof (TypeRef), property_node) as TypeRef;
				if (this.ReturnType == null) {
					this.ReturnType = new TypeRef();
				}
				value = Value(typeof (TypeRef));
				value.set_object(this.ReturnType);
				return true;
			}
			default:
				return default_deserialize_property(property_name, out value, pspec, property_node);
			}
		}
	}
}