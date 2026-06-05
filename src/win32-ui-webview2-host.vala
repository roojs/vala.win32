/* Phase 7i: WebView2 host glue — loader/com-glue C + Vala surface on generated vapi.
 *
 * COM method calls use win32-ui-webview2.vapi (ICoreWebView2*, ICoreWebView2Controller*).
 * Hand C stays in win32-ui-webview2-{loader,com-glue}.c only (async vtables + bootstrap).
 *
 * Layout: ergo uses create_with_xywh / set_bounds_xywh; on_size() is native Track A only.
 * Ergo API: src/win32-ergo-webview2.vala (Win32.WebView). */

using Microsoft.Web.WebView2.Win32;
using Win32.Ui;
using Win32.Ui.WindowsAndMessaging;
using Win32.Foundation;

namespace Win32.Ui.WebView {

[CCode (cheader_filename = "win32-ui-webview2-com-glue.h", cname = "vala_webview2_com_begin_host")]
extern bool com_begin_host (
	[CCode (type_id = "HWND")] void* parent,
	[CCode (type_id = "LPCWSTR")] uint16* url,
	Microsoft.Web.WebView2.Win32.Rect* bounds
);

[CCode (cheader_filename = "win32-ui-webview2-com-glue.h", cname = "vala_webview2_com_release_host")]
extern void com_release_host ();

[CCode (cheader_filename = "objbase.h", cname = "CoTaskMemFree")]
extern void co_task_mem_free (void* ptr);

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

private bool com_ok (int hr) {
	return hr >= 0;
}

private string take_com_string (uint16* com_str) {
	if (com_str == null) {
		return "";
	}
	var s = utf16_ptr_to_string (com_str);
	co_task_mem_free (com_str);
	return s;
}

private string utf16_ptr_to_string (uint16* wide) {
	if (wide == null) {
		return "";
	}
	int len = 0;
	while (wide[len] != 0) {
		len++;
	}
	var buf = new uint16[len + 1];
	for (int i = 0; i <= len; i++) {
		buf[i] = wide[i];
	}
	return utf16_buffer_to_string (buf);
}

private void apply_bounds () {
	if (g_host == null || g_host.controller == null) {
		return;
	}
	var hr = g_host.controller.put_bounds (g_host.bounds);
	if (!com_ok (hr)) {
		stderr.printf ("WebView2 put_bounds failed: 0x%08x\n", (uint) hr);
	}
}

private void flush_pending_navigate () {
	if (g_host == null || !g_host.ready || g_host.webview == null || g_host.pending_url == null) {
		return;
	}
	var nav = g_host.webview.navigate (g_host.pending_url.ptr);
	if (!com_ok (nav)) {
		stderr.printf ("WebView2 navigate failed: 0x%08x\n", (uint) nav);
	}
	g_host.pending_url = null;
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

[CCode (cname = "vala_webview2_host_create_with_xywh")]
public bool create_with_xywh (
	void* parent_hwnd,
	int x, int y, int width, int height,
	uint16* url
) {
	return create_with_bounds (parent_hwnd, rect_xywh (x, y, width, height), url);
}

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
	return com_ok (g_host.webview.navigate_to_string (WideString (html).ptr));
}

[CCode (cname = "vala_webview2_host_reload")]
public bool reload () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	return com_ok (g_host.webview.reload ());
}

[CCode (cname = "vala_webview2_host_stop")]
public bool stop () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	return com_ok (g_host.webview.stop ());
}

[CCode (cname = "vala_webview2_host_go_back")]
public bool go_back () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	return com_ok (g_host.webview.go_back ());
}

[CCode (cname = "vala_webview2_host_go_forward")]
public bool go_forward () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	return com_ok (g_host.webview.go_forward ());
}

[CCode (cname = "vala_webview2_host_execute_script")]
public bool execute_script (string js) {
	/* vapi needs ICoreWebView2ExecuteScriptCompletedHandler — wiring deferred. */
	if (g_host == null || !g_host.ready || g_host.webview == null || js.length == 0) {
		return false;
	}
	return false;
}

[CCode (cname = "vala_webview2_host_post_web_message_as_json")]
public bool post_web_message_as_json (string json) {
	if (g_host == null || !g_host.ready || g_host.webview == null || json.length == 0) {
		return false;
	}
	return com_ok (g_host.webview.post_web_message_as_json (WideString (json).ptr));
}

[CCode (cname = "vala_webview2_host_get_source")]
public string get_source () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return "";
	}
	uint16* uri = null;
	if (!com_ok (g_host.webview.get_source (out uri))) {
		return "";
	}
	return take_com_string (uri);
}

[CCode (cname = "vala_webview2_host_get_can_go_back")]
public bool get_can_go_back () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	int val = 0;
	if (!com_ok (g_host.webview.get_can_go_back (out val))) {
		return false;
	}
	return val != 0;
}

[CCode (cname = "vala_webview2_host_get_can_go_forward")]
public bool get_can_go_forward () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return false;
	}
	int val = 0;
	if (!com_ok (g_host.webview.get_can_go_forward (out val))) {
		return false;
	}
	return val != 0;
}

[CCode (cname = "vala_webview2_host_get_document_title")]
public string get_document_title () {
	if (g_host == null || !g_host.ready || g_host.webview == null) {
		return "";
	}
	uint16* title = null;
	if (!com_ok (g_host.webview.get_document_title (out title))) {
		return "";
	}
	return take_com_string (title);
}

[CCode (cname = "vala_webview2_host_put_is_visible")]
public bool put_is_visible (bool visible) {
	if (g_host == null || !g_host.ready || g_host.controller == null) {
		return false;
	}
	return com_ok (g_host.controller.put_is_visible (visible ? 1 : 0));
}

[CCode (cname = "vala_webview2_host_get_is_visible")]
public bool get_is_visible () {
	if (g_host == null || !g_host.ready || g_host.controller == null) {
		return false;
	}
	int val = 0;
	if (!com_ok (g_host.controller.get_is_visible (out val))) {
		return false;
	}
	return val != 0;
}

[CCode (cname = "vala_webview2_host_put_zoom_factor")]
public bool put_zoom_factor (double zoom) {
	if (g_host == null || !g_host.ready || g_host.controller == null) {
		return false;
	}
	return com_ok (g_host.controller.put_zoom_factor (zoom));
}

[CCode (cname = "vala_webview2_host_get_zoom_factor")]
public double get_zoom_factor () {
	if (g_host == null || !g_host.ready || g_host.controller == null) {
		return 1.0;
	}
	double val = 1.0;
	if (!com_ok (g_host.controller.get_zoom_factor (out val))) {
		return 1.0;
	}
	return val;
}

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
