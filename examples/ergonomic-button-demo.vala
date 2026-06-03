/* Phase 3 Track B (B0/B1): Win32.Button / Win32.Edit + WidgetDispatch. */

const int ID_CLICK_ME = 100;
const int ID_EDIT = 101;

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] CLASS_NAME = {
	'V', 'a', 'l', 'a', 'W', 'i', 'n', '3', '2', 'E', 'r', 'g', 'o', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] WINDOW_TITLE = {
	'v', 'a', 'l', 'a', '.', 'w', 'i', 'n', '3', '2', ' ', 'e', 'r', 'g', 'o', 0
};

[CCode (array_length = false, array_null_terminated = true)]
const uint16[] BUTTON_LABEL = {
	'C', 'l', 'i', 'c', 'k', ' ', 'm', 'e', 0
};

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
		CLASS_NAME,
		WINDOW_TITLE,
		window_proc,
		360,
		120
	);
	if (frame.handle == null) {
		return 1;
	}

	name_edit = Win32.Edit (frame, inst, 72, 12, 260, 24, ID_EDIT);
	name_edit.set_text ("Hello, Edit");
	if (name_edit.handle == null) {
		return 1;
	}

	click_btn = Win32.Button (
		frame,
		inst,
		20,
		44,
		120,
		32,
		ID_CLICK_ME,
		BUTTON_LABEL
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
