/*
 * Win32 / metadata names → Vala identifiers for vapi emission.
 */

namespace Generate {
	/** Maps C / metadata names to Vala names and strips Ansi vs Unicode suffix policy. */
	public class NameMapper : Object {
		/**
		 * Function or constant: CreateWindowExW → create_window_ex.
		 *
		 * @param c_name metadata Name
		 */
		/**
		 * Win32 #define names (WM_DESTROY) keep spelling; others use snake_case.
		 */
		public static string to_constant_name (string c_name) {
			var s = c_name;
			if (s.has_suffix ("W") && s.length > 1) {
				s = s.substring (0, s.length - 1);
			}
			if (s == s.up ()) {
				return s;
			}
			return NameMapper.to_snake_function (c_name);
		}

		public static string to_snake_function (string c_name) {
			var s = c_name;
			if (s.has_suffix ("W") && s.length > 1) {
				s = s.substring (0, s.length - 1);
			}
			return NameMapper.to_snake (s);
		}

		/**
		 * Struct / delegate: WNDCLASSEXW → WndClassEx, WNDPROC → WndProc.
		 *
		 * @param c_name metadata type Name
		 */
		public static string to_vala_type (string c_name) {
			var s = c_name;
			if (s.has_suffix ("W") && s.length > 1) {
				s = s.substring (0, s.length - 1);
			}
			string? known = NameMapper.type_overrides ().get (s);
			if (known != null) {
				return known;
			}
			return NameMapper.to_pascal_words (s);
		}

		/**
		 * Field or parameter name: hInstance → h_instance.
		 *
		 * @param name metadata field name
		 */
		public static string to_snake (string name) {
			var sb = new GLib.StringBuilder ();
			var prev_lower = false;
			foreach (var i in NameMapper.indexes (name)) {
				unichar c = name.get_char (i);
				if (c == '_') {
					sb.append_c ('_');
					prev_lower = true;
					continue;
				}
				if (c >= 'A' && c <= 'Z') {
					if (sb.len > 0 && prev_lower) {
						sb.append_c ('_');
					}
					sb.append_c ((char) (c + ('a' - 'A')));
					prev_lower = false;
				} else {
					sb.append_c ((char) c);
					prev_lower = c >= 'a' && c <= 'z';
				}
			}
			return sb.str;
		}

		static string to_pascal_words (string name) {
			var parts = name.split ("_");
			var sb = new GLib.StringBuilder ();
			foreach (var part in parts) {
				if (part.length == 0) {
					continue;
				}
				sb.append (NameMapper.capitalize_token (part));
			}
			if (sb.len == 0) {
				return name;
			}
			return sb.str;
		}

		static string capitalize_token (string token) {
			if (token.length == 0) {
				return token;
			}
			if (token.length <= 3 && token == token.up () && token.index_of ("_") < 0) {
				var lower = token.down ();
				return lower.substring (0, 1).up () + lower.substring (1);
			}
			var sb = new GLib.StringBuilder ();
			var prev_lower = false;
			foreach (var i in NameMapper.indexes (token)) {
				unichar c = token.get_char (i);
				if (c >= 'A' && c <= 'Z') {
					if (sb.len > 0 && prev_lower) {
						sb.append (token.substring (i, 1));
					} else {
						sb.append_c ((char) c);
					}
					prev_lower = false;
				} else {
					sb.append_c ((char) c);
					prev_lower = true;
				}
			}
			return sb.str;
		}

		static int[] indexes (string s) {
			int[] result = {};
			for (int i = 0; i < s.length; i++) {
				result += i;
			}
			return result;
		}

		static Gee.HashMap<string, string> type_overrides () {
			var map = new Gee.HashMap<string, string> ();
			map["WNDCLASSEX"] = "WndClassEx";
			map["WNDPROC"] = "WndProc";
			map["MSG"] = "Msg";
			return map;
		}
	}
}
