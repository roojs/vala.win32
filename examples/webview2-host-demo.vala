/* Phase 7b: Win32 host window + WebView2 plumbing (async; needs message loop). */

using WebView2.Plumbing;
using Win32.Ui;
using Win32.Ui.WindowsAndMessaging;
using Win32.System;

private void* g_hwnd;

private int64 window_proc (
	[CCode (type_id = "HWND")] void* h_wnd,
	uint msg,
	ulong w_param,
	int64 l_param
) {
	if (msg == WM_SIZE) {
		host_on_size (g_hwnd);
		return 0;
	}
	if (msg == WM_DESTROY) {
		host_destroy ();
		post_quit_message (0);
		return 0;
	}
	return def_window_proc (h_wnd, msg, w_param, l_param);
}

public static int main (string[] args) {
	void* inst = get_module_handle (null);
	var class_name = WideString ("ValaWin32WebView2Host");
	var window_title = WideString ("vala.win32 WebView2 host (7b)");

	var wc = WndClassEx ();
	wc.cbSize = (uint) sizeof (WndClassEx);
	wc.lpfnWndProc = window_proc;
	wc.hInstance = inst;
	wc.hbrBackground = (void*) (SysColorIndex.COLOR_WINDOW + 1);
	wc.lpszClassName = class_name.ptr;

	if (register_class_ex (ref wc) == 0) {
		stderr.printf ("RegisterClassExW failed\n");
		return 1;
	}

	g_hwnd = create_window_ex (
		0,
		class_name.ptr,
		window_title.ptr,
		WindowStyle.WS_OVERLAPPEDWINDOW | WindowStyle.WS_VISIBLE,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		1024,
		768,
		null,
		null,
		inst,
		null
	);
	if (g_hwnd == null) {
		stderr.printf ("CreateWindowExW failed\n");
		return 1;
	}

	var start_url = "https://example.com/";
	if (args.length > 1) {
		start_url = args[1];
	}
	var url = WideString (start_url);
	if (!host_create (g_hwnd, url.ptr)) {
		stderr.printf ("WebView2 host_create failed (runtime/loader missing?)\n");
		return 1;
	}

	Msg msg;
	while (get_message (out msg, null, 0, 0) > 0) {
		translate_message (ref msg);
		dispatch_message (ref msg);
	}

	return 0;
}
