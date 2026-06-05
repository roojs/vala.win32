/* Phase 7i: WebView2 host glue — loader/com-glue C + minimal Vala surface.
 *
 * Layout: use set_bounds_xywh / create_with_xywh from ergo; set_bounds(Rect) and
 * on_size() are native-track (full client rect). Ergo owns x/y/width/height.
 *
 * Stack: Win32.WebView.navigate → Ui.WebView.navigate → webview_navigate (C) → Navigate (COM)
 *
 * Ergo API: src/win32-ergo-webview2.vala (Win32.WebView). */

using Microsoft.Web.WebView2.Win32;
using Win32.Ui;
using Win32.Ui.WindowsAndMessaging;
using Win32.Foundation;

namespace Win32.Ui.WebView {

const int STRING_BUF_CHARS = 2048;

[CCode (cheader_filename = "win32-ui-webview2-com-glue.h", cname = "vala_webview2_com_begin_host")]
extern bool com_begin_host (
	[CCode (type_id = "HWND")] void* parent,
	[CCode (type_id = "LPCWSTR")] uint16* url,
	Microsoft.Web.WebView2.Win32.Rect* bounds
);

[CCode (cheader_filename = "win32-ui-webview2-com-glue.h", cname = "vala_webview2_com_release_host")]
extern void com_release_host ();

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_controller_put_bounds")]
extern int controller_put_bounds (
	ICoreWebView2Controller controller,
	Microsoft.Web.WebView2.Win32.Rect* bounds
);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_navigate")]
extern int webview_navigate (
	ICoreWebView2 webview,
	[CCode (type_id = "LPCWSTR")] uint16* url
);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_navigate_to_string")]
extern int webview_navigate_to_string (
	ICoreWebView2 webview,
	[CCode (type_id = "LPCWSTR")] uint16* html
);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_reload")]
extern int webview_reload (ICoreWebView2 webview);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_stop")]
extern int webview_stop (ICoreWebView2 webview);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_go_back")]
extern int webview_go_back (ICoreWebView2 webview);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_go_forward")]
extern int webview_go_forward (ICoreWebView2 webview);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_post_web_message_as_json")]
extern int webview_post_web_message_as_json (
	ICoreWebView2 webview,
	[CCode (type_id = "LPCWSTR")] uint16* json
);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_execute_script")]
extern int webview_execute_script (
	ICoreWebView2 webview,
	[CCode (type_id = "LPCWSTR")] uint16* script
);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_get_can_go_back")]
extern int webview_get_can_go_back (ICoreWebView2 webview, bool* out);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_get_can_go_forward")]
extern int webview_get_can_go_forward (ICoreWebView2 webview, bool* out);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_copy_source")]
extern int webview_copy_source (
	ICoreWebView2 webview,
	[CCode (array_length = false)] uint16[] buf,
	size_t buf_chars
);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_webview_copy_document_title")]
extern int webview_copy_document_title (
	ICoreWebView2 webview,
	[CCode (array_length = false)] uint16[] buf,
	size_t buf_chars
);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_controller_put_is_visible")]
extern int controller_put_is_visible (ICoreWebView2Controller controller, bool visible);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_controller_get_is_visible")]
extern int controller_get_is_visible (ICoreWebView2Controller controller, bool* out);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_controller_put_zoom_factor")]
extern int controller_put_zoom_factor (ICoreWebView2Controller controller, double zoom);

[CCode (cheader_filename = "win32-ui-webview2-host-glue.h", cname = "vala_webview2_controller_get_zoom_factor")]
extern int controller_get_zoom_factor (ICoreWebView2Controller controller, double* out);

[Compact]
private struct HostState {
	public void* parent;
	public Microsoft.Web.WebView2.Win32.Rect bounds;
	public ICoreWebView2Controller? controller;
	public ICoreWebView2? webview;
	public WideString? pending_url;
	public bool ready;
}

private HostState? g_host;

private Microsoft.Web.WebView2.Win32.Rect rect_xywh (int x, int y, int width, int height) {
	return Microsoft.Web.WebView2.Win32.Rect () {
		left = x,
		top = y,
		right = x + width,
		bottom = y + height,
	};
}

private Microsoft.Web.WebView2.Win32.Rect client_rect (void* hwnd) {
	Win32.Foundation.Rect fr;
	get_client_rect (hwnd, out fr);
	return Microsoft.Web.WebView2.Win32.Rect () {
		left = fr.left,
		top = fr.top,
		right = fr.right,
		bottom = fr.bottom,
	};
}

private void apply_bounds () {
	if (g_host == null || g_host.controller == null) {
		return;
	}
	controller_put_bounds (g_host.controller, &g_host.bounds);
}

private void flush_pending_navigate () {
	if (g_host == null || !g_host.ready || g_host.webview == null || g_host.pending_url == null) {
		return;
	}
	var nav = webview_navigate (g_host.webview, g_host.pending_url.ptr);
	if (nav < 0) {
		stderr.printf ("WebView2 navigate failed: 0x%08x\n", (uint) nav);
	}
	g_host.pending_url = null;
}

private bool com_ok (int hr) {
	return hr >= 0;
}

[CCode (cname = "vala_webview2_host_finish_setup")]
public void finish_setup (
	ICoreWebView2Controller controller,
	ICoreWebView2 webview,
	[CCode (type_id = "HWND")] void* parent
) {
	if (g_host == null) {
		return;
	}
	g_host.controller = controller;
	g_host.webview = webview;
	g_host.parent = parent;
	g_host.ready = true;
	apply_bounds ();
	flush_pending_navigate ();
}

/** Ergo/bootstrap: parent client coordinates as x, y, width, height. */
[CCode (cname = "vala_webview2_host_create_with_xywh")]
public bool create_with_xywh (
	void* parent_hwnd,
	int x, int y, int width, int height,
	uint16* url
) {
	return create_with_bounds (parent_hwnd, rect_xywh (x, y, width, height), url);
}

/** Async bootstrap with bounds in parent client coordinates. url null skips initial navigate. */
[CCode (cname = "vala_webview2_host_create_with_bounds")]
public bool create_with_bounds (
	void* parent_hwnd,
	Microsoft.Web.WebView2.Win32.Rect bounds,
	uint16* url
) {
	if (parent_hwnd == null) {
		return false;
	}
	var st = HostState ();
	st.parent = parent_hwnd;
	st.bounds = bounds;
	g_host = st;
	return com_begin_host (parent_hwnd, url, &g_host.bounds);
}

/** Native Track A: bounds = parent client rect; navigates immediately. */
[CCode (cname = "vala_webview2_host_create")]
public bool create (void* parent_hwnd, uint16* url) {
	if (parent_hwnd == null || url == null) {
		return false;
	}
	return create_with_bounds (parent_hwnd, client_rect (parent_hwnd), url);
}

[CCode (cname = "vala_webview2_host_set_bounds_xywh")]
public void set_bounds_xywh (int x, int y, int width, int height) {
	set_bounds (rect_xywh (x, y, width, height));
}

[CCode (cname = "vala_webview2_host_set_bounds")]
public void set_bounds (Microsoft.Web.WebView2.Win32.Rect bounds) {
	if (g_host == null) {
		return;
	}
	g_host.bounds = bounds;
	if (g_host.ready) {
		apply_bounds ();
	}
}

/** ICoreWebView2::Navigate — queues until async controller setup completes. */
[CCode (cname = "vala_webview2_host_navigate")]
public bool navigate (string url) {
	if (g_host == null || url.length == 0) {
		return false;
	}
	g_host.pending_url = WideString (url);
	if (g_host.ready) {
		flush_pending_navigate ();
	}
	return true;
}

[CCode (cname = "vala_webview2_host_navigate_to_string")]
public bool navigate_to_string (string html) {
	if (g_host == null || !g_host.ready || g_host.webview == null || html.length == 0) {
		return false;
	}
	var wide = WideString (html);
	return com_ok (webview_navigate_to_string (g_host.webview, wide.ptr));
}

[CCode (cname = "vala_webview2_host_reload")]
public bool reload () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	return com_ok (webview_reload (g_host.webview));
}

[CCode (cname = "vala_webview2_host_stop")]
public bool stop () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	return com_ok (webview_stop (g_host.webview));
}

[CCode (cname = "vala_webview2_host_go_back")]
public bool go_back () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	return com_ok (webview_go_back (g_host.webview));
}

[CCode (cname = "vala_webview2_host_go_forward")]
public bool go_forward () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	return com_ok (webview_go_forward (g_host.webview));
}

[CCode (cname = "vala_webview2_host_execute_script")]
public bool execute_script (string js) {
	if (g_host == null || !g_host.ready || g_host.webview == null || js.length == 0) {
		return false;
	}
	var wide = WideString (js);
	return com_ok (webview_execute_script (g_host.webview, wide.ptr));
}

[CCode (cname = "vala_webview2_host_post_web_message_as_json")]
public bool post_web_message_as_json (string json) {
	if (g_host == null || !g_host.ready || g_host.webview == null || json.length == 0) {
		return false;
	}
	var wide = WideString (json);
	return com_ok (webview_post_web_message_as_json (g_host.webview, wide.ptr));
}

[CCode (cname = "vala_webview2_host_get_source")]
public string get_source () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return "";
	}
	var buf = new uint16[STRING_BUF_CHARS];
	if (!com_ok (webview_copy_source (g_host.webview, buf, STRING_BUF_CHARS))) {
		return "";
	}
	return utf16_buffer_to_string (buf);
}

[CCode (cname = "vala_webview2_host_get_can_go_back")]
public bool get_can_go_back () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	bool val = false;
	if (!com_ok (webview_get_can_go_back (g_host.webview, &val))) {
		return false;
	}
	return val;
}

[CCode (cname = "vala_webview2_host_get_can_go_forward")]
public bool get_can_go_forward () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	bool val = false;
	if (!com_ok (webview_get_can_go_forward (g_host.webview, &val))) {
		return false;
	}
	return val;
}

[CCode (cname = "vala_webview2_host_get_document_title")]
public string get_document_title () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return "";
	}
	var buf = new uint16[STRING_BUF_CHARS];
	if (!com_ok (webview_copy_document_title (g_host.webview, buf, STRING_BUF_CHARS))) {
		return "";
	}
	return utf16_buffer_to_string (buf);
}

[CCode (cname = "vala_webview2_host_put_is_visible")]
public bool put_is_visible (bool visible) {
	if (g_host == null || !g_host.ready || g_host.controller == null) {
		return false;
	}
	return com_ok (controller_put_is_visible (g_host.controller, visible));
}

[CCode (cname = "vala_webview2_host_get_is_visible")]
public bool get_is_visible () {
	if (g_host == null || !g_host.ready || g_host.controller == null) {
		return false;
	}
	bool val = false;
	if (!com_ok (controller_get_is_visible (g_host.controller, &val))) {
		return false;
	}
	return val;
}

[CCode (cname = "vala_webview2_host_put_zoom_factor")]
public bool put_zoom_factor (double zoom) {
	if (g_host == null || !g_host.ready || g_host.controller == null) {
		return false;
	}
	return com_ok (controller_put_zoom_factor (g_host.controller, zoom));
}

[CCode (cname = "vala_webview2_host_get_zoom_factor")]
public double get_zoom_factor () {
	if (g_host == null || !g_host.ready || g_host.controller == null) {
		return 1.0;
	}
	double val = 1.0;
	if (!com_ok (controller_get_zoom_factor (g_host.controller, &val))) {
		return 1.0;
	}
	return val;
}

/** Native Track A: resize webview to full parent client area (not used by ergo layout). */
[CCode (cname = "vala_webview2_host_on_size")]
public void on_size (void* parent_hwnd) {
	if (g_host == null || g_host.controller == null || parent_hwnd != g_host.parent) {
		return;
	}
	g_host.bounds = client_rect (parent_hwnd);
	apply_bounds ();
}

[CCode (cname = "vala_webview2_host_destroy")]
public void destroy () {
	com_release_host ();
	g_host = null;
}

[CCode (cname = "vala_webview2_host_is_ready")]
public bool is_ready () {
	return g_host != null && g_host.ready;
}

}
