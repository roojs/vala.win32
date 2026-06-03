/* Phase 4d: GetLastError helpers (generated win32-errors.vala, POSIX-safe).
 *
 * Prints two intentional API failures and exits 0. No CreateWindowExW — on some
 * Wine builds that call raises a SEH fault dialog even when it returns NULL. */

using Win32;
using Win32.Ui;
using Win32.Ui.WindowsAndMessaging;
using Win32.System;

public static int main (string[] args) {
	void* inst = get_module_handle (null);
	uint err = 0;

	stderr.printf ("error-demo: two intentional API failures (expect clean exit 0)\n");

	/* Invalid cbSize → RegisterClassExW fails (ERROR_INVALID_PARAMETER = 87). */
	var class_name = WideString ("ValaErrorDemoBadClass");
	var wc = WndClassEx ();
	wc.cbSize = 0;
	wc.hInstance = inst;
	wc.lpszClassName = class_name.ptr;

	if (win32_bool_ok (register_class_ex (ref wc), out err)) {
		stderr.printf ("unexpected: RegisterClassExW succeeded with cbSize 0\n");
		return 1;
	}
	stderr.printf ("RegisterClassExW failed as expected (code %u)\n", err);

	/* Class never registered → UnregisterClassW fails (ERROR_CLASS_DOES_NOT_EXIST = 1411). */
	var bogus_class = WideString ("NoSuchClass_12345");
	if (win32_bool_ok (unregister_class (bogus_class.ptr, inst), out err)) {
		stderr.printf ("unexpected: UnregisterClassW succeeded\n");
		return 1;
	}
	stderr.printf ("UnregisterClassW failed as expected (code %u)\n", err);

	return 0;
}
