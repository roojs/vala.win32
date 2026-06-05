/* Track B: Win32 ergonomic controls — gobject profile, signals + properties. */

using GLib;

public static int main(string[] args) {
	var SCROLL_MAX = 100;

	var frame = new Win32.Window(
		"ValaWin32Ergo",
		"vala.win32 ergo",
		360, // width
		480  // height
	);
	if (frame.handle == null) {
		return 1;
	}

	new Win32.Label(frame, 20, 16, 48, 20, "Name:");

	var name_edit = new Win32.Edit(
		frame,
		72,      // x
		12,      // y
		260,     // width
		24       // height
	);
	name_edit.text = "Hello, Edit";
	if (name_edit.handle == null) {
		return 1;
	}

	var click_btn = new Win32.Button(
		frame,
		20,          // x
		44,          // y
		120,         // width
		32,          // height
		"Click me"   // label
	);
	if (click_btn.handle == null) {
		return 1;
	}

	new Win32.Label(frame, 20, 84, 40, 20, "List:");

	var color_list = new Win32.ListBox(
		frame,
		20,      // x
		104,     // y
		320,     // width
		80       // height
	);
	if (color_list.handle == null) {
		return 1;
	}
	color_list.add_item("Red");
	color_list.add_item("Green");
	color_list.add_item("Blue");
	color_list.selected_index = 0;

	new Win32.Label(frame, 20, 192, 40, 20, "Pick:");

	var size_combo = new Win32.ComboBox(
		frame,
		20,       // x
		212,      // y
		320,      // width
		100       // height(dropdown room)
	);
	if (size_combo.handle == null) {
		return 1;
	}
	size_combo.add_item("Small");
	size_combo.add_item("Medium");
	size_combo.add_item("Large");
	size_combo.selected_index = 0;

	new Win32.Label(frame, 20, 320, 56, 20, "Scroll:");

	var scroll_bar = new Win32.ScrollBar(
		frame,
		20,        // x
		344,       // y
		320,       // width
		24,        // height
		0,
		SCROLL_MAX,
		50
	);
	if (scroll_bar.handle == null) {
		return 1;
	}

	new Win32.Label(frame, 20, 376, 72, 20, "Progress:");

	var progress = new Win32.ProgressBar(
		frame,
		20,   // x
		400,  // y
		320,  // width
		20,   // height
		SCROLL_MAX
	);
	if (progress.handle == null) {
		return 1;
	}
	progress.value = scroll_bar.value;

	if (Environment.get_variable("WIN32_WIDGET_DEBUG") != null) {
		stderr.printf("WIN32_WIDGET_DEBUG: tracing WM_COMMAND / WM_HSCROLL on stderr\n");
		Win32.WidgetDispatch.debug_dump_registry();
	}

	click_btn.clicked.connect(() => {
		frame.title = name_edit.text;
	});

	color_list.selection_changed.connect(() => {
		frame.title = color_list.selected_text;
	});

	size_combo.selection_changed.connect(() => {
		frame.title = size_combo.selected_text;
	});

	scroll_bar.value_changed.connect(() => {
		progress.value = scroll_bar.value;
	});

	return frame.run();
}
