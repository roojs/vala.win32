/* Hand-maintained UTF-8 ↔ UTF-16 helpers for examples (generator emit TBD).
 * Use WideString while Win32 retains the LPCWSTR pointer (e.g. registered class name).
 * Pure Vala — no GLib; --profile=posix has no string.to_utf16 () or unichar. */

using Win32.Ui.WindowsAndMessaging;

namespace Win32.Ui {

private long[] utf8_to_utf16 (string text) {
	var wide = new long[text.length * 2 + 1];
	int out = 0;
	unowned char* p = text;
	while (*p != '\0') {
		uint8 b0 = (uint8) *p;
		uint32 c;
		if ((b0 & 0x80) == 0) {
			c = b0;
			p += 1;
		} else if ((b0 & 0xe0) == 0xc0 && p[1] != '\0') {
			c = (b0 & 0x1f) << 6;
			c |= ((uint8) p[1]) & 0x3f;
			p += 2;
		} else if ((b0 & 0xf0) == 0xe0 && p[1] != '\0' && p[2] != '\0') {
			c = (b0 & 0x0f) << 12;
			c |= (((uint8) p[1]) & 0x3f) << 6;
			c |= ((uint8) p[2]) & 0x3f;
			p += 3;
		} else if ((b0 & 0xf8) == 0xf0 && p[1] != '\0' && p[2] != '\0' && p[3] != '\0') {
			c = (b0 & 0x07) << 18;
			c |= (((uint8) p[1]) & 0x3f) << 12;
			c |= (((uint8) p[2]) & 0x3f) << 6;
			c |= ((uint8) p[3]) & 0x3f;
			p += 4;
		} else {
			p += 1;
			continue;
		}
		if (c <= 0xffff) {
			wide[out++] = c;
		} else {
			c -= 0x10000;
			wide[out++] = 0xd800 + (c >> 10);
			wide[out++] = 0xdc00 + (c & 0x3ff);
		}
	}
	wide[out++] = 0;
	wide.length = out;
	return wide;
}

public struct WideString {
	long[] _utf16;

	public WideString (string text) {
		_utf16 = utf8_to_utf16 (text);
	}

	public uint16* ptr {
		get { return (uint16*) _utf16; }
	}
}

public string window_text_get (void* hwnd, int max_chars = 256) {
	if (hwnd == null) {
		return "";
	}
	var buf = new uint16[max_chars];
	get_window_text (hwnd, buf, max_chars);
	return (string) buf;
}

public void window_text_set (void* hwnd, string text) {
	if (hwnd == null) {
		return;
	}
	long[] wide = utf8_to_utf16 (text);
	set_window_text (hwnd, (uint16*) wide);
}

}
