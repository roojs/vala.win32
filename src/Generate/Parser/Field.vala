/*
 * win32json struct field(Types[].Fields[]).
 */

namespace Generate.Parse {
	/** Field on a struct or similar type definition. */
	public class Field : Base {
		public string Name { get; set; default = ""; }
		public TypeRef Type { get; set; default = new TypeRef(); }
		public Gee.ArrayList<string> Attrs { get; set; default = new Gee.ArrayList<string> (); }

		public override bool deserialize_property(
			string property_name,
			out Value value,
			ParamSpec pspec,
			Json.Node property_node
		) {
			if (property_name == "Attrs") {
				this.Attrs = Base.deserialize_string_list(property_node);
				value = Value(typeof (Gee.ArrayList));
				value.set_object(this.Attrs);
				return true;
			}
			if (property_name == "Type") {
				this.Type = Json.gobject_deserialize(typeof (TypeRef), property_node) as TypeRef;
				if (this.Type == null) {
					this.Type = new TypeRef();
				}
				value = Value(typeof (TypeRef));
				value.set_object(this.Type);
				return true;
			}
			return default_deserialize_property(property_name, out value, pspec, property_node);
		}
	}
}