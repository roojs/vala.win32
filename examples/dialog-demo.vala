/* Track B / Phase 4a: MessageBox via Win32.Window + NativeDialogs (hand widget baseline). */

using GLib;
using Win32.Ui.WindowsAndMessaging;

public static int main (string[] args) {
	var frame = new Win32.Window (
		"ValaErgoDialog",
		"vala.win32 dialog-demo",
		480,
		320
	);
	if (frame.handle == null) {
		return 1;
	}

	var result = frame.show_message (
		"MessageBoxW via Win32.Window API.",
		"Phase 4a (hand baseline)"
	);
	stderr.printf (
		"MessageBox returned %d (IDOK=%d)\n",
		(int) result,
		(int) MESSAGEBOXRESULT.IDOK
	);

	return frame.run ();
}
