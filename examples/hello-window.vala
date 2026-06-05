/* Track B: minimal top-level hello — ergonomic Win32.Window API. */

using GLib;

public static int main (string[] args) {
	var frame = new Win32.Window (
		"ValaWin32Hello",
		"vala.win32 hello",
		480,
		320
	);
	if (frame.handle == null) {
		return 1;
	}

	return frame.run ();
}
