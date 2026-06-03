/* Phase 3 Track A: child Button + WM_COMMAND / BN_CLICKED. */

using Win32.Ui.Controls;
using Win32.Ui.WindowsAndMessaging;
using Win32.System;

const int ID_CLICK_ME = 100;

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
const uint16[] CLICKED_TITLE = {
	'C', 'l', 'i', 'c', 'k', 'e', 'd', '!', 0
};

private long window_proc (
	[CCode (type_id = "HWND")] void* h_wnd,
	uint msg,
	ulong w_param,
	long l_param
) {
	if (msg == WM_COMMAND) {
		if (loword (w_param) == BN_CLICKED && hiword (w_param) == ID_CLICK_ME) {
			set_window_text (h_wnd, CLICKED_TITLE);
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
		200,
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

	Msg msg;
	while (get_message (out msg, null, 0, 0) > 0) {
		translate_message (ref msg);
		dispatch_message (ref msg);
	}

	return 0;
}
