/* Phase 3 Track B (B0/B1): Win32.Button / Win32.Edit + WidgetDispatch. */

const int ID_CLICK_ME = 100;
const int ID_EDIT = 101;

private Win32.Window frame;
private Win32.Button click_btn;
private Win32.Edit name_edit;

private int64 window_proc (
	[CCode (type_id = "HWND")] void* h_wnd,
	uint msg,
	ulong w_param,
	int64 l_param
) {
	if (msg == Win32.Ui.WindowsAndMessaging.WM_COMMAND) {
		if (Win32.WidgetDispatch.try_wm_command (w_param)) {
			return 0;
		}
	}
	if (msg == Win32.Ui.WindowsAndMessaging.WM_DESTROY) {
		Win32.Ui.WindowsAndMessaging.post_quit_message (0);
		return 0;
	}
	return Win32.Ui.WindowsAndMessaging.def_window_proc (h_wnd, msg, w_param, l_param);
}

public static int main (string[] args) {
	void* inst = Win32.System.get_module_handle (null);

	frame = Win32.Window (
		inst,
		"ValaWin32Ergo",
		"vala.win32 ergo",
		window_proc,
		360, // width
		120  // height
	);
	if (frame.handle == null) {
		return 1;
	}

	name_edit = Win32.Edit (
		frame,
		inst,
		72,      // x
		12,      // y
		260,     // width
		24,      // height
		ID_EDIT  // control id (WM_COMMAND)
	);
	name_edit.set_text ("Hello, Edit");
	if (name_edit.handle == null) {
		return 1;
	}

	click_btn = Win32.Button (
		frame,
		inst,
		20,          // x
		44,          // y
		120,         // width
		32,          // height
		ID_CLICK_ME, // control id (WM_COMMAND)
		"Click me"   // label
	);
	if (click_btn.handle == null) {
		return 1;
	}

	click_btn.clicked (() => {
		frame.set_title (name_edit.get_text ());
	});

	Win32.Ui.WindowsAndMessaging.Msg msg;
	while (Win32.Ui.WindowsAndMessaging.get_message (out msg, null, 0, 0) > 0) {
		Win32.Ui.WindowsAndMessaging.translate_message (ref msg);
		Win32.Ui.WindowsAndMessaging.dispatch_message (ref msg);
	}

	return 0;
}
