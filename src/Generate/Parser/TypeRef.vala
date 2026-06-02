/*
 * win32json type reference (Native, ApiRef, …).
 */

namespace Generate.Parse {
	/**
	 * Type descriptor embedded in constants, fields, parameters, and return types.
	 */
	public class TypeRef : Base {
		/** JSON keys match win32json (PascalCase). */
		public string Kind { get; set; default = ""; }
		public string Name { get; set; default = ""; }
		public string TargetKind { get; set; default = ""; }
		public string Api { get; set; default = ""; }
		public Gee.ArrayList<string> Parents { get; set; default = new Gee.ArrayList<string> (); }

		public override bool deserialize_property (
			string property_name,
			out Value value,
			ParamSpec pspec,
			Json.Node property_node
		) {
			if (property_name == "Parents") {
				this.Parents = Base.deserialize_string_list (property_node);
				value = Value (typeof (Gee.ArrayList));
				value.set_object (this.Parents);
				return true;
			}
			return default_deserialize_property (property_name, out value, pspec, property_node);
		}
	}
}
