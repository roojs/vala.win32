/* Track B: ergonomic WebView2 — Win32.Window + Win32.WebView (hand baseline for 7h). */

using GLib;

public static int main (string[] args) {
	var start_url = "https://example.com/";
	if (args.length > 1) {
		start_url = args[1];
	}

	var frame = new Win32.Window (
		"ValaWin32WebView2Ergo",
		"vala.win32 WebView2 (ergo)",
		1024,
		768,
		true
	);
	if (frame.handle == null) {
		return 1;
	}

	/* Same layout pattern as Button, Edit, … — position + size, then navigate. */
	var web = new Win32.WebView (frame, 0, 0, 1024, 768, true);
	web.navigate (start_url);
	web.navigation_completed.connect ((ok) => {
		stderr.printf ("WebView navigation_completed success=%s\n", ok ? "true" : "false");
	});

	return frame.run ();
}
