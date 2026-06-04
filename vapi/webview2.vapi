/* Phase 7b: narrow C plumbing API for WebView2 host (not full SDK surface). */

[CCode (cheader_filename = "webview2-plumbing.h", lower_case_cprefix = "vala_webview2_", gir_namespace = "WebView2", gir_version = "1.0")]
namespace WebView2.Plumbing {

[CCode (cname = "vala_webview2_host_create")]
public bool host_create (void* parent_hwnd, uint16* url);

[CCode (cname = "vala_webview2_host_on_size")]
public void host_on_size (void* parent_hwnd);

[CCode (cname = "vala_webview2_host_destroy")]
public void host_destroy ();

[CCode (cname = "vala_webview2_host_is_ready")]
public bool host_is_ready ();

}
