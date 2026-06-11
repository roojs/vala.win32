/* C entry point for WinUI3 hello window (implemented in C++/WinRT). */

#ifndef WIN32_UI_WINUI3_HOST_H
#define WIN32_UI_WINUI3_HOST_H

#ifdef __cplusplus
extern "C" {
#endif

/* Returns 0 on success, negative HRESULT on failure. Blocks until the window closes. */
int winui3_run_hello_window (void);

#ifdef __cplusplus
}
#endif

#endif
