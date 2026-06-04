#ifndef VALA_WEBVIEW2_CAPTURE_SPIKE_H
#define VALA_WEBVIEW2_CAPTURE_SPIKE_H

#include <windows.h>

struct ICoreWebView2;
struct ICoreWebView2Controller;

#ifdef __cplusplus
extern "C" {
#endif

#define VALA_WEBVIEW2_WM_SPIKE_DONE (WM_APP + 1)

/* Call before host_create. Optional output_dir; use_wide_bounds widens put_Bounds before scroll. */
BOOL vala_webview2_host_set_capture_spike (LPCWSTR output_dir, BOOL use_wide_bounds);

/* After spike posts VALA_WEBVIEW2_WM_SPIKE_DONE: 1 ok, 0 not run, -1 failed. */
int vala_webview2_host_capture_spike_result (void);

/* Called from host plumbing when webview + controller are ready (not for app use). */
void vala_webview2_capture_spike_on_host_ready (
	struct ICoreWebView2 *webview,
	struct ICoreWebView2Controller *controller,
	HWND parent);

void vala_webview2_capture_spike_on_host_destroy (void);

#ifdef __cplusplus
}
#endif

#endif /* VALA_WEBVIEW2_CAPTURE_SPIKE_H */
