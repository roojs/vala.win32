/* Phase 7i: WebView2 host — generated COM vapi + loader/com-glue C. */

using Microsoft.Web.WebView2.Win32;
using Win32.Ui.WindowsAndMessaging;
using Win32.Foundation;

namespace Win32.Ui.WebView {

[CCode (cheader_filename = "webview2-com-glue.h", cname = "vala_webview2_com_begin_host")]
extern bool com_begin_host (
	[CCode (type_id = "HWND")] void* parent,
	uint16* url
);

[CCode (cheader_filename = "webview2-capture-spike.h", cname = "vala_webview2_capture_spike_on_host_ready")]
extern void capture_spike_on_host_ready (
	ICoreWebView2 webview,
	ICoreWebView2Controller controller,
	[CCode (type_id = "HWND")] void* parent
);

[CCode (cheader_filename = "webview2-capture-spike.h", cname = "vala_webview2_capture_spike_on_host_destroy")]
extern void capture_spike_on_host_destroy ();

[CCode (cname = "VALA_WEBVIEW2_WM_SPIKE_DONE")]
public const uint SPIKE_DONE_MESSAGE;

[CCode (cname = "vala_webview2_host_set_capture_spike")]
public extern bool host_set_capture_spike (void* output_dir, bool use_wide_bounds);

[CCode (cname = "vala_webview2_host_capture_spike_result")]
public extern int host_capture_spike_result ();

private class HostState {
	public void* parent;
	public uint16* url;
	public ICoreWebView2Controller? controller;
	public ICoreWebView2? webview;
	public bool ready;
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

private HostState? g_host;

[CCode (cname = "vala_webview2_host_finish_setup")]
public void host_finish_setup (
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
	g_host.controller.put_bounds (client_rect (parent));
	capture_spike_on_host_ready (g_host.webview, g_host.controller, parent);
	if (g_host.url != null) {
		g_host.webview.navigate (g_host.url);
	}
	g_host.ready = true;
}

[CCode (cname = "vala_webview2_host_create")]
public bool host_create (void* parent_hwnd, uint16* url) {
	if (parent_hwnd == null || url == null) {
		return false;
	}
	g_host = new HostState () {
		parent = parent_hwnd,
		url = url,
	};
	return com_begin_host (parent_hwnd, url);
}

[CCode (cname = "vala_webview2_host_on_size")]
public void host_on_size (void* parent_hwnd) {
	if (g_host == null || g_host.controller == null || parent_hwnd != g_host.parent) {
		return;
	}
	g_host.controller.put_bounds (client_rect (parent_hwnd));
}

[CCode (cname = "vala_webview2_host_destroy")]
public void host_destroy () {
	capture_spike_on_host_destroy ();
	if (g_host != null && g_host.controller != null) {
		g_host.controller.close ();
	}
	g_host = null;
}

[CCode (cname = "vala_webview2_host_is_ready")]
public bool host_is_ready () {
	return g_host != null && g_host.ready;
}

}
