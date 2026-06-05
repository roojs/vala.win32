/* Phase 4c: menu bar + LoadCursor (Track A). See docs/win32-rc.md for .rc resources. */

using Win32.Ui;
using Win32.Ui.WindowsAndMessaging;
using Win32.System;

const int ID_FILE_HELLO = 300;
const int ID_FILE_EXIT = 301;

/* IDC_ARROW from win32metadata (not emitted as const yet). */
const int IDC_ARROW = 32512;

private int64 window_proc (
	[CCode (type_id = "HWND")] void* h_wnd,
	uint msg,
	ulong w_param,
	int64 l_param
) {
	if (msg == WM_COMMAND) {
		var id = loword (w_param);
		if (id == ID_FILE_HELLO) {
			uint style = (uint) (
				MESSAGEBOXSTYLE.MB_OK |
				MESSAGEBOXSTYLE.MB_ICONINFORMATION
			);
			message_box (
				h_wnd,
				WideString ("Hello from the menu.").ptr,
				WideString ("menu-demo").ptr,
				style
			);
			return 0;
		}
		if (id == ID_FILE_EXIT) {
			destroy_window (h_wnd);
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

	var class_name = WideString ("ValaMenuDemo");
	var window_title = WideString ("vala.win32 menu-demo");

	var wc = WndClassEx ();
	wc.cbSize = (uint) sizeof (WndClassEx);
	wc.lpfnWndProc = window_proc;
	wc.hInstance = inst;
	wc.hbrBackground = (void*) (SysColorIndex.COLOR_WINDOW + 1);
	wc.lpszClassName = class_name.ptr;
	wc.hCursor = load_cursor (null, (uint16*) (ulong) IDC_ARROW);

	if (register_class_ex (ref wc) == 0) {
		stderr.printf ("RegisterClassExW failed\n");
		return 1;
	}

	void* file_menu = create_menu ();
	append_menu (
		file_menu,
		MENUITEMFLAGS.MF_STRING,
		(void*) ID_FILE_HELLO,
		WideString ("Say &hello").ptr
	);
	append_menu (
		file_menu,
		MENUITEMFLAGS.MF_STRING,
		(void*) ID_FILE_EXIT,
		WideString ("E&xit").ptr
	);

	void* bar = create_menu ();
	append_menu (
		bar,
		MENUITEMFLAGS.MF_POPUP | MENUITEMFLAGS.MF_STRING,
		file_menu,
		WideString ("&File").ptr
	);

	void* hwnd = create_window_ex (
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
		stderr.printf ("CreateWindowExW failed\n");
		return 1;
	}

	set_menu (hwnd, bar);

	Msg msg;
	while (get_message (out msg, null, 0, 0) > 0) {
		translate_message (ref msg);
		dispatch_message (ref msg);
	}

	return 0;
}
