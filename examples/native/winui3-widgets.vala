/* Phase 9c: WinUI3 widgets — layout + input + button click (host implements UI). */

using WinUI3;

public static int main (string[] args) {
	int hr = run_widgets_demo ();
	if (hr != 0) {
		stderr.printf ("WinUI3 widgets demo failed: 0x%08x\n", (uint) hr);
		return 1;
	}
	return 0;
}
