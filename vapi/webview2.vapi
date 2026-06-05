/* Phase 7i: host API (Vala impl in src/webview2-host.vala) + capture spike C hooks. */

[CCode (cheader_filename = "webview2-capture-spike.h", lower_case_cprefix = "vala_webview2_", gir_namespace = "Win32UiWebView", gir_version = "1.0")]
namespace Win32.Ui.WebView {

[CCode (cname = "vala_webview2_host_create")]
public bool host_create (void* parent_hwnd, uint16* url);

[CCode (cname = "vala_webview2_host_on_size")]
public void host_on_size (void* parent_hwnd);

[CCode (cname = "vala_webview2_host_destroy")]
public void host_destroy ();

[CCode (cname = "vala_webview2_host_is_ready")]
public bool host_is_ready ();

[CCode (cname = "VALA_WEBVIEW2_WM_SPIKE_DONE")]
public const uint SPIKE_DONE_MESSAGE;

[CCode (cname = "vala_webview2_host_set_capture_spike")]
public bool host_set_capture_spike (void* output_dir, bool use_wide_bounds);

[CCode (cname = "vala_webview2_host_capture_spike_result")]
public int host_capture_spike_result ();

}
