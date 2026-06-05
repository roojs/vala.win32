#ifndef VALA_WEBVIEW2_COM_GLUE_H
#define VALA_WEBVIEW2_COM_GLUE_H

#include <windows.h>

struct ICoreWebView2;
struct ICoreWebView2Controller;

#ifdef __cplusplus
extern "C" {
#endif

BOOL vala_webview2_com_begin_host (HWND parent, LPCWSTR url);

#ifdef __cplusplus
}
#endif

#endif /* VALA_WEBVIEW2_COM_GLUE_H */
