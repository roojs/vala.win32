/*
 * Shared debug logging (same pattern as OLLMchat.ApplicationInterface).
 */

namespace Generate {

	private static GLib.FileStream? debug_log_file = null;
	private static bool debug_log_in_progress = false;

	public static bool debug_on = false;
	public static bool debug_critical_enabled = false;

	public interface ApplicationInterface : GLib.Object {
		public static void debug_log (
			string app_id,
			string? in_domain,
			GLib.LogLevelFlags level,
			string message
		) {
			if (debug_log_in_progress) {
				return;
			}

			var timestamp = (new GLib.DateTime.now_local ()).format ("%H:%M:%S.%f");

			bool should_output = debug_on || (level & GLib.LogLevelFlags.LEVEL_CRITICAL) != 0;

			if (should_output) {
				GLib.stderr.printf (
					timestamp + ": " + level.to_string () + " : "
						+ (in_domain == null ? "" : in_domain) + " : " + message + "\n"
				);
			}

			if ((level & GLib.LogLevelFlags.LEVEL_CRITICAL) != 0 && debug_critical_enabled) {
				GLib.error ("Critical warning: [" + (in_domain ?? "") + "] " + message);
			}

			debug_log_in_progress = true;

			if (debug_log_file == null) {
				var log_dir = GLib.Path.build_filename (
					GLib.Environment.get_home_dir (), ".cache", "vala.win32"
				);
				var log_file_path = GLib.Path.build_filename (log_dir, app_id + ".debug.log");

				var parts = log_dir.split ("/");
				var current_path = "";
				foreach (var part in parts) {
					if (part == "") {
						current_path = "/";
						continue;
					}
					if (current_path == "") {
						current_path = part;
					} else {
						current_path = current_path + "/" + part;
					}
					try {
						GLib.DirUtils.create (current_path, 0755);
					} catch (GLib.FileError e) {
						if (e.code != GLib.FileError.EXIST) {
						}
					}
				}

				debug_log_file = GLib.FileStream.open (log_file_path, "w");
				if (debug_log_file == null) {
					GLib.stderr.printf ("ERROR: FAILED TO OPEN DEBUG LOG FILE: Unable to open file stream\n");
					debug_log_in_progress = false;
					return;
				}
			}

			try {
				if (debug_log_file != null) {
					debug_log_file.puts (timestamp + ": " + level.to_string () + " : " + message + "\n");
					debug_log_file.flush ();
				}
			} catch (GLib.Error e) {
				GLib.stderr.printf ("ERROR: FAILED TO WRITE TO DEBUG LOG FILE: " + e.message + "\n");
			}
			debug_log_in_progress = false;
		}
	}
}
