/* Phase 7i: WebView2 host using generated COM vapi + thin loader C. */

using Microsoft.Web.WebView2.Win32;
using Win32.Ui.WindowsAndMessaging;
using Win32.Foundation;

namespace Win32.Ui.WebView {

[CCode (cheader_filename = "webview2-loader.h", cname = "vala_webview2_loader_init")]
extern bool loader_init ();

[CCode (cheader_filename = "webview2-loader.h", cname = "vala_webview2_loader_create_environment")]
extern int loader_create_environment (
	ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler handler
);

[CCode (cheader_filename = "webview2-capture-spike.h", cname = "vala_webview2_capture_spike_on_host_ready")]
extern void capture_spike_on_host_ready (
	ICoreWebView2 webview,
	ICoreWebView2Controller controller,
	[CCode (type_id = "HWND")] void* parent
);

[CCode (cheader_filename = "webview2-capture-spike.h", cname = "vala_webview2_capture_spike_on_host_destroy")]
extern void capture_spike_on_host_destroy ();

private class HostState {
	public void* parent;
	public uint16* url;
	public ICoreWebView2Environment? environment;
	public ICoreWebView2Controller? controller;
	public ICoreWebView2? webview;
	public bool ready;
	public EnvironmentCompletedHandler? env_handler;
	public ControllerCompletedHandler? controller_handler;
}

private class EnvironmentCompletedHandler : ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler {
	HostState host;

	public EnvironmentCompletedHandler (HostState host) {
		this.host = host;
	}

	public int invoke (int error_code, ICoreWebView2Environment result) {
		if (error_code != 0 || result == null) {
			stderr.printf ("WebView2 environment failed: 0x%08x\n", (uint) error_code);
			return error_code;
		}
		host.environment = result;
		host.controller_handler = new ControllerCompletedHandler (host);
		return host.environment.create_core_web_view2controller (host.parent, host.controller_handler);
	}
}

private class ControllerCompletedHandler : ICoreWebView2CreateCoreWebView2ControllerCompletedHandler {
	HostState host;

	public ControllerCompletedHandler (HostState host) {
		this.host = host;
	}

	public int invoke (int error_code, ICoreWebView2Controller result) {
		ICoreWebView2? webview = null;

		if (error_code != 0 || result == null) {
			stderr.printf ("WebView2 controller failed: 0x%08x\n", (uint) error_code);
			return error_code;
		}

		host.controller = result;
		var hr = host.controller.get_core_web_view2 (out webview);
		if (hr != 0 || webview == null) {
			stderr.printf ("get_CoreWebView2 failed: 0x%08x\n", (uint) hr);
			return hr;
		}
		host.webview = webview;

		host.controller.put_bounds (client_rect (host.parent));

		capture_spike_on_host_ready (host.webview, host.controller, host.parent);

		if (host.url != null) {
			host.webview.navigate (host.url);
		}
		host.ready = true;
		return 0;
	}
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

[CCode (cname = "vala_webview2_host_create")]
public bool host_create (void* parent_hwnd, uint16* url) {
	if (parent_hwnd == null || url == null) {
		return false;
	}
	if (!loader_init ()) {
		return false;
	}

	g_host = new HostState () {
		parent = parent_hwnd,
		url = url,
	};
	g_host.env_handler = new EnvironmentCompletedHandler (g_host);
	var hr = loader_create_environment (g_host.env_handler);
	if (hr != 0) {
		stderr.printf ("CreateCoreWebView2EnvironmentWithOptions failed: 0x%08x\n", (uint) hr);
		g_host = null;
		return false;
	}
	return true;
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

public bool host_is_ready () {
	return g_host != null && g_host.ready;
}

}
