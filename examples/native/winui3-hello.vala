/* Phase 9b: WinUI3 hello window — bootstrap + Application + Window + TextBlock. */

using WinUI3;

public static int main (string[] args) {
	stdout.printf ("Starting WinUI3 hello window...\n");
	int hr = run_hello_window ();
	if (hr != 0) {
		stderr.printf ("WinUI3 hello failed: 0x%08x\n", (uint) hr);
		return 1;
	}
	stdout.printf ("WinUI3 hello finished\n");
	return 0;
}
