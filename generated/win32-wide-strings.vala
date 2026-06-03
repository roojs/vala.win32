/* Hand-maintained UTF-8 ↔ UTF-16 helpers for examples (generator emit TBD).
 *
 * WideString lifetime (when to cache vs copy):
 * - WC_* in win32-ui-control-strings.vala: compile-time UTF-16 arrays (already static).
 * - RegisterClass class name: keep a WideString field (e.g. Window._class_name) for app lifetime.
 * - Control captions / item text: prefer window_text_set (Win32 copies); do not pass a
 *   short-lived WideString.ptr to CreateWindowEx unless you keep the WideString alive.
 * - ListBox/ComboBox LB_ADDSTRING / CB_ADDSTRING: Win32 copies the buffer; temp WideString is OK.
 * - intern(): optional UTF-16 cache for repeated literals — defer to B3 generator (Gee/hash).
 *
 * Pure Vala — no GLib; --profile=posix has no string.to_utf16 () or unichar. */

using Win32.Ui.WindowsAndMessaging;

namespace Win32.Ui {

private uint16[] utf8_to_utf16 (string text) {
	var wide = new uint16[text.length * 2 + 1];
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
			wide[out++] = (uint16) c;
		} else {
			c -= 0x10000;
			wide[out++] = (uint16) (0xd800 + (c >> 10));
			wide[out++] = (uint16) (0xdc00 + (c & 0x3ff));
		}
	}
	wide[out++] = 0;
	wide.length = out;
	return wide;
}

public string utf16_buffer_to_string (uint16[] wide) {
	return utf16_to_utf8 (wide);
}

private int utf8_append_codepoint (uint8[] buf, int len, uint32 c) {
	if (c <= 0x7f) {
		buf[len++] = (uint8) c;
	} else if (c <= 0x7ff) {
		buf[len++] = (uint8) (0xc0 | (c >> 6));
		buf[len++] = (uint8) (0x80 | (c & 0x3f));
	} else if (c <= 0xffff) {
		buf[len++] = (uint8) (0xe0 | (c >> 12));
		buf[len++] = (uint8) (0x80 | ((c >> 6) & 0x3f));
		buf[len++] = (uint8) (0x80 | (c & 0x3f));
	} else {
		buf[len++] = (uint8) (0xf0 | (c >> 18));
		buf[len++] = (uint8) (0x80 | ((c >> 12) & 0x3f));
		buf[len++] = (uint8) (0x80 | ((c >> 6) & 0x3f));
		buf[len++] = (uint8) (0x80 | (c & 0x3f));
	}
	return len;
}

private string utf16_to_utf8 (uint16[] wide) {
	var bytes = new uint8[wide.length * 4 + 1];
	int len = 0;
	for (int i = 0; i < wide.length && wide[i] != 0; i++) {
		uint32 c = wide[i];
		if (c >= 0xd800 && c <= 0xdbff && i + 1 < wide.length) {
			uint32 low = wide[i + 1];
			if (low >= 0xdc00 && low <= 0xdfff) {
				c = 0x10000 + ((c - 0xd800) << 10) + (low - 0xdc00);
				i++;
			}
		}
		len = utf8_append_codepoint (bytes, len, c);
	}
	bytes[len] = 0;
	bytes.length = len + 1;
	return (string) bytes;
}

public struct WideString {
	uint16[] _utf16;

	public WideString (string text) {
		_utf16 = utf8_to_utf16 (text);
	}

	public uint16* ptr {
		get { return _utf16; }
	}
}

public string window_text_get (void* hwnd, int max_chars = 256) {
	if (hwnd == null) {
		return "";
	}
	var buf = new uint16[max_chars];
	get_window_text (hwnd, buf, max_chars);
	return utf16_to_utf8 (buf);
}

public void window_text_set (void* hwnd, string text) {
	if (hwnd == null) {
		return;
	}
	uint16[] wide = utf8_to_utf16 (text);
	set_window_text (hwnd, wide);
}

}
