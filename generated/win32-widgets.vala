/* Hand-maintained Track B spike (B0/B1) — generator emit in B3.
 * Struct constructors + namespace helpers: --profile=posix skips class method codegen in valac 0.56. */

using Win32.Ui.Controls;
using Win32.Ui.WindowsAndMessaging;

namespace Win32 {

const int CONTROL_TEXT_MAX = 256;
const int EDIT_STYLE_AUTOHSCROLL = 0x0080;
const int WM_COMMAND_REGISTRY_MAX = 64;

private enum WmCommandKind {
	BUTTON,
	EDIT
}

public delegate void ButtonClickedCallback ();
public delegate void EditChangedCallback ();

private struct WmCommandRegistration {
	public int control_id;
	public WmCommandKind kind;
	public ButtonClickedCallback clicked;
	public EditChangedCallback changed;
}

private int wm_command_count = 0;
private WmCommandRegistration[]? wm_command_registry = null;

private WmCommandRegistration[] wm_command_registry_get () {
	if (wm_command_registry == null) {
		wm_command_registry = new WmCommandRegistration[WM_COMMAND_REGISTRY_MAX];
	}
	return wm_command_registry;
}

private void control_text_set (void* handle, string value) {
	if (handle == null) {
		return;
	}
	set_window_text (handle, value);
}

private void control_text_read_into (void* handle, uint16[] buffer, int max_count) {
	if (handle == null) {
		buffer[0] = 0;
		return;
	}
	get_window_text (handle, buffer, max_count);
}

private void wm_command_register_button (int control_id, owned ButtonClickedCallback callback) {
	var registry = wm_command_registry_get ();
	for (int i = 0; i < wm_command_count; i++) {
		if (registry[i].control_id == control_id) {
			registry[i].kind = WmCommandKind.BUTTON;
			registry[i].clicked = (owned) callback;
			return;
		}
	}
	if (wm_command_count >= WM_COMMAND_REGISTRY_MAX) {
		stderr.printf ("WidgetDispatch registry full\n");
		return;
	}
	registry[wm_command_count].control_id = control_id;
	registry[wm_command_count].kind = WmCommandKind.BUTTON;
	registry[wm_command_count].clicked = (owned) callback;
	wm_command_count++;
}

private void wm_command_register_edit (int control_id, owned EditChangedCallback callback) {
	var registry = wm_command_registry_get ();
	for (int i = 0; i < wm_command_count; i++) {
		if (registry[i].control_id == control_id) {
			registry[i].kind = WmCommandKind.EDIT;
			registry[i].changed = (owned) callback;
			return;
		}
	}
	if (wm_command_count >= WM_COMMAND_REGISTRY_MAX) {
		stderr.printf ("WidgetDispatch registry full\n");
		return;
	}
	registry[wm_command_count].control_id = control_id;
	registry[wm_command_count].kind = WmCommandKind.EDIT;
	registry[wm_command_count].changed = (owned) callback;
	wm_command_count++;
}

private bool wm_command_dispatch (ulong w_param) {
	var control_id = (int) loword (w_param);
	var notify = hiword (w_param);
	var registry = wm_command_registry_get ();
	for (int i = 0; i < wm_command_count; i++) {
		if (registry[i].control_id != control_id) {
			continue;
		}
		switch (registry[i].kind) {
		case WmCommandKind.BUTTON:
			if (notify == BN_CLICKED) {
				registry[i].clicked ();
				return true;
			}
			break;
		case WmCommandKind.EDIT:
			if (notify == EN_CHANGE) {
				registry[i].changed ();
				return true;
			}
			break;
		}
		return false;
	}
	return false;
}

public struct WidgetDispatch {
	public int _reserved;

	public static bool try_wm_command (ulong w_param) {
		return wm_command_dispatch (w_param);
	}
}

public struct Window {
	public void* handle;

	public Window (
		void* instance,
		uint16[] class_name,
		uint16[] window_title,
		WndProc window_proc,
		int width,
		int height
	) {
		var wc = WndClassEx ();
		wc.cbSize = (uint) sizeof (WndClassEx);
		wc.lpfnWndProc = window_proc;
		wc.hInstance = instance;
		wc.hbrBackground = (void*) (SysColorIndex.COLOR_WINDOW + 1);
		wc.lpszClassName = class_name;

		if (register_class_ex (ref wc) == 0) {
			stderr.printf ("RegisterClassExW failed\n");
			handle = null;
			return;
		}

		handle = create_window_ex (
			0,
			class_name,
			window_title,
			WindowStyle.WS_OVERLAPPEDWINDOW | WindowStyle.WS_VISIBLE,
			CW_USEDEFAULT,
			CW_USEDEFAULT,
			width,
			height,
			null,
			null,
			instance,
			null
		);
		if (handle == null) {
			stderr.printf ("CreateWindowExW failed\n");
		}
	}

	public string get_title () {
		if (handle == null) {
			return "";
		}
		var buf = new uint16[CONTROL_TEXT_MAX];
		control_text_read_into (handle, buf, CONTROL_TEXT_MAX);
		return (string) buf;
	}

	public void set_title (string value) {
		control_text_set (handle, value);
	}
}

public struct Button {
	public void* handle;
	public int id;

	public Button (
		Window parent,
		void* instance,
		int x,
		int y,
		int width,
		int height,
		int control_id,
		uint16[] label
	) {
		id = control_id;

		uint style = (uint) (
			WindowStyle.WS_CHILD |
			WindowStyle.WS_VISIBLE |
			WindowStyle.WS_TABSTOP |
			BS_DEFPUSHBUTTON
		);

		handle = create_window_ex (
			0,
			WC_BUTTON,
			label,
			style,
			x,
			y,
			width,
			height,
			parent.handle,
			(void*) control_id,
			instance,
			null
		);
		if (handle == null) {
			stderr.printf ("CreateWindowExW (button) failed\n");
		}
	}

	public void clicked (owned ButtonClickedCallback callback) {
		wm_command_register_button (id, (owned) callback);
	}
}

public struct Edit {
	public void* handle;
	public int id;

	public Edit (
		Window parent,
		void* instance,
		int x,
		int y,
		int width,
		int height,
		int control_id
	) {
		id = control_id;

		uint style = (uint) (
			WindowStyle.WS_CHILD |
			WindowStyle.WS_VISIBLE |
			WindowStyle.WS_BORDER |
			WindowStyle.WS_TABSTOP |
			EDIT_STYLE_AUTOHSCROLL
		);

		handle = create_window_ex (
			0,
			WC_EDIT,
			null,
			style,
			x,
			y,
			width,
			height,
			parent.handle,
			(void*) control_id,
			instance,
			null
		);
		if (handle == null) {
			stderr.printf ("CreateWindowExW (edit) failed\n");
		}
	}

	public string get_text () {
		if (handle == null) {
			return "";
		}
		var buf = new uint16[CONTROL_TEXT_MAX];
		control_text_read_into (handle, buf, CONTROL_TEXT_MAX);
		return (string) buf;
	}

	public void set_text (string value) {
		control_text_set (handle, value);
	}

	public void changed (owned EditChangedCallback callback) {
		wm_command_register_edit (id, (owned) callback);
	}
}

}
