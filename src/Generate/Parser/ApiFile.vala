/*
 * One win32json api/*.json namespace file.
 */

namespace Generate.Parse {
	/**
	 * Root object for a vendored win32json namespace blob.
	 * File name {@code UI.WindowsAndMessaging.json} → namespace {@code Windows.Win32.UI.WindowsAndMessaging}.
	 */
	public class ApiFile : Base {
		public Gee.ArrayList<Constant> Constants { get; set; default = new Gee.ArrayList<Constant> (); }
		public Gee.ArrayList<MetadataType> Types { get; set; default = new Gee.ArrayList<MetadataType> (); }
		public Gee.ArrayList<Function> Functions { get; set; default = new Gee.ArrayList<Function> (); }
		public Gee.ArrayList<string> UnicodeAliases { get; set; default = new Gee.ArrayList<string> (); }

		/**
		 * Load a namespace JSON file from disk.
		 *
		 * @param path path to e.g. metadata/win32json/api/UI.WindowsAndMessaging.json
		 * @return deserialized API file
		 */
		public static ApiFile load_from_file(string path) throws GLib.Error {
			var parser = new Json.Parser();
			parser.load_from_file(path);
			var node = parser.get_root();
			if (node == null || node.get_node_type() != Json.NodeType.OBJECT) {
				throw new GLib.FileError.FAILED("Expected JSON object in %s", path);
			}
			var doc = Json.gobject_deserialize(typeof (ApiFile), node) as ApiFile;
			if (doc == null) {
				throw new GLib.FileError.FAILED("Failed to deserialize %s", path);
			}
			return doc;
		}

		/**
		 * Namespace prefix for symbols in this file.
		 *
		 * @param file_basename e.g. {@code UI.WindowsAndMessaging.json}
		 */
		public static string namespace_from_basename(string file_basename) {
			if (file_basename.has_suffix(".json")) {
				return "Windows.Win32." + file_basename.slice(0, -5);
			}
			return "Windows.Win32." + file_basename;
		}

		/**
		 * Full metadata name for a top-level symbol in this file.
		 *
		 * @param basename json file basename
		 * @param symbol_name entry Name field
		 */
		public static string full_name(string basename, string symbol_name) {
			return namespace_from_basename(basename) + "." + symbol_name;
		}

		public override bool deserialize_property(
			string property_name,
			out Value value,
			ParamSpec pspec,
			Json.Node property_node
		) {
			switch (property_name) {
			case "Constants": {
				this.Constants = new Gee.ArrayList<Constant> ();
				if (property_node.get_node_type() == Json.NodeType.ARRAY) {
					var arr = property_node.get_array();
					for (uint i = 0; i < arr.get_length(); i++) {
						var item = Json.gobject_deserialize(typeof (Constant), arr.get_element(i)) as Constant;
						if (item != null) {
							this.Constants.add(item);
						}
					}
				}
				value = Value(typeof (Gee.ArrayList));
				value.set_object(this.Constants);
				return true;
			}
			case "Types": {
				this.Types = new Gee.ArrayList<MetadataType> ();
				if (property_node.get_node_type() == Json.NodeType.ARRAY) {
					var arr = property_node.get_array();
					for (uint i = 0; i < arr.get_length(); i++) {
						var item = Json.gobject_deserialize(typeof (MetadataType), arr.get_element(i)) as MetadataType;
						if (item != null) {
							this.Types.add(item);
						}
					}
				}
				value = Value(typeof (Gee.ArrayList));
				value.set_object(this.Types);
				return true;
			}
			case "Functions": {
				this.Functions = new Gee.ArrayList<Function> ();
				if (property_node.get_node_type() == Json.NodeType.ARRAY) {
					var arr = property_node.get_array();
					for (uint i = 0; i < arr.get_length(); i++) {
						var item = Json.gobject_deserialize(typeof (Function), arr.get_element(i)) as Function;
						if (item != null) {
							this.Functions.add(item);
						}
					}
				}
				value = Value(typeof (Gee.ArrayList));
				value.set_object(this.Functions);
				return true;
			}
			case "UnicodeAliases": {
				this.UnicodeAliases = Base.deserialize_string_list(property_node);
				value = Value(typeof (Gee.ArrayList));
				value.set_object(this.UnicodeAliases);
				return true;
			}
			default:
				return default_deserialize_property(property_name, out value, pspec, property_node);
			}
		}
	}
}