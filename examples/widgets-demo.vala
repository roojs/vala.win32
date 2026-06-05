/* Track B showcase: widgets, signals, properties — no raw Win32 in application code. */

using GLib;

public static int main(string[] args) {
	var SCROLL_MAX = 100;
	var M = 20;
	var PAD = 14;
	var GROUP_Y = 76;
	var LEFT_W = 404;
	var RIGHT_X = 436;
	var RIGHT_W = 484;
	var STATUS_Y = 500;

	var frame = new Win32.Window(
		"ValaWin32ErgoWidgets",
		"vala.win32 — Track B widgets",
		960,
		580,
		true
	);
	if (frame.handle == null) {
		return 1;
	}

	new Win32.Label(frame, M, 16, 900, 22, "Track B widget showcase");
	new Win32.Label(frame, M, 40, 900, 20,
		"Signals and properties on native controls — layout via Win32.GroupBox and widget helpers.");

	int lx = M + PAD;
	int ly = GROUP_Y + 28;
	int left_inner_w = LEFT_W - PAD * 2;
	int rx = RIGHT_X + PAD;
	int ry = GROUP_Y + 28;
	int panel_w = RIGHT_W - PAD * 2;
	int list_h = 96;
	int tree_w = 188;
	int tree_h = 142;
	int cal_gap = 10;
	int cal_w = panel_w - tree_w - cal_gap;
	int row2_y = ry + list_h + 6;
	int tab_h = 50;
	int tab_y = row2_y + tree_h + 6;
	int footer_y = tab_y + tab_h + 6;

	int left_group_h = ly + 338 + 22 - GROUP_Y + 12;
	int right_group_h = footer_y + 28 - GROUP_Y + 12;

	new Win32.GroupBox(frame, M, GROUP_Y, LEFT_W, left_group_h, "User32 — WM_COMMAND");
	new Win32.GroupBox(frame, RIGHT_X, GROUP_Y, RIGHT_W, right_group_h, "Common Controls — WM_NOTIFY");

	new Win32.Label(frame, lx, ly, 48, 20, "Name");
	var name_edit = new Win32.Edit(frame, lx + 52, ly - 2, left_inner_w - 52, 26);
	name_edit.text = "Hello, Edit";

	var click_btn = new Win32.Button(frame, lx, ly + 34, 148, 32, "Click me");

	new Win32.Label(frame, lx, ly + 72, 40, 20, "List");
	var list_box = new Win32.ListBox(frame, lx, ly + 92, left_inner_w, 64);
	list_box.add_item("Red");
	list_box.add_item("Green");
	list_box.add_item("Blue");
	list_box.selected_index = 0;

	new Win32.Label(frame, lx, ly + 164, 40, 20, "Size");
	var combo = new Win32.ComboBox(frame, lx, ly + 184, left_inner_w, 72);
	combo.add_item("Small");
	combo.add_item("Medium");
	combo.add_item("Large");
	combo.selected_index = 0;

	new Win32.Label(frame, lx, ly + 262, 56, 20, "Scroll");
	var scroll = new Win32.ScrollBar(
		frame, lx, ly + 284, left_inner_w, 24, 0, SCROLL_MAX, 40
	);

	new Win32.Label(frame, lx, ly + 316, 72, 20, "Progress");
	var progress = new Win32.ProgressBar(frame, lx, ly + 338, left_inner_w, 22, SCROLL_MAX);
	progress.value = scroll.value;

	var list_view = new Win32.ListView(frame, rx, ry, panel_w, list_h);
	list_view.add_column("Item", 160);
	list_view.add_column("Note", 120);
	list_view.append_row("Alpha", "row 0");
	list_view.append_row("Beta", "row 1");
	list_view.append_row("Gamma", "row 2");

	var tree_view = new Win32.TreeView(frame, rx, row2_y, tree_w, tree_h);
	var projects = tree_view.add_root("Projects");
	tree_view.add_child(projects, "Track A — raw vapi");
	tree_view.add_child(projects, "Track B — widgets");
	var track_b = tree_view.add_child(projects, "Demos");
	tree_view.add_child(track_b, "hello-window");
	tree_view.add_child(track_b, "button-demo");
	tree_view.add_child(track_b, "widgets-demo");
	tree_view.add_child(track_b, "dialog-demo");
	var coverage = tree_view.add_root("Coverage");
	tree_view.add_child(coverage, "6a matrix");
	tree_view.add_child(coverage, "6b filter trials");
	tree_view.add_child(coverage, "6c WM_NOTIFY profiles");

	var month_cal = new Win32.MonthCalendar(
		frame, rx + tree_w + cal_gap, row2_y, cal_w, tree_h
	);

	var tab_control = new Win32.TabControl(frame, rx, tab_y, panel_w, tab_h);
	tab_control.add_page("Overview");
	tab_control.add_page("Details");
	tab_control.add_page("Log");

	var toolbar = new Win32.Toolbar(frame, rx, footer_y, panel_w - 236, 28);

	new Win32.Label(frame, rx + panel_w - 224, footer_y + 2, 40, 20, "Date");
	var date_pick = new Win32.DateTimePicker(
		frame, rx + panel_w - 180, footer_y, 180, 24
	);
	var tool_tips = new Win32.ToolTips(frame, rx + panel_w - 180, footer_y, 180, 24);

	var status = new Win32.Label(
		frame, M, STATUS_Y, LEFT_W + RIGHT_W + (RIGHT_X - M - LEFT_W), 28,
		"Ready — interact with any control"
	);

	if (Environment.get_variable("WIN32_WIDGET_DEBUG") != null) {
		stderr.printf("WIN32_WIDGET_DEBUG=1 — WM_COMMAND / WM_NOTIFY / WM_SCROLL on stderr\n");
		Win32.WidgetDispatch.debug_dump_registry();
	}

	click_btn.clicked.connect(() => {
		status.text = "Button.clicked → " + name_edit.text;
		frame.title = name_edit.text;
	});
	name_edit.changed.connect(() => {
		status.text = "Edit.changed";
	});
	list_box.selection_changed.connect(() => {
		status.text = "ListBox: " + list_box.selected_text;
	});
	combo.selection_changed.connect(() => {
		status.text = "ComboBox: " + combo.selected_text;
	});
	scroll.value_changed.connect(() => {
		progress.value = scroll.value;
		status.text = "ScrollBar: %d".printf(scroll.value);
	});
	list_view.selection_changed.connect(() => {
		status.text = "ListView.selection_changed";
	});
	tree_view.selection_changed.connect(() => {
		status.text = "TreeView.selection_changed";
	});
	tab_control.selection_changed.connect(() => {
		status.text = "TabControl.selection_changed";
	});

	if (toolbar.handle == null) {
		status.text = "Toolbar create failed(Wine?)";
	} else if (month_cal.handle == null) {
		status.text = "MonthCalendar create failed";
	} else if (date_pick.handle == null) {
		status.text = "DateTimePicker create failed";
	} else if (tool_tips.handle == null) {
		status.text = "Ready — ToolTips optional";
	}

	return frame.run();
}