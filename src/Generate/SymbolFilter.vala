/*
 * gui.filter — symbol-level excludes(last matching line wins).
 */

namespace Generate {
	/**
	 * Loads metadata/filters/gui.filter and tests full metadata symbol names.
	 */
	public class SymbolFilter : Object {
		class Rule : Object {
			public string pattern { get; set; default = ""; }
			public bool include { get; set; default = true; }
		}

		Gee.ArrayList<Rule> rules = new Gee.ArrayList<Rule> ();

		/**
		 * @param path path to gui.filter
		 */
		public SymbolFilter.from_file(string path) throws GLib.Error {
			string contents;
			GLib.FileUtils.get_contents(path, out contents);
			foreach (var raw in contents.split("\n")) {
				var line = raw.strip();
				var hash = line.index_of("#");
				if (hash >= 0) {
					line = line.substring(0, hash).strip();
				}
				if (line.length == 0) {
					continue;
				}
				var inc = true;
				if (line.has_prefix("+")) {
					line = line.substring(1).strip();
				} else if (line.has_prefix("-")) {
					inc = false;
					line = line.substring(1).strip();
				}
				var rule = new Rule();
				rule.pattern = line;
				rule.include = inc;
				this.rules.add(rule);
			}
		}

		/**
		 * @param full_name e.g. Windows.Win32.UI.WindowsAndMessaging.CreateWindowExW
		 */
		public bool include_symbol(string full_name) {
			bool? verdict = null;
			foreach (var rule in this.rules) {
				if (SymbolFilter.glob_match(full_name, rule.pattern)) {
					verdict = rule.include;
				}
			}
			return verdict ?? true;
		}

		/**
		 * Shell-style glob: * and ? (not path-aware).
		 */
		public static bool glob_match(string text, string pattern) {
			var rx = "^" + SymbolFilter.glob_to_regex(pattern) + "$";
			try {
				var re = new GLib.Regex(rx, 0, 0);
				return re.match(text);
			} catch (GLib.RegexError e) {
				GLib.warning("bad filter pattern '%s': %s", pattern, e.message);
				return false;
			}
		}

		static string glob_to_regex(string glob) {
			var sb = new GLib.StringBuilder();
			for (int i = 0; i < glob.length; i++) {
				unichar c = glob.get_char(i);
				switch (c) {
				case '*':
					sb.append(".*");
					break;
				case '?':
					sb.append(".");
					break;
				case '.':
					sb.append("\\.");
					break;
				default:
					sb.append(Regex.escape_string(glob.substring(i, 1)));
					break;
				}
			}
			return sb.str;
		}
	}
}