/*
 * Load metadata/win32json-api.files — which JSON blobs to generate.
 */

namespace Generate {

	public class ApiFileList : Object {
		/**
		 * Read basenames(one per line) from e.g. metadata/win32json-api.files.
		 *
		 * @param path list file path
		 */
		public static Gee.ArrayList<string> load_basenames(string path) throws GLib.Error {
			var list = new Gee.ArrayList<string> ();
			string contents;
			GLib.FileUtils.get_contents(path, out contents);
			foreach (var raw in contents.split("\n")) {
				var line = raw.strip();
				if (line.length == 0 || line.has_prefix("#")) {
					continue;
				}
				if (!line.has_suffix(".json")) {
					line = line + ".json";
				}
				list.add(line);
			}
			return list;
		}

		/**
		 * Load ApiFileEntry list for all basenames in the list file.
		 *
		 * @param api_dir metadata/win32json/api
		 * @param list_path metadata/win32json-api.files
		 */
		public static Gee.ArrayList<Parse.ApiFileEntry> load_entries(
			string api_dir,
			string list_path
		) throws GLib.Error {
			var entries = new Gee.ArrayList<Parse.ApiFileEntry> ();
			foreach (var basename in ApiFileList.load_basenames(list_path)) {
				var path = GLib.Path.build_filename(api_dir, basename);
				if (!GLib.FileUtils.test(path, GLib.FileTest.EXISTS)) {
					throw new GLib.FileError.NOENT("missing %s(run ./scripts/vendor-win32json.sh)", path);
				}
				var doc = Parse.ApiFile.load_from_file(path);
				entries.add(new Parse.ApiFileEntry(basename, doc));
			}
			return entries;
		}
	}
}