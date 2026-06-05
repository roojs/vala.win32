/* Phase 7i: WebView2 glue — hand host shell(async bootstrap, layout, shared helpers).
 *
 * Sync glue methods: generated/win32-ui-webview2-host-glue.vala(from ergo_native_map).
 * Ergo: src/win32-ergo-webview2.vala → Win32.WebView. Hand C: loader + com-glue only. */

using Microsoft.Web.WebView2.Win32;
using Win32.Ui;
using Win32.Ui.WindowsAndMessaging;
using Win32.Foundation;

namespace Win32.Ui.WebView {

[CCode(cheader_filename = "win32-ui-webview2-com-glue.h", cname = "vala_webview2_com_begin_host")]
extern bool com_begin_host(
	[CCode(type_id = "HWND")] void* parent,
	[CCode(type_id = "LPCWSTR")] uint16* url,
	Microsoft.Web.WebView2.Win32.Rect* bounds
);

[CCode(cheader_filename = "win32-ui-webview2-com-glue.h", cname = "vala_webview2_com_release_host")]
extern void com_release_host();

[CCode(cheader_filename = "objbase.h", cname = "CoTaskMemFree")]
extern void co_task_mem_free(void* ptr);

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

private Microsoft.Web.WebView2.Win32.Rect rect_xywh(int x, int y, int width, int height) {
	return Microsoft.Web.WebView2.Win32.Rect() {
		left = x,
		top = y,
		right = x + width,
		bottom = y + height,
	};
}

private Microsoft.Web.WebView2.Win32.Rect client_rect(void* hwnd) {
	Win32.Foundation.Rect fr;
	get_client_rect(hwnd, out fr);
	return Microsoft.Web.WebView2.Win32.Rect() {
		left = fr.left,
		top = fr.top,
		right = fr.right,
		bottom = fr.bottom,
	};
}

private bool com_ok(int hr) {
	return hr >= 0;
}

private bool webview_ready() {
	return g_host != null && g_host.ready && g_host.webview != null;
}

private bool controller_ready() {
	return g_host != null && g_host.ready && g_host.controller != null;
}

private string take_com_string(uint16* com_str) {
	if (com_str == null) {
		return "";
	}
	var s = utf16_ptr_to_string(com_str);
	co_task_mem_free(com_str);
	return s;
}

private string utf16_ptr_to_string(uint16* wide) {
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
	return utf16_buffer_to_string(buf);
}

private void apply_bounds() {
	if (g_host == null || g_host.controller == null) {
		return;
	}
	var hr = com_controller_put_bounds(g_host.controller, g_host.bounds);
	if (!com_ok(hr)) {
		stderr.printf("WebView2 put_bounds failed: 0x%08x\n", (uint) hr);
	}
}

private void flush_pending_navigate() {
	if (g_host == null || !g_host.ready || g_host.webview == null || g_host.pending_url == null) {
		return;
	}
	var nav = com_webview_navigate(g_host.webview, g_host.pending_url.ptr);
	if (!com_ok(nav)) {
		stderr.printf("WebView2 navigate failed: 0x%08x\n", (uint) nav);
	}
	g_host.pending_url = null;
}

[CCode(cname = "vala_webview2_host_finish_setup")]
public void finish_setup(
	ICoreWebView2Controller controller,
	ICoreWebView2 webview,
	[CCode(type_id = "HWND")] void* parent
) {
	if (g_host == null) {
		return;
	}
	g_host.controller = controller;
	g_host.webview = webview;
	g_host.parent = parent;
	g_host.ready = true;
	apply_bounds();
	flush_pending_navigate();
}

[CCode(cname = "vala_webview2_host_create_with_xywh")]
public bool create_with_xywh(
	void* parent_hwnd,
	int x, int y, int width, int height,
	uint16* url
) {
	return create_with_bounds(parent_hwnd, rect_xywh(x, y, width, height), url);
}

[CCode(cname = "vala_webview2_host_create_with_bounds")]
public bool create_with_bounds(
	void* parent_hwnd,
	Microsoft.Web.WebView2.Win32.Rect bounds,
	uint16* url
) {
	if (parent_hwnd == null) {
		return false;
	}
	var st = HostState();
	st.parent = parent_hwnd;
	st.bounds = bounds;
	g_host = st;
	return com_begin_host(parent_hwnd, url, &g_host.bounds);
}

[CCode(cname = "vala_webview2_host_create")]
public bool create(void* parent_hwnd, uint16* url) {
	if (parent_hwnd == null || url == null) {
		return false;
	}
	return create_with_bounds(parent_hwnd, client_rect(parent_hwnd), url);
}

[CCode(cname = "vala_webview2_host_set_bounds_xywh")]
public void set_bounds_xywh(int x, int y, int width, int height) {
	set_bounds(rect_xywh(x, y, width, height));
}

[CCode(cname = "vala_webview2_host_set_bounds")]
public void set_bounds(Microsoft.Web.WebView2.Win32.Rect bounds) {
	if (g_host == null) {
		return;
	}
	g_host.bounds = bounds;
	if (g_host.ready) {
		apply_bounds();
	}
}

[CCode(cname = "vala_webview2_host_navigate")]
public bool navigate(string url) {
	if (g_host == null || url.length == 0) {
		return false;
	}
	g_host.pending_url = WideString(url);
	if (g_host.ready) {
		flush_pending_navigate();
	}
	return true;
}

[CCode(cname = "vala_webview2_host_on_size")]
public void on_size(void* parent_hwnd) {
	if (g_host == null || g_host.controller == null || parent_hwnd != g_host.parent) {
		return;
	}
	g_host.bounds = client_rect(parent_hwnd);
	apply_bounds();
}

[CCode(cname = "vala_webview2_host_destroy")]
public void destroy() {
	com_release_host();
	g_host = null;
}

[CCode(cname = "vala_webview2_host_is_ready")]
public bool is_ready() {
	return g_host != null && g_host.ready;
}

}