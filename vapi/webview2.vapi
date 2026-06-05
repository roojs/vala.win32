/* Phase 7g capture spike C hooks (host API is Vala: src/webview2-host.vala). */

[CCode (cheader_filename = "webview2-capture-spike.h", lower_case_cprefix = "vala_webview2_", gir_namespace = "Win32UiWebView", gir_version = "1.0")]
namespace Win32.Ui.WebView {

[CCode (cname = "VALA_WEBVIEW2_WM_SPIKE_DONE")]
public const uint SPIKE_DONE_MESSAGE;

[CCode (cname = "vala_webview2_host_set_capture_spike")]
public extern bool host_set_capture_spike (void* output_dir, bool use_wide_bounds);

[CCode (cname = "vala_webview2_host_capture_spike_result")]
public extern int host_capture_spike_result ();

}
