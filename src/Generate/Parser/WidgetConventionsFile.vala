/*
 * Root of metadata/widget-conventions.json.
 */

namespace Generate.Parse {
	public class WidgetConventionsFile : Base {
		public Gee.HashMap<string, string> class_name_overrides { get; set; }
		public Gee.HashMap<string, WidgetBehaviorProfileSpec> profiles { get; set; }

		public WidgetConventionsFile () {
			this.class_name_overrides = new Gee.HashMap<string, string> ();
			this.profiles = new Gee.HashMap<string, WidgetBehaviorProfileSpec> ();
		}

		public static WidgetConventionsFile load_from_file (string path) throws GLib.Error {
			var parser = new Json.Parser ();
			parser.load_from_file (path);
			var node = parser.get_root ();
			if (node == null || node.get_node_type () != Json.NodeType.OBJECT) {
				throw new GLib.IOError.FAILED ("widget conventions %s: root must be object", path);
			}
			var doc = Json.gobject_deserialize (typeof (WidgetConventionsFile), node) as WidgetConventionsFile;
			if (doc == null) {
				throw new GLib.IOError.FAILED ("widget conventions %s: deserialize failed", path);
			}
			return doc;
		}

		public override bool deserialize_property (
			string property_name,
			out Value value,
			ParamSpec pspec,
			Json.Node property_node
		) {
			switch (property_name) {
			case "class_name_overrides":
			case "class-name-overrides":
				this.class_name_overrides = new Gee.HashMap<string, string> ();
				if (property_node.get_node_type () == Json.NodeType.OBJECT) {
					var obj = property_node.get_object ();
					foreach (var wc in obj.get_members ()) {
						this.class_name_overrides[wc] = obj.get_string_member (wc);
					}
				}
				value = new Value (typeof (Gee.HashMap));
				value.set_object (this.class_name_overrides);
				return true;
			case "profiles":
				this.profiles = new Gee.HashMap<string, WidgetBehaviorProfileSpec> ();
				if (property_node.get_node_type () == Json.NodeType.OBJECT) {
					var obj = property_node.get_object ();
					foreach (var wc in obj.get_members ()) {
						var pnode = obj.get_member (wc);
						var spec = Json.gobject_deserialize (
							typeof (WidgetBehaviorProfileSpec),
							pnode
						) as WidgetBehaviorProfileSpec;
						if (spec != null) {
							this.profiles[wc] = spec;
						}
					}
				}
				value = new Value (typeof (Gee.HashMap));
				value.set_object (this.profiles);
				return true;
			default:
				return default_deserialize_property (property_name, out value, pspec, property_node);
			}
		}
	}
}
