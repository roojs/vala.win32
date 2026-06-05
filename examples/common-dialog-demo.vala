/* Track B / Phase 4b: common dialogs via NativeDialogs + Win32.Button (hand baseline). */

using GLib;

const int ID_OPEN = 200;
const int ID_COLOR = 201;

public static int main (string[] args) {
	var frame = new Win32.Window (
		"ValaErgoCommonDialog",
		"vala.win32 common-dialog-demo",
		400,
		220
	);
	if (frame.handle == null) {
		return 1;
	}

	var open_btn = new Win32.Button (frame, 20, 20, 140, 28, ID_OPEN, "Open file…");
	var color_btn = new Win32.Button (frame, 20, 56, 140, 28, ID_COLOR, "Choose color…");
	if (open_btn.handle == null || color_btn.handle == null) {
		return 1;
	}

	open_btn.clicked.connect (() => {
		string path;
		if (Win32.NativeDialogs.try_open_file (frame, out path)) {
			frame.title = path;
		} else {
			frame.title = "(open cancelled)";
		}
	});

	color_btn.clicked.connect (() => {
		uint rgb = 0x000000ff;
		if (Win32.NativeDialogs.try_choose_color (frame, ref rgb)) {
			frame.title = "Color 0x%06x".printf (rgb & 0xffffff);
		} else {
			frame.title = "(color cancelled)";
		}
	});

	return frame.run ();
}
