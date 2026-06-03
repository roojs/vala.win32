/* Phase 4b: common dialogs (file / color / font) via generated vapi. */

using Win32.Ui;
using Win32.Ui.Controls.Dialogs;
using Win32.Ui.Controls;
using Win32.Ui.WindowsAndMessaging;
using Win32.System;

const int ID_OPEN = 200;
const int ID_COLOR = 201;
const int FILE_BUF_CHARS = 260;

private void* frame_hwnd = null;

private void show_open_file () {
	if (frame_hwnd == null) {
		return;
	}
	var file_buf = new uint16[FILE_BUF_CHARS];
	var filter = WideString ("Text (*.txt)\0*.txt\0All (*.*)\0*.*\0");
	var ofn = OPENFILENAME ();
	ofn.lStructSize = (uint) sizeof (OPENFILENAME);
	ofn.hwndOwner = frame_hwnd;
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
		window_text_set (frame_hwnd, (string) file_buf);
	} else {
		window_text_set (frame_hwnd, "(open cancelled)");
	}
}

private void show_choose_color () {
	if (frame_hwnd == null) {
		return;
	}
	uint rgb = 0x000000ff;
	var cc = CHOOSECOLOR ();
	cc.lStructSize = (uint) sizeof (CHOOSECOLOR);
	cc.hwndOwner = frame_hwnd;
	cc.rgbResult = (void*) (&rgb);
	cc.Flags = CHOOSECOLORFLAGS.CC_RGBINIT | CHOOSECOLORFLAGS.CC_FULLOPEN;
	if (choose_color (ref cc) != 0) {
		window_text_set (frame_hwnd, "Color 0x%06x".printf (rgb & 0xffffff));
	} else {
		window_text_set (frame_hwnd, "(color cancelled)");
	}
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
		if (code == BN_CLICKED) {
			if (id == ID_OPEN) {
				show_open_file ();
				return 0;
			}
			if (id == ID_COLOR) {
				show_choose_color ();
				return 0;
			}
		}
	}
	if (msg == WM_DESTROY) {
		post_quit_message (0);
		return 0;
	}
	return def_window_proc (h_wnd, msg, w_param, l_param);
}

private void* add_button (
	void* parent,
	void* inst,
	int id,
	string label,
	int y
) {
	uint style = (uint) (
		WindowStyle.WS_CHILD |
		WindowStyle.WS_VISIBLE |
		WindowStyle.WS_TABSTOP
	);
	return create_window_ex (
		0,
		WC_BUTTON,
		WideString (label).ptr,
		style,
		20,
		y,
		140,
		28,
		parent,
		(void*) id,
		inst,
		null
	);
}

public static int main (string[] args) {
	void* inst = get_module_handle (null);

	var class_name = WideString ("ValaCommonDialogDemo");
	var window_title = WideString ("vala.win32 common-dialog-demo");

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

	frame_hwnd = create_window_ex (
		0,
		class_name.ptr,
		window_title.ptr,
		WindowStyle.WS_OVERLAPPEDWINDOW | WindowStyle.WS_VISIBLE,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		400,
		220,
		null,
		null,
		inst,
		null
	);
	if (frame_hwnd == null) {
		stderr.printf ("CreateWindowExW failed\n");
		return 1;
	}

	if (add_button (frame_hwnd, inst, ID_OPEN, "Open file…", 20) == null
		|| add_button (frame_hwnd, inst, ID_COLOR, "Choose color…", 56) == null) {
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
