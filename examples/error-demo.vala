/* Phase 4d: Win32 GetLastError → Vala Win32Error (generated helpers). */

using Win32;
using Win32.Ui;
using Win32.Ui.WindowsAndMessaging;
using Win32.System;

public static int main (string[] args) {
	void* inst = get_module_handle (null);

	var class_name = WideString ("ValaErrorDemoBadClass");
	var wc = WndClassEx ();
	wc.cbSize = (uint) sizeof (WndClassEx);
	wc.hInstance = inst;
	wc.lpszClassName = class_name.ptr;

	try {
		check_bool (register_class_ex (ref wc));
		stderr.printf ("unexpected: RegisterClassExW succeeded without WndProc\n");
		return 1;
	} catch (Win32Error e) {
		stderr.printf ("RegisterClassExW failed as expected (code %u)\n", e.win32_code);
	}

	var bogus_class = WideString ("NoSuchClass_12345");
	try {
		check_pointer (create_window_ex (
			0,
			bogus_class.ptr,
			WideString ("title").ptr,
			WindowStyle.WS_OVERLAPPEDWINDOW,
			CW_USEDEFAULT,
			CW_USEDEFAULT,
			100,
			100,
			null,
			null,
			inst,
			null
		));
		stderr.printf ("unexpected: CreateWindowExW succeeded\n");
		return 1;
	} catch (Win32Error e) {
		stderr.printf ("CreateWindowExW failed as expected (code %u)\n", e.win32_code);
	}

	return 0;
}
