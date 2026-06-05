/* Track B / Phase 4d: win32_bool_ok helpers(no Window — hand baseline). */

using Win32;
using Win32.Ui;
using Win32.Ui.WindowsAndMessaging;
using Win32.System;

public static int main(string[] args) {
	void* inst = get_module_handle(null);
	uint err = 0;

	stderr.printf("error-demo: intentional failures(expect exit 0)\n");

	var class_name = WideString("ValaErgoErrorBadClass");
	var wc = WndClassEx();
	wc.cbSize = 0;
	wc.hInstance = inst;
	wc.lpszClassName = class_name.ptr;

	if (win32_bool_ok(register_class_ex(ref wc), out err)) {
		stderr.printf("unexpected: RegisterClassExW succeeded with cbSize 0\n");
		return 1;
	}
	stderr.printf("RegisterClassExW failed as expected(code %u)\n", err);

	var bogus = WideString("NoSuchClass_12345");
	if (win32_bool_ok(unregister_class(bogus.ptr, inst), out err)) {
		stderr.printf("unexpected: UnregisterClassW succeeded\n");
		return 1;
	}
	stderr.printf("UnregisterClassW failed as expected(code %u)\n", err);

	return 0;
}