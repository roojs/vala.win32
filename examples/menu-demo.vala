/* Track B / Phase 4c: MenuBar + signals (hand widget baseline). */

using GLib;

const int ID_FILE_HELLO = 300;
const int ID_FILE_EXIT = 301;

public static int main (string[] args) {
	var frame = new Win32.Window (
		"ValaErgoMenu",
		"vala.win32 menu-demo",
		480,
		320,
		true
	);
	if (frame.handle == null) {
		return 1;
	}

	var menu = new Win32.MenuBar (frame);
	var file = menu.add_submenu ("&File");
	file.add_item (ID_FILE_HELLO, "Say &hello");
	file.add_item (ID_FILE_EXIT, "E&xit");
	menu.attach ();

	menu.activated.connect ((id) => {
		if (id == ID_FILE_HELLO) {
			frame.show_message ("Hello from the menu.", "menu-demo");
		} else if (id == ID_FILE_EXIT) {
			frame.close ();
		}
	});

	return frame.run ();
}
