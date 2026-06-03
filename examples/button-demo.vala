/* Phase 3 Track A: Button + Edit child controls; WM_COMMAND; get/set window text. */

using Win32.Ui.Controls;
using Win32.Ui.WindowsAndMessaging;
using Win32.System;

const int ID_CLICK_ME = 100;
const int ID_EDIT = 101;
const int EDIT_TEXT_MAX = 256;

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] CLASS_NAME = {
	'V', 'a', 'l', 'a', 'B', 'u', 't', 't', 'o', 'n', 'D', 'e', 'm', 'o', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] WINDOW_TITLE = {
	'v', 'a', 'l', 'a', '.', 'w', 'i', 'n', '3', '2', ' ', 'b', 'u', 't', 't', 'o', 'n', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] BUTTON_LABEL = {
	'C', 'l', 'i', 'c', 'k', ' ', 'm', 'e', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] EDIT_INITIAL = {
	'H', 'e', 'l', 'l', 'o', ',', ' ', 'E', 'd', 'i', 't', 0
};

private void* edit_hwnd = null;

private long window_proc (
	[CCode (type_id = "HWND")] void* h_wnd,
	uint msg,
	ulong w_param,
	long l_param
) {
	if (msg == WM_COMMAND) {
		if (loword (w_param) == ID_CLICK_ME && hiword (w_param) == BN_CLICKED) {
			if (edit_hwnd != null) {
				var text = new uint16[EDIT_TEXT_MAX];
				get_window_text (edit_hwnd, text, EDIT_TEXT_MAX);
				set_window_text (h_wnd, text);
			}
			return 0;
		}
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
		320,
		220,
		null,
		null,
		inst,
		null
	);
	if (hwnd == null) {
		stderr.printf ("CreateWindowExW failed\n");
		return 1;
	}

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
		20,
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
		20,
		64,
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

	Msg msg;
	while (get_message (out msg, null, 0, 0) > 0) {
		translate_message (ref msg);
		dispatch_message (ref msg);
	}

	return 0;
}
