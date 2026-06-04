#ifndef VALA_WEBVIEW2_PLUMBING_H
#define VALA_WEBVIEW2_PLUMBING_H

#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Initialize COM and start async WebView2 host inside parent HWND. */
BOOL vala_webview2_host_create (HWND parent, LPCWSTR url);

/* Resize WebView2 bounds to parent client area (call from WM_SIZE). */
void vala_webview2_host_on_size (HWND parent);

/* Release controller/webview (optional; process exit also tears down). */
void vala_webview2_host_destroy (void);

/* TRUE after controller completed handler finished setup. */
BOOL vala_webview2_host_is_ready (void);

#ifdef __cplusplus
}
#endif

#endif /* VALA_WEBVIEW2_PLUMBING_H */
