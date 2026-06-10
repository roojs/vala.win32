/* C entry points for WinUI3 demos (implemented in C++/WinRT). */

#ifndef WIN32_UI_WINUI3_HOST_H
#define WIN32_UI_WINUI3_HOST_H

#ifdef __cplusplus
extern "C" {
#endif

/* Returns 0 on success, HRESULT as int on failure. Blocks until the app exits. */
int winui3_run_hello_window (void);
int winui3_run_widgets_demo (void);

#ifdef __cplusplus
}
#endif

#endif
