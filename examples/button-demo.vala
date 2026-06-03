/* Phase 3 Track A: common controls demo (Button through ProgressBar). */

using Win32.Ui.Controls;
using Win32.Ui.WindowsAndMessaging;
using Win32.System;

const int ID_CLICK_ME = 100;
const int ID_EDIT = 101;
const int ID_LIST = 102;
const int ID_COMBO = 103;
const int ID_SCROLL = 104;
const int TEXT_MAX = 256;
const int SCROLL_MAX = 100;
const uint PBM_SETPOS = 0x0402;
const uint PBM_SETRANGE32 = 0x0406;
const uint PBS_SMOOTH = 0x0001;

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] CLASS_NAME = {
	'V', 'a', 'l', 'a', 'C', 'o', 'n', 't', 'r', 'o', 'l', 's', 'D', 'e', 'm', 'o', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] WINDOW_TITLE = {
	'v', 'a', 'l', 'a', '.', 'w', 'i', 'n', '3', '2', ' ', 'c', 'o', 'n', 't', 'r', 'o', 'l', 's', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] BUTTON_LABEL = {
	'C', 'l', 'i', 'c', 'k', ' ', 'm', 'e', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] LABEL_NAME = {
	'N', 'a', 'm', 'e', ':', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] LABEL_LIST = {
	'L', 'i', 's', 't', ':', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] LABEL_PICK = {
	'P', 'i', 'c', 'k', ':', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] LABEL_SCROLL = {
	'S', 'c', 'r', 'o', 'l', 'l', ':', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] LABEL_PROGRESS = {
	'P', 'r', 'o', 'g', 'r', 'e', 's', 's', ':', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] EDIT_INITIAL = {
	'H', 'e', 'l', 'l', 'o', ',', ' ', 'E', 'd', 'i', 't', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] LIST_RED = { 'R', 'e', 'd', 0 };

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] LIST_GREEN = { 'G', 'r', 'e', 'e', 'n', 0 };

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] LIST_BLUE = { 'B', 'l', 'u', 'e', 0 };

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] COMBO_SMALL = { 'S', 'm', 'a', 'l', 'l', 0 };

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] COMBO_MEDIUM = { 'M', 'e', 'd', 'i', 'u', 'm', 0 };

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] COMBO_LARGE = { 'L', 'a', 'r', 'g', 'e', 0 };

private void* edit_hwnd = null;
private void* list_hwnd = null;
private void* combo_hwnd = null;
private void* scroll_hwnd = null;
private void* progress_hwnd = null;

private int64 makelparam (uint lo, uint hi) {
	return (int64) (lo | (hi << 16));
}

private void list_add (void* hwnd, uint16[] text) {
	send_message (hwnd, LB_ADDSTRING, 0, (int64) text);
}

private void combo_add (void* hwnd, uint16[] text) {
	send_message (hwnd, CB_ADDSTRING, 0, (int64) text);
}

private void set_title_from_list (void* frame) {
	if (list_hwnd == null) {
		return;
	}
	int index = (int) send_message (list_hwnd, LB_GETCURSEL, 0, 0);
	if (index < 0) {
		return;
	}
	var text = new uint16[TEXT_MAX];
	send_message (list_hwnd, LB_GETTEXT, (ulong) index, (int64) text);
	set_window_text (frame, text);
}

private void set_title_from_combo (void* frame) {
	if (combo_hwnd == null) {
		return;
	}
	int index = (int) send_message (combo_hwnd, CB_GETCURSEL, 0, 0);
	if (index < 0) {
		return;
	}
	var text = new uint16[TEXT_MAX];
	send_message (combo_hwnd, CB_GETLBTEXT, (ulong) index, (int64) text);
	set_window_text (frame, text);
}

private void sync_progress_from_scroll () {
	if (scroll_hwnd == null || progress_hwnd == null) {
		return;
	}
	int pos = (int) send_message (scroll_hwnd, SBM_GETPOS, 0, 0);
	send_message (progress_hwnd, PBM_SETPOS, (ulong) pos, 0);
}

private int64 window_proc (
	[CCode (type_id = "HWND")] void* h_wnd,
	uint msg,
	ulong w_param,
	int64 l_param
) {
	if (msg == WM_COMMAND) {
		var id = loword (w_param);
		var code = hiword (w_param);
		if (id == ID_CLICK_ME && code == BN_CLICKED) {
			if (edit_hwnd != null) {
				var text = new uint16[TEXT_MAX];
				get_window_text (edit_hwnd, text, TEXT_MAX);
				set_window_text (h_wnd, text);
			}
			return 0;
		}
		if (id == ID_LIST && code == LBN_SELCHANGE) {
			set_title_from_list (h_wnd);
			return 0;
		}
		if (id == ID_COMBO && code == CBN_SELCHANGE) {
			set_title_from_combo (h_wnd);
			return 0;
		}
	}
	if (msg == WM_HSCROLL && (void*) l_param == scroll_hwnd) {
		var result = def_window_proc (h_wnd, msg, w_param, l_param);
		sync_progress_from_scroll ();
		return result;
	}
	if (msg == WM_DESTROY) {
		post_quit_message (0);
		return 0;
	}
	return def_window_proc (h_wnd, msg, w_param, l_param);
}

public static int main (string[] args) {
	void* inst = get_module_handle (null);

	var wc = WndClassEx ();
	wc.cbSize = (uint) sizeof (WndClassEx);
	wc.lpfnWndProc = window_proc;
	wc.hInstance = inst;
	wc.hbrBackground = (void*) (SysColorIndex.COLOR_WINDOW + 1);
	wc.lpszClassName = CLASS_NAME;

	if (register_class_ex (ref wc) == 0) {
		stderr.printf ("RegisterClassExW failed\n");
		return 1;
	}

	void* hwnd = create_window_ex (
		0,
		CLASS_NAME,
		WINDOW_TITLE,
		WindowStyle.WS_OVERLAPPEDWINDOW | WindowStyle.WS_VISIBLE,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		360,
		480,
		null,
		null,
		inst,
		null
	);
	if (hwnd == null) {
		stderr.printf ("CreateWindowExW failed\n");
		return 1;
	}

	uint static_style = (uint) (WindowStyle.WS_CHILD | WindowStyle.WS_VISIBLE);

	void* name_label = create_window_ex (
		0,
		WC_STATIC,
		LABEL_NAME,
		static_style,
		20,
		16,
		48,
		20,
		hwnd,
		null,
		inst,
		null
	);
	if (name_label == null) {
		stderr.printf ("CreateWindowExW (static name) failed\n");
		return 1;
	}

	uint edit_style = (uint) (
		WindowStyle.WS_CHILD |
		WindowStyle.WS_VISIBLE |
		WindowStyle.WS_BORDER |
		WindowStyle.WS_TABSTOP |
		0x0080
	);

	edit_hwnd = create_window_ex (
		0,
		WC_EDIT,
		null,
		edit_style,
		72,
		12,
		260,
		24,
		hwnd,
		(void*) ID_EDIT,
		inst,
		null
	);
	if (edit_hwnd == null) {
		stderr.printf ("CreateWindowExW (edit) failed\n");
		return 1;
	}
	set_window_text (edit_hwnd, EDIT_INITIAL);

	uint btn_style = (uint) (
		WindowStyle.WS_CHILD |
		WindowStyle.WS_VISIBLE |
		WindowStyle.WS_TABSTOP |
		BS_DEFPUSHBUTTON
	);

	void* btn = create_window_ex (
		0,
		WC_BUTTON,
		BUTTON_LABEL,
		btn_style,
		20,
		44,
		120,
		32,
		hwnd,
		(void*) ID_CLICK_ME,
		inst,
		null
	);
	if (btn == null) {
		stderr.printf ("CreateWindowExW (button) failed\n");
		return 1;
	}

	void* list_label = create_window_ex (
		0,
		WC_STATIC,
		LABEL_LIST,
		static_style,
		20,
		84,
		40,
		20,
		hwnd,
		null,
		inst,
		null
	);
	if (list_label == null) {
		stderr.printf ("CreateWindowExW (static list) failed\n");
		return 1;
	}

	uint list_style = (uint) (
		WindowStyle.WS_CHILD |
		WindowStyle.WS_VISIBLE |
		WindowStyle.WS_BORDER |
		WindowStyle.WS_VSCROLL |
		WindowStyle.WS_TABSTOP |
		0x0001
	);

	list_hwnd = create_window_ex (
		0,
		WC_LISTBOX,
		null,
		list_style,
		20,
		104,
		320,
		80,
		hwnd,
		(void*) ID_LIST,
		inst,
		null
	);
	if (list_hwnd == null) {
		stderr.printf ("CreateWindowExW (listbox) failed\n");
		return 1;
	}
	list_add (list_hwnd, LIST_RED);
	list_add (list_hwnd, LIST_GREEN);
	list_add (list_hwnd, LIST_BLUE);
	send_message (list_hwnd, LB_SETCURSEL, 0, 0);

	void* pick_label = create_window_ex (
		0,
		WC_STATIC,
		LABEL_PICK,
		static_style,
		20,
		192,
		40,
		20,
		hwnd,
		null,
		inst,
		null
	);
	if (pick_label == null) {
		stderr.printf ("CreateWindowExW (static pick) failed\n");
		return 1;
	}

	uint combo_style = (uint) (
		WindowStyle.WS_CHILD |
		WindowStyle.WS_VISIBLE |
		WindowStyle.WS_VSCROLL |
		WindowStyle.WS_TABSTOP |
		CBS_DROPDOWNLIST
	);

	combo_hwnd = create_window_ex (
		0,
		WC_COMBOBOX,
		null,
		combo_style,
		20,
		212,
		320,
		100,
		hwnd,
		(void*) ID_COMBO,
		inst,
		null
	);
	if (combo_hwnd == null) {
		stderr.printf ("CreateWindowExW (combobox) failed\n");
		return 1;
	}
	combo_add (combo_hwnd, COMBO_SMALL);
	combo_add (combo_hwnd, COMBO_MEDIUM);
	combo_add (combo_hwnd, COMBO_LARGE);
	send_message (combo_hwnd, CB_SETCURSEL, 0, 0);

	void* scroll_label = create_window_ex (
		0,
		WC_STATIC,
		LABEL_SCROLL,
		static_style,
		20,
		320,
		56,
		20,
		hwnd,
		null,
		inst,
		null
	);
	if (scroll_label == null) {
		stderr.printf ("CreateWindowExW (static scroll) failed\n");
		return 1;
	}

	uint scroll_style = (uint) (
		WindowStyle.WS_CHILD |
		WindowStyle.WS_VISIBLE |
		WindowStyle.WS_TABSTOP |
		SBS_HORZ
	);

	scroll_hwnd = create_window_ex (
		0,
		WC_SCROLLBAR,
		null,
		scroll_style,
		20,
		344,
		320,
		24,
		hwnd,
		(void*) ID_SCROLL,
		inst,
		null
	);
	if (scroll_hwnd == null) {
		stderr.printf ("CreateWindowExW (scrollbar) failed\n");
		return 1;
	}
	send_message (
		scroll_hwnd,
		SBM_SETRANGE,
		0,
		makelparam (0, (uint) SCROLL_MAX)
	);
	send_message (scroll_hwnd, SBM_SETPOS, 1, 50);

	void* progress_label = create_window_ex (
		0,
		WC_STATIC,
		LABEL_PROGRESS,
		static_style,
		20,
		376,
		72,
		20,
		hwnd,
		null,
		inst,
		null
	);
	if (progress_label == null) {
		stderr.printf ("CreateWindowExW (static progress) failed\n");
		return 1;
	}

	uint progress_style = (uint) (
		WindowStyle.WS_CHILD |
		WindowStyle.WS_VISIBLE |
		PBS_SMOOTH
	);

	progress_hwnd = create_window_ex (
		0,
		PROGRESS_CLASS,
		null,
		progress_style,
		20,
		400,
		320,
		20,
		hwnd,
		null,
		inst,
		null
	);
	if (progress_hwnd == null) {
		stderr.printf ("CreateWindowExW (progress) failed\n");
		return 1;
	}
	send_message (progress_hwnd, PBM_SETRANGE32, 0, (int64) SCROLL_MAX);
	sync_progress_from_scroll ();

	Msg msg;
	while (get_message (out msg, null, 0, 0) > 0) {
		translate_message (ref msg);
		dispatch_message (ref msg);
	}

	return 0;
}
