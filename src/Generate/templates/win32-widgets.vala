/* Track B widget shell — dispatch, Window, dialogs, menus; control classes emitted at @TRACK_B_WIDGETS@ */

using GLib;
using Win32.Graphics.Gdi;
using Win32.System;
using Win32.Ui;
using Win32.Ui.Controls;
using Win32.Ui.Controls.Dialogs;
using Win32.Ui.WindowsAndMessaging;

namespace Win32 {

const int ITEM_TEXT_MAX = 256;

private const uint WM_SETFONT = 0x0030;

private void* _control_font_default;

private void* control_font_default () {
	if (_control_font_default == null) {
		_control_font_default = get_stock_object (GetSTOCKOBJECTFLAGS.DEFAULT_GUI_FONT);
	}
	return _control_font_default;
}

/**
 * Apply the OS default GUI font to a child HWND (including group boxes created outside widget classes).
 */
public class ControlFont {
	public static void apply_default ([CCode (type_id = "HWND")] void* hwnd) {
		if (hwnd != null) {
			send_message (hwnd, WM_SETFONT, (ulong) control_font_default (), 1);
		}
	}
}

private int window_registry_count = 0;
private void*[]? window_registry_handles = null;
private Window?[]? window_registry_windows = null;

private void window_registry_ensure () {
	if (window_registry_handles == null) {
		window_registry_handles = new void*[16];
		window_registry_windows = new Window[16];
	}
}

private void window_registry_add (Window window) {
	if (window.handle == null) {
		return;
	}
	window_registry_ensure ();
	for (int i = 0; i < window_registry_count; i++) {
		if (window_registry_handles[i] == window.handle) {
			window_registry_windows[i] = window;
			return;
		}
	}
	window_registry_handles[window_registry_count] = window.handle;
	window_registry_windows[window_registry_count] = window;
	window_registry_count++;
}

private bool window_destroy_dispatch (void* hwnd) {
	for (int i = 0; i < window_registry_count; i++) {
		if (window_registry_handles[i] == hwnd) {
			window_registry_windows[i].destroyed ();
			return true;
		}
	}
	return false;
}

private bool window_size_dispatch (void* hwnd, uint width, uint height) {
	for (int i = 0; i < window_registry_count; i++) {
		if (window_registry_handles[i] == hwnd) {
			window_registry_windows[i].resized (width, height);
			return true;
		}
	}
	return false;
}

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
	if (msg == WM_NOTIFY) {
		if (wm_notify_dispatch (l_param)) {
			return 0;
		}
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
	if (msg == WM_SIZE) {
		var width = (uint) (l_param & 0xffff);
		var height = (uint) ((l_param >> 16) & 0xffff);
		window_size_dispatch (h_wnd, width, height);
	}
	if (msg == WM_DESTROY) {
		window_destroy_dispatch (h_wnd);
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

/* InitCommonControlsEx — commctrl.h (not pulled in via win32-ui-controls.vapi C header). */
[CCode (cheader_filename = "commctrl.h")]
struct CommonControlsInit {
	public uint dwSize;
	public uint dwICC;
}

[CCode (cheader_filename = "commctrl.h", cname = "InitCommonControlsEx")]
extern int init_common_controls_ex_native (void* picce);

const uint ICC_LISTVIEW_CLASSES_MASK = 1;
const uint ICC_TREEVIEW_CLASSES_MASK = 2;
const uint ICC_BAR_CLASSES_MASK = 4;
const uint ICC_TAB_CLASSES_MASK = 8;
const uint ICC_PROGRESS_CLASS_MASK = 32;
const uint ICC_DATE_CLASSES_MASK = 256;

/* Commctrl WM_NOTIFY codes (not in win32json as named constants). */
const uint LVN_ITEMCHANGED = 0xFFFFFF9Bu;
const uint TVN_SELCHANGED = 0xFFFFFF0Du;
const uint TCN_SELCHANGE = 0xFFFFFDD5u;

private static bool common_controls_inited = false;

private void ensure_common_controls () {
	if (common_controls_inited) {
		return;
	}
	var icce = CommonControlsInit ();
	icce.dwSize = (uint) sizeof (CommonControlsInit);
	icce.dwICC = (
		ICC_LISTVIEW_CLASSES_MASK |
		ICC_TREEVIEW_CLASSES_MASK |
		ICC_TAB_CLASSES_MASK |
		ICC_BAR_CLASSES_MASK |
		ICC_DATE_CLASSES_MASK |
		ICC_PROGRESS_CLASS_MASK
	);
	init_common_controls_ex_native (&icce);
	common_controls_inited = true;
}

private enum WmNotifyKind { LISTVIEW, TREEVIEW, TABCONTROL }

private int wm_notify_count = 0;
private void*[]? wm_notify_hwnds = null;
private WmNotifyKind[]? wm_notify_kinds = null;
private ListView?[]? wm_notify_list_views = null;
private TreeView?[]? wm_notify_tree_views = null;
private TabControl?[]? wm_notify_tab_controls = null;

private void wm_notify_registry_ensure () {
	if (wm_notify_hwnds == null) {
		wm_notify_hwnds = new void*[64];
		wm_notify_kinds = new WmNotifyKind[64];
		wm_notify_list_views = new ListView[64];
		wm_notify_tree_views = new TreeView[64];
		wm_notify_tab_controls = new TabControl[64];
	}
}

private int wm_notify_find_hwnd (void* hwnd) {
	for (int i = 0; i < wm_notify_count; i++) {
		if (wm_notify_hwnds[i] == hwnd) {
			return i;
		}
	}
	return -1;
}

private void wm_notify_register (void* hwnd, WmNotifyKind kind) {
	wm_notify_registry_ensure ();
	for (int i = 0; i < wm_notify_count; i++) {
		if (wm_notify_hwnds[i] == hwnd) {
			wm_notify_kinds[i] = kind;
			return;
		}
	}
	wm_notify_hwnds[wm_notify_count] = hwnd;
	wm_notify_kinds[wm_notify_count] = kind;
	wm_notify_count++;
}

private void wm_notify_register_list_view (ListView list_view) {
	if (list_view.handle == null) {
		return;
	}
	wm_notify_register (list_view.handle, WmNotifyKind.LISTVIEW);
	var idx = wm_notify_find_hwnd (list_view.handle);
	if (idx >= 0) {
		wm_notify_list_views[idx] = list_view;
	}
}

private void wm_notify_register_tree_view (TreeView tree_view) {
	if (tree_view.handle == null) {
		return;
	}
	wm_notify_register (tree_view.handle, WmNotifyKind.TREEVIEW);
	var idx = wm_notify_find_hwnd (tree_view.handle);
	if (idx >= 0) {
		wm_notify_tree_views[idx] = tree_view;
	}
}

private void wm_notify_register_tab_control (TabControl tab_control) {
	if (tab_control.handle == null) {
		return;
	}
	wm_notify_register (tab_control.handle, WmNotifyKind.TABCONTROL);
	var idx = wm_notify_find_hwnd (tab_control.handle);
	if (idx >= 0) {
		wm_notify_tab_controls[idx] = tab_control;
	}
}

private bool wm_notify_dispatch (int64 l_param) {
	var hdr = (NMHDR*) l_param;
	if (hdr == null) {
		return false;
	}
	var idx = wm_notify_find_hwnd (hdr.hwndFrom);
	if (idx < 0) {
		return false;
	}
	var code = hdr.code;
	if (widget_debug_enabled ()) {
		stderr.printf (
			"WM_NOTIFY hwnd=%p code=0x%08x kind=%d\n",
			hdr.hwndFrom, code, (int) wm_notify_kinds[idx]
		);
	}
	switch (wm_notify_kinds[idx]) {
	case WmNotifyKind.LISTVIEW:
		if (code == LVN_ITEMCHANGED) {
			wm_notify_list_views[idx].selection_changed ();
			return true;
		}
		break;
	case WmNotifyKind.TREEVIEW:
		if (code == TVN_SELCHANGED) {
			wm_notify_tree_views[idx].selection_changed ();
			return true;
		}
		break;
	case WmNotifyKind.TABCONTROL:
		if (code == TCN_SELCHANGE) {
			wm_notify_tab_controls[idx].selection_changed ();
			return true;
		}
		break;
	}
	return false;
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
	/** Fired when this window receives WM_DESTROY (before the demo message loop exits). */
	public signal void destroyed ();
	/** Fired on WM_SIZE with the new client-area size in pixels. */
	public signal void resized (uint width, uint height);
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
		window_registry_add (this);
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

/**
 * Layout group (WC_BUTTON + BS_GROUPBOX). Decorative frame only — no command signal.
 */
public class GroupBox {
	public void* handle { get; private set; }

	public GroupBox (
		Window parent,
		int x, int y, int width, int height,
		string title
	) {
		uint style = (uint) (
			WindowStyle.WS_CHILD | WindowStyle.WS_VISIBLE | BS_GROUPBOX
		);
		handle = create_window_ex (
			0, WC_BUTTON, WideString (title).ptr, style,
			x, y, width, height,
			parent.handle, null, parent.instance, null
		);
		ControlFont.apply_default (handle);
	}
}

/* @TRACK_B_WIDGETS@ */

}
