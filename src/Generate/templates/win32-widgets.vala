/* Track B widget template — edited here; regen writes generated/win32-widgets.vala */

using GLib;
using Win32.System;
using Win32.Ui;
using Win32.Ui.Controls;
using Win32.Ui.Controls.Dialogs;
using Win32.Ui.WindowsAndMessaging;

namespace Win32 {

const int ITEM_TEXT_MAX = 256;
const int LBS_NOTIFY = 0x0001;
const uint PBM_SETPOS = 0x0402;
const uint PBM_GETPOS = 0x0408;
const uint PBM_SETRANGE32 = 0x0406;
const uint PBS_SMOOTH = 0x0001;

private int64 makelparam_uint (uint lo, uint hi) {
	return (int64) (lo | (hi << 16));
}

/* Set WIN32_WIDGET_DEBUG=1 (or true) to trace WM_COMMAND on stderr. */
private bool widget_debug_enabled () {
	unowned string? v = Environment.get_variable ("WIN32_WIDGET_DEBUG");
	return v != null && v != "" && v != "0";
}

private int64 widget_window_proc (
	[CCode (type_id = "HWND")] void* h_wnd,
	uint msg,
	ulong w_param,
	int64 l_param
) {
	if (widget_debug_enabled () && (msg == WM_COMMAND || msg == WM_NOTIFY || msg == WM_HSCROLL || msg == WM_VSCROLL)) {
		stderr.printf (
			"wndproc msg=0x%04x wParam=0x%llx lParam=0x%llx\n",
			msg, (ulong) w_param, (ulong) l_param
		);
	}
	if (msg == WM_COMMAND) {
		if (wm_command_dispatch (w_param)) {
			return 0;
		}
		if (widget_debug_enabled ()) {
			stderr.printf ("WM_COMMAND not handled (see dispatch log)\n");
		}
	}
	int64 scroll_result;
	if (WidgetDispatch.try_wm_hscroll (h_wnd, msg, w_param, l_param, out scroll_result)) {
		return scroll_result;
	}
	if (msg == WM_DESTROY) {
		post_quit_message (0);
		return 0;
	}
	return def_window_proc (h_wnd, msg, w_param, l_param);
}

public class WidgetDispatch {
	public static bool try_wm_command (ulong w_param) {
		return wm_command_dispatch (w_param);
	}

	/* ScrollBar: call def_window_proc, then emit value_changed when l_param is a registered HWND. */
	public static bool try_wm_hscroll (
		void* parent_wnd,
		uint msg,
		ulong w_param,
		int64 l_param,
		out int64 proc_result
	) {
		proc_result = 0;
		if (msg != WM_HSCROLL && msg != WM_VSCROLL) {
			return false;
		}
		var scroll_hwnd = (void*) l_param;
		var idx = wm_scroll_find_handle (scroll_hwnd);
		if (idx < 0) {
			return false;
		}
		if (widget_debug_enabled ()) {
			stderr.printf (
				"WM_SCROLL hwnd=%p (SB_THUMBTRACK=%u SB_ENDSCROLL=%u)\n",
				scroll_hwnd, SB_THUMBTRACK, SB_ENDSCROLL
			);
		}
		proc_result = def_window_proc (parent_wnd, msg, w_param, l_param);
		if (widget_debug_enabled ()) {
			stderr.printf ("  -> ScrollBar.value_changed hwnd=%p\n", scroll_hwnd);
		}
		wm_scroll_bars[idx].value_changed ();
		return true;
	}

	public static void debug_dump_registry () {
		if (!widget_debug_enabled ()) {
			return;
		}
		stderr.printf ("WM_COMMAND registry (%d entries):\n", wm_command_count);
		for (int i = 0; i < wm_command_count; i++) {
			stderr.printf (
				"  [%d] id=%d kind=%d\n",
				i, wm_command_entries[i].control_id, (int) wm_command_entries[i].kind
			);
		}
		stderr.printf ("WM_SCROLL registry (%d scrollbars):\n", wm_scroll_count);
		for (int i = 0; i < wm_scroll_count; i++) {
			stderr.printf ("  [%d] hwnd=%p\n", i, wm_scroll_handles[i]);
		}
	}
}

private enum WmCommandKind { BUTTON, EDIT, LISTBOX, COMBOBOX, MENU }

/* Plain struct (no GObject refs) — Vala would GBox-copy an array of boxed structs and
 * discard updates when register helpers free the duplicate from registry_get (). */
private struct WmCommandEntry {
	public int control_id;
	public WmCommandKind kind;
}

private int wm_command_count = 0;
private WmCommandEntry[]? wm_command_entries = null;
private Button?[]? wm_command_buttons = null;
private Edit?[]? wm_command_edits = null;
private ListBox?[]? wm_command_list_boxes = null;
private ComboBox?[]? wm_command_combo_boxes = null;
private MenuBar?[]? wm_command_menu_bars = null;

private int wm_scroll_count = 0;
private void*[]? wm_scroll_handles = null;
private ScrollBar?[]? wm_scroll_bars = null;

private void wm_scroll_registry_ensure () {
	if (wm_scroll_handles == null) {
		wm_scroll_handles = new void*[64];
		wm_scroll_bars = new ScrollBar[64];
	}
}

private int wm_scroll_find_handle (void* hwnd) {
	for (int i = 0; i < wm_scroll_count; i++) {
		if (wm_scroll_handles[i] == hwnd) {
			return i;
		}
	}
	return -1;
}

private void wm_scroll_register (ScrollBar scroll_bar) {
	wm_scroll_registry_ensure ();
	var hwnd = scroll_bar.handle;
	for (int i = 0; i < wm_scroll_count; i++) {
		if (wm_scroll_handles[i] == hwnd) {
			wm_scroll_bars[i] = scroll_bar;
			return;
		}
	}
	wm_scroll_handles[wm_scroll_count] = hwnd;
	wm_scroll_bars[wm_scroll_count] = scroll_bar;
	wm_scroll_count++;
}

private void wm_command_registry_ensure () {
	if (wm_command_entries == null) {
		wm_command_entries = new WmCommandEntry[64];
		wm_command_buttons = new Button[64];
		wm_command_edits = new Edit[64];
		wm_command_list_boxes = new ListBox[64];
		wm_command_combo_boxes = new ComboBox[64];
		wm_command_menu_bars = new MenuBar[64];
	}
}

private int wm_command_find (int control_id) {
	for (int i = 0; i < wm_command_count; i++) {
		if (wm_command_entries[i].control_id == control_id) {
			return i;
		}
	}
	return -1;
}

private int wm_command_slot (int control_id) {
	wm_command_registry_ensure ();
	var idx = wm_command_find (control_id);
	if (idx < 0) {
		idx = wm_command_count++;
		wm_command_entries[idx].control_id = control_id;
	}
	return idx;
}

private void wm_command_register_button (Button button) {
	var idx = wm_command_slot (button.control_id);
	wm_command_entries[idx].kind = WmCommandKind.BUTTON;
	wm_command_buttons[idx] = button;
}

private void wm_command_register_edit (Edit edit) {
	var idx = wm_command_slot (edit.control_id);
	wm_command_entries[idx].kind = WmCommandKind.EDIT;
	wm_command_edits[idx] = edit;
}

private void wm_command_register_list_box (ListBox list_box) {
	var idx = wm_command_slot (list_box.control_id);
	wm_command_entries[idx].kind = WmCommandKind.LISTBOX;
	wm_command_list_boxes[idx] = list_box;
}

private void wm_command_register_combo_box (ComboBox combo_box) {
	var idx = wm_command_slot (combo_box.control_id);
	wm_command_entries[idx].kind = WmCommandKind.COMBOBOX;
	wm_command_combo_boxes[idx] = combo_box;
}

private void wm_command_register_menu (MenuBar bar, int menu_id) {
	var idx = wm_command_slot (menu_id);
	wm_command_entries[idx].kind = WmCommandKind.MENU;
	wm_command_menu_bars[idx] = bar;
}

private string list_box_item_text (void* hwnd, int index) {
	if (hwnd == null || index < 0) {
		return "";
	}
	var buf = new uint16[ITEM_TEXT_MAX];
	send_message (hwnd, LB_GETTEXT, (ulong) index, (int64) buf);
	return utf16_buffer_to_string (buf);
}

private string combo_box_item_text (void* hwnd, int index) {
	if (hwnd == null || index < 0) {
		return "";
	}
	var buf = new uint16[ITEM_TEXT_MAX];
	send_message (hwnd, CB_GETLBTEXT, (ulong) index, (int64) buf);
	return utf16_buffer_to_string (buf);
}

private bool wm_command_dispatch (ulong w_param) {
	var control_id = (int) loword (w_param);
	var notify = hiword (w_param);
	if (widget_debug_enabled ()) {
		stderr.printf (
			"WM_COMMAND id=%d notify=%u (BN_CLICKED=%u LBN_SELCHANGE=%u CBN_SELCHANGE=%u)\n",
			control_id, notify, BN_CLICKED, LBN_SELCHANGE, CBN_SELCHANGE
		);
	}
	var idx = wm_command_find (control_id);
	if (idx < 0) {
		if (widget_debug_enabled ()) {
			stderr.printf ("  -> no registry match for id=%d\n", control_id);
		}
		return false;
	}
	var entry = wm_command_entries[idx];
	switch (entry.kind) {
	case WmCommandKind.BUTTON:
		if (notify == BN_CLICKED) {
			if (widget_debug_enabled ()) {
				stderr.printf ("  -> Button.clicked id=%d\n", control_id);
			}
			wm_command_buttons[idx].clicked ();
			return true;
		}
		if (widget_debug_enabled ()) {
			stderr.printf ("  -> button id=%d notify mismatch\n", control_id);
		}
		break;
	case WmCommandKind.EDIT:
		if (notify == EN_CHANGE) {
			if (widget_debug_enabled ()) {
				stderr.printf ("  -> Edit.changed id=%d\n", control_id);
			}
			wm_command_edits[idx].changed ();
			return true;
		}
		break;
	case WmCommandKind.LISTBOX:
		if (notify == LBN_SELCHANGE) {
			if (widget_debug_enabled ()) {
				stderr.printf ("  -> ListBox.selection_changed id=%d\n", control_id);
			}
			wm_command_list_boxes[idx].selection_changed ();
			return true;
		}
		break;
	case WmCommandKind.COMBOBOX:
		if (notify == CBN_SELCHANGE) {
			if (widget_debug_enabled ()) {
				stderr.printf ("  -> ComboBox.selection_changed id=%d\n", control_id);
			}
			wm_command_combo_boxes[idx].selection_changed ();
			return true;
		}
		break;
	case WmCommandKind.MENU:
		if (widget_debug_enabled ()) {
			stderr.printf ("  -> MenuBar.activated id=%d\n", control_id);
		}
		wm_command_menu_bars[idx].activated (control_id);
		return true;
	}
	return false;
}

public class Window {
	public void* handle { get; private set; }
	public void* instance { get; private set; }
	WideString _class_name;

	public Window (
		string class_name,
		string window_title,
		int width,
		int height,
		bool default_arrow_cursor = false
	) {
		instance = get_module_handle (null);
		_class_name = WideString (class_name);
		var wide_class = _class_name.ptr;

		var wc = WndClassEx ();
		wc.cbSize = (uint) sizeof (WndClassEx);
		wc.lpfnWndProc = widget_window_proc;
		wc.hInstance = instance;
		wc.hbrBackground = (void*) (SysColorIndex.COLOR_WINDOW + 1);
		wc.lpszClassName = wide_class;
		if (default_arrow_cursor) {
			wc.hCursor = load_cursor (null, (uint16*) (ulong) IDC_ARROW);
		}

		if (register_class_ex (ref wc) == 0) {
			stderr.printf ("RegisterClassExW failed\n");
			return;
		}

		handle = create_window_ex (
			0, wide_class, null,
			WindowStyle.WS_OVERLAPPEDWINDOW | WindowStyle.WS_VISIBLE,
			CW_USEDEFAULT, CW_USEDEFAULT, width, height,
			null, null, instance, null
		);
		if (handle != null) {
			window_text_set (handle, window_title);
		}
		if (widget_debug_enabled ()) {
			stderr.printf ("Window handle=%p class=%s\n", handle, class_name);
		}
	}

	public int run () {
		Msg msg;
		while (get_message (out msg, null, 0, 0) > 0) {
			translate_message (ref msg);
			dispatch_message (ref msg);
		}
		return 0;
	}

	public string title {
		owned get { return window_text_get (handle); }
		set { window_text_set (handle, value); }
	}

	public void close () {
		if (handle != null) {
			destroy_window (handle);
		}
	}

	/** Modal message box owned by this window (hand baseline — Phase 5+ may emit). */
	public MESSAGEBOXRESULT show_message (
		string text,
		string caption,
		MESSAGEBOXSTYLE style = MESSAGEBOXSTYLE.MB_OK | MESSAGEBOXSTYLE.MB_ICONINFORMATION
	) {
		return NativeDialogs.show_message (this, text, caption, style);
	}
}

/* IDC_ARROW — not emitted as vapi const yet (see menu-demo Track A). */
const int IDC_ARROW = 32512;

/**
 * Hand-maintained Phase 4 baseline: common dialogs. Compare to generator emit in Phase 5+.
 */
public class NativeDialogs {
	const int FILE_BUF_CHARS = 260;

	public static MESSAGEBOXRESULT show_message (
		Window? parent,
		string text,
		string caption,
		MESSAGEBOXSTYLE style
	) {
		return message_box (
			parent != null ? parent.handle : null,
			WideString (text).ptr,
			WideString (caption).ptr,
			(uint) style
		);
	}

	public static bool try_open_file (Window parent, out string path) {
		var file_buf = new uint16[FILE_BUF_CHARS];
		var filter = WideString ("Text (*.txt)\0*.txt\0All (*.*)\0*.*\0");
		var ofn = OPENFILENAME ();
		ofn.lStructSize = (uint) sizeof (OPENFILENAME);
		ofn.hwndOwner = parent.handle;
		ofn.lpstrFilter = filter.ptr;
		ofn.nFilterIndex = 1;
		ofn.lpstrFile = file_buf;
		ofn.nMaxFile = FILE_BUF_CHARS;
		ofn.Flags = (
			OPENFILENAMEFLAGS.OFN_PATHMUSTEXIST |
			OPENFILENAMEFLAGS.OFN_FILEMUSTEXIST |
			OPENFILENAMEFLAGS.OFN_EXPLORER
		);
		if (get_open_file_name (ref ofn) != 0) {
			path = (string) file_buf;
			return true;
		}
		path = "";
		return false;
	}

	public static bool try_choose_color (Window parent, ref uint rgb) {
		var cc = CHOOSECOLOR ();
		cc.lStructSize = (uint) sizeof (CHOOSECOLOR);
		cc.hwndOwner = parent.handle;
		cc.rgbResult = (void*) (&rgb);
		cc.Flags = CHOOSECOLORFLAGS.CC_RGBINIT | CHOOSECOLORFLAGS.CC_FULLOPEN;
		return choose_color (ref cc) != 0;
	}
}

/**
 * Hand-maintained Phase 4 baseline: menu bar + WM_COMMAND menu ids.
 */
public class MenuBar {
	public signal void activated (int menu_id);
	public Window parent { get; private set; }
	public void* handle { get; private set; }

	public MenuBar (Window parent) {
		this.parent = parent;
		handle = create_menu ();
	}

	public MenuPopup add_submenu (string label) {
		var popup = create_menu ();
		append_menu (
			handle,
			MENUITEMFLAGS.MF_POPUP | MENUITEMFLAGS.MF_STRING,
			popup,
			WideString (label).ptr
		);
		return new MenuPopup (this, popup);
	}

	public void attach () {
		set_menu (parent.handle, handle);
	}
}

public class MenuPopup {
	MenuBar bar;
	public void* handle { get; private set; }

	public MenuPopup (MenuBar bar, void* popup_handle) {
		this.bar = bar;
		handle = popup_handle;
	}

	public void add_item (int menu_id, string label) {
		append_menu (
			handle,
			MENUITEMFLAGS.MF_STRING,
			(void*) menu_id,
			WideString (label).ptr
		);
		wm_command_register_menu (bar, menu_id);
	}
}

public class Button {
	public signal void clicked ();
	public void* handle { get; private set; }
	public int control_id { get; private set; }

	public Button (
		Window parent,
		int x,
		int y,
		int width,
		int height,
		int control_id,
		string label
	) {
		this.control_id = control_id;
		uint style = (uint) (
			WindowStyle.WS_CHILD | WindowStyle.WS_VISIBLE |
			WindowStyle.WS_TABSTOP | BS_DEFPUSHBUTTON
		);
		handle = create_window_ex (
			0, WC_BUTTON, null, style,
			x, y, width, height,
			parent.handle, (void*) (intptr) control_id, parent.instance, null
		);
		if (handle != null) {
			window_text_set (handle, label);
		}
		wm_command_register_button (this);
	}
}

public class Label {
	public void* handle { get; private set; }

	public Label (
		Window parent,
		int x, int y, int width, int height, string text
	) {
		uint style = (uint) (WindowStyle.WS_CHILD | WindowStyle.WS_VISIBLE);
		handle = create_window_ex (
			0, WC_STATIC, null, style,
			x, y, width, height,
			parent.handle, null, parent.instance, null
		);
		if (handle != null) {
			window_text_set (handle, text);
		}
	}
}

public class Edit {
	public signal void changed ();
	public void* handle { get; private set; }
	public int control_id { get; private set; }

	public Edit (
		Window parent,
		int x, int y, int width, int height, int control_id
	) {
		this.control_id = control_id;
		uint style = (uint) (
			WindowStyle.WS_CHILD | WindowStyle.WS_VISIBLE |
			WindowStyle.WS_BORDER | WindowStyle.WS_TABSTOP | 0x0080
		);
		handle = create_window_ex (
			0, WC_EDIT, null, style,
			x, y, width, height,
			parent.handle, (void*) (intptr) control_id, parent.instance, null
		);
		wm_command_register_edit (this);
	}

	public string text {
		owned get { return window_text_get (handle); }
		set { window_text_set (handle, value); }
	}
}

public class ListBox {
	public signal void selection_changed ();
	public void* handle { get; private set; }
	public int control_id { get; private set; }

	public ListBox (
		Window parent,
		int x, int y, int width, int height, int control_id
	) {
		this.control_id = control_id;
		uint style = (uint) (
			WindowStyle.WS_CHILD | WindowStyle.WS_VISIBLE |
			WindowStyle.WS_BORDER | WindowStyle.WS_VSCROLL |
			WindowStyle.WS_TABSTOP | LBS_NOTIFY
		);
		handle = create_window_ex (
			0, WC_LISTBOX, null, style,
			x, y, width, height,
			parent.handle, (void*) (intptr) control_id, parent.instance, null
		);
		wm_command_register_list_box (this);
	}

	public void add_item (string text) {
		var wide = WideString (text);
		send_message (handle, LB_ADDSTRING, 0, (int64) wide.ptr);
	}

	public int selected_index {
		get { return (int) send_message (handle, LB_GETCURSEL, 0, 0); }
		set { send_message (handle, LB_SETCURSEL, (ulong) value, 0); }
	}

	public string selected_text {
		owned get { return list_box_item_text (handle, selected_index); }
	}
}

public class ComboBox {
	public signal void selection_changed ();
	public void* handle { get; private set; }
	public int control_id { get; private set; }

	public ComboBox (
		Window parent,
		int x, int y, int width, int height, int control_id
	) {
		this.control_id = control_id;
		uint style = (uint) (
			WindowStyle.WS_CHILD | WindowStyle.WS_VISIBLE |
			WindowStyle.WS_VSCROLL | WindowStyle.WS_TABSTOP |
			CBS_DROPDOWNLIST
		);
		handle = create_window_ex (
			0, WC_COMBOBOX, null, style,
			x, y, width, height,
			parent.handle, (void*) (intptr) control_id, parent.instance, null
		);
		wm_command_register_combo_box (this);
	}

	public void add_item (string text) {
		var wide = WideString (text);
		send_message (handle, CB_ADDSTRING, 0, (int64) wide.ptr);
	}

	public int selected_index {
		get { return (int) send_message (handle, CB_GETCURSEL, 0, 0); }
		set { send_message (handle, CB_SETCURSEL, (ulong) value, 0); }
	}

	public string selected_text {
		owned get { return combo_box_item_text (handle, selected_index); }
	}
}

public class ScrollBar {
	public signal void value_changed ();
	public void* handle { get; private set; }
	public int control_id { get; private set; }

	public ScrollBar (
		Window parent,
		int x,
		int y,
		int width,
		int height,
		int control_id,
		int range_min = 0,
		int range_max = 100,
		int initial_value = 0
	) {
		this.control_id = control_id;
		uint style = (uint) (
			WindowStyle.WS_CHILD | WindowStyle.WS_VISIBLE |
			WindowStyle.WS_TABSTOP | SBS_HORZ
		);
		handle = create_window_ex (
			0, WC_SCROLLBAR, null, style,
			x, y, width, height,
			parent.handle, (void*) (intptr) control_id, parent.instance, null
		);
		if (handle != null) {
			send_message (
				handle, SBM_SETRANGE, 0,
				makelparam_uint ((uint) range_min, (uint) range_max)
			);
			send_message (handle, SBM_SETPOS, 1, (ulong) initial_value);
		}
		wm_scroll_register (this);
	}

	public int value {
		get { return (int) send_message (handle, SBM_GETPOS, 0, 0); }
		set { send_message (handle, SBM_SETPOS, 1, (ulong) value); }
	}
}

public class ProgressBar {
	public void* handle { get; private set; }

	public ProgressBar (
		Window parent,
		int x,
		int y,
		int width,
		int height,
		int range_max = 100
	) {
		uint style = (uint) (
			WindowStyle.WS_CHILD | WindowStyle.WS_VISIBLE | PBS_SMOOTH
		);
		handle = create_window_ex (
			0, PROGRESS_CLASS, null, style,
			x, y, width, height,
			parent.handle, null, parent.instance, null
		);
		if (handle != null) {
			send_message (handle, PBM_SETRANGE32, 0, (int64) range_max);
		}
	}

	public int value {
		get { return (int) send_message (handle, PBM_GETPOS, 0, 0); }
		set { send_message (handle, PBM_SETPOS, (ulong) value, 0); }
	}

	public int range_max {
		set {
			send_message (handle, PBM_SETRANGE32, 0, (int64) value);
		}
	}
}

}
