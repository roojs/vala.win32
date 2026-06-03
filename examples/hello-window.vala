/* Phase 2: native Win32 message loop via generated vapi shards. */

using Win32.Ui.WindowsAndMessaging;
using Win32.System;

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] CLASS_NAME = {
	'V', 'a', 'l', 'a', 'W', 'i', 'n', '3', '2', '.', 'H', 'e', 'l', 'l', 'o', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] WINDOW_TITLE = {
	'v', 'a', 'l', 'a', '.', 'w', 'i', 'n', '3', '2', ' ', 'P', 'h', 'a', 's', 'e', ' ', '2', 0
};

private long window_proc (
	[CCode (type_id = "HWND")] void* h_wnd,
	uint msg,
	ulong w_param,
	long l_param
) {
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
		640,
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

	Msg msg;
	while (get_message (out msg, null, 0, 0) > 0) {
		translate_message (ref msg);
		dispatch_message (ref msg);
	}

	return 0;
}
