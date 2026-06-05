/* Phase 4a: MessageBox via generated vapi(Track A). */

using Win32.Ui;
using Win32.Ui.WindowsAndMessaging;
using Win32.System;

private int64 window_proc(
	[CCode(type_id = "HWND")] void* h_wnd,
	uint msg,
	ulong w_param,
	int64 l_param
) {
	if (msg == WM_DESTROY) {
		post_quit_message(0);
		return 0;
	}
	return def_window_proc(h_wnd, msg, w_param, l_param);
}

public static int main(string[] args) {
	void* inst = get_module_handle(null);

	var class_name = WideString("ValaDialogDemo");
	var window_title = WideString("vala.win32 dialog-demo");

	var wc = WndClassEx();
	wc.cbSize = (uint) sizeof (WndClassEx);
	wc.lpfnWndProc = window_proc;
	wc.hInstance = inst;
	wc.hbrBackground = (void*) (SysColorIndex.COLOR_WINDOW + 1);
	wc.lpszClassName = class_name.ptr;

	if (register_class_ex(ref wc) == 0) {
		stderr.printf("RegisterClassExW failed\n");
		return 1;
	}

	void* hwnd = create_window_ex(
		0,
		class_name.ptr,
		window_title.ptr,
		WindowStyle.WS_OVERLAPPEDWINDOW | WindowStyle.WS_VISIBLE,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		480,
		320,
		null,
		null,
		inst,
		null
	);
	if (hwnd == null) {
		stderr.printf("CreateWindowExW failed\n");
		return 1;
	}

	uint style = (uint) (
		MESSAGEBOXSTYLE.MB_OK |
		MESSAGEBOXSTYLE.MB_ICONINFORMATION
	);
	var result = message_box(
		hwnd,
		WideString("MessageBoxW from generated vapi.").ptr,
		WideString("Phase 4a").ptr,
		style
	);
	stderr.printf(
		"MessageBox returned %d(IDOK=%d)\n",
		(int) result,
		(int) MESSAGEBOXRESULT.IDOK
	);

	Msg msg;
	while (get_message(out msg, null, 0, 0) > 0) {
		translate_message(ref msg);
		dispatch_message(ref msg);
	}

	return 0;
}