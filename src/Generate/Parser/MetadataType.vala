/*
 * win32json type entry(ApiFile.Types[]) — struct, enum, delegate, etc.
 */

namespace Generate.Parse {
	/**
	 * Type definition from one namespace JSON file.
	 * Only fields relevant to a given Kind are populated upstream.
	 */
	public class MetadataType : Base {
		public string Name { get; set; default = ""; }
		public string Kind { get; set; default = ""; }
		public string? Platform { get; set; default = null; }
		public bool Flags { get; set; default = false; }
		public bool Scoped { get; set; default = false; }
		public string IntegerBase { get; set; default = ""; }
		public int Size { get; set; default = 0; }
		public int PackingSize { get; set; default = 0; }
		public bool SetLastError { get; set; default = false; }
		public TypeRef ReturnType { get; set; default = new TypeRef(); }
		public Gee.ArrayList<string> Architectures { get; set; default = new Gee.ArrayList<string> (); }
		public Gee.ArrayList<string> Attrs { get; set; default = new Gee.ArrayList<string> (); }
		public Gee.ArrayList<string> ReturnAttrs { get; set; default = new Gee.ArrayList<string> (); }
		public Gee.ArrayList<Field> Fields { get; set; default = new Gee.ArrayList<Field> (); }
		public Gee.ArrayList<EnumValue> Values { get; set; default = new Gee.ArrayList<EnumValue> (); }
		public Gee.ArrayList<Parameter> Params { get; set; default = new Gee.ArrayList<Parameter> (); }
		public Gee.ArrayList<Function> Methods { get; set; default = new Gee.ArrayList<Function> (); }
		public TypeRef Interface { get; set; default = new TypeRef(); }
		public string? Guid { get; set; default = null; }
		public Gee.ArrayList<MetadataType> NestedTypes { get; set; default = new Gee.ArrayList<MetadataType> (); }

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
			case "Fields": {
				this.Fields = new Gee.ArrayList<Field> ();
				if (property_node.get_node_type() == Json.NodeType.ARRAY) {
					var arr = property_node.get_array();
					for (uint i = 0; i < arr.get_length(); i++) {
						var item = Json.gobject_deserialize(typeof (Field), arr.get_element(i)) as Field;
						if (item != null) {
							this.Fields.add(item);
						}
					}
				}
				value = Value(typeof (Gee.ArrayList));
				value.set_object(this.Fields);
				return true;
			}
			case "Values": {
				this.Values = new Gee.ArrayList<EnumValue> ();
				if (property_node.get_node_type() == Json.NodeType.ARRAY) {
					var arr = property_node.get_array();
					for (uint i = 0; i < arr.get_length(); i++) {
						var item = Json.gobject_deserialize(typeof (EnumValue), arr.get_element(i)) as EnumValue;
						if (item != null) {
							this.Values.add(item);
						}
					}
				}
				value = Value(typeof (Gee.ArrayList));
				value.set_object(this.Values);
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
			case "NestedTypes": {
				this.NestedTypes = new Gee.ArrayList<MetadataType> ();
				if (property_node.get_node_type() == Json.NodeType.ARRAY) {
					var arr = property_node.get_array();
					for (uint i = 0; i < arr.get_length(); i++) {
						var item = Json.gobject_deserialize(typeof (MetadataType), arr.get_element(i)) as MetadataType;
						if (item != null) {
							this.NestedTypes.add(item);
						}
					}
				}
				value = Value(typeof (Gee.ArrayList));
				value.set_object(this.NestedTypes);
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
			case "Methods": {
				this.Methods = new Gee.ArrayList<Function> ();
				if (property_node.get_node_type() == Json.NodeType.ARRAY) {
					var arr = property_node.get_array();
					for (uint i = 0; i < arr.get_length(); i++) {
						var item = Json.gobject_deserialize(typeof (Function), arr.get_element(i)) as Function;
						if (item != null) {
							this.Methods.add(item);
						}
					}
				}
				value = Value(typeof (Gee.ArrayList));
				value.set_object(this.Methods);
				return true;
			}
			case "Interface": {
				this.Interface = Json.gobject_deserialize(typeof (TypeRef), property_node) as TypeRef;
				if (this.Interface == null) {
					this.Interface = new TypeRef();
				}
				value = Value(typeof (TypeRef));
				value.set_object(this.Interface);
				return true;
			}
			default:
				return default_deserialize_property(property_name, out value, pspec, property_node);
			}
		}
	}
}