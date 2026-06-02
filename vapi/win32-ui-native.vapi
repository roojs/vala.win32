/* Win32 API relay (CCode). Use with --pkg win32-ui --pkg win32-ui-native. */

namespace Win32Ui.Native {
	[CCode (cname = "WNDPROC", has_target = false)]
	public delegate long WndProc (
		[CCode (type_id = "HWND")] void* h_wnd,
		uint msg,
		ulong w_param,
		long l_param
	);

	[CCode (cname = "WNDCLASSEXW", cheader_filename = "windows.h")]
	public struct WndClassEx {
		public uint cbSize;
		public uint style;
		public WndProc lpfnWndProc;
		public int cbClsExtra;
		public int cbWndExtra;
		public void* hInstance;
		public void* hIcon;
		public void* hCursor;
		public void* hbrBackground;
		public unowned uint16* lpszMenuName;
		public unowned uint16* lpszClassName;
		public void* hIconSm;
	}

	[CCode (cname = "MSG", cheader_filename = "windows.h")]
	public struct Msg {
		public void* hwnd;
		public uint message;
		public ulong wParam;
		public long lParam;
		public uint time;
		public int pt_x;
		public int pt_y;
	}

	[CCode (cname = "GetModuleHandleW", cheader_filename = "windows.h")]
	public extern void* get_module_handle (void* lp_module_name);

	[CCode (cname = "RegisterClassExW", cheader_filename = "windows.h")]
	public extern ushort register_class_ex (ref WndClassEx lp_wcx);

	[CCode (cname = "CreateWindowExW", cheader_filename = "windows.h")]
	public extern void* create_window_ex (
		uint dw_ex_style,
		[CCode (type_id = "LPCWSTR")] uint16* lp_class_name,
		[CCode (type_id = "LPCWSTR")] uint16* lp_window_name,
		uint dw_style,
		int x,
		int y,
		int n_width,
		int n_height,
		[CCode (type_id = "HWND")] void* h_wnd_parent,
		[CCode (type_id = "HMENU")] void* h_menu,
		[CCode (type_id = "HINSTANCE")] void* h_instance,
		void* lp_param
	);

	[CCode (cname = "GetMessageW", cheader_filename = "windows.h")]
	public extern int get_message (
		out Msg lp_msg,
		[CCode (type_id = "HWND")] void* h_wnd,
		uint w_msg_filter_min,
		uint w_msg_filter_max
	);

	[CCode (cname = "TranslateMessage", cheader_filename = "windows.h")]
	public extern int translate_message (ref Msg lp_msg);

	[CCode (cname = "DispatchMessageW", cheader_filename = "windows.h")]
	public extern long dispatch_message (ref Msg lp_msg);

	[CCode (cname = "DefWindowProcW", cheader_filename = "windows.h")]
	public extern long def_window_proc (
		[CCode (type_id = "HWND")] void* h_wnd,
		uint msg,
		ulong w_param,
		long l_param
	);

	[CCode (cname = "PostQuitMessage", cheader_filename = "windows.h")]
	public extern void post_quit_message (int n_exit_code);
}
