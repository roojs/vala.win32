/* Async COM completed handlers; host logic continues in Vala (Phase 7i). */

#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>

#include "webview2-com-glue.h"
#include "webview2-loader.h"
#include "WebView2.h"

void vala_webview2_host_finish_setup (
	ICoreWebView2Controller *controller,
	ICoreWebView2 *webview,
	HWND parent);

typedef struct WebView2GlueState {
	HWND parent;
	wchar_t url[2048];
} WebView2GlueState;

static WebView2GlueState g_glue;

typedef struct EnvCompletedHandler {
	ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler iface;
	ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVtbl vtbl;
	LONG ref_count;
} EnvCompletedHandler;

typedef struct ControllerCompletedHandler {
	ICoreWebView2CreateCoreWebView2ControllerCompletedHandler iface;
	ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl vtbl;
	LONG ref_count;
} ControllerCompletedHandler;

static HRESULT STDMETHODCALLTYPE env_handler_qi (
	ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *This,
	REFIID riid,
	void **ppv)
{
	if (IsEqualIID (riid, &IID_IUnknown)
	    || IsEqualIID (riid, &IID_ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler)) {
		*ppv = This;
		ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler_AddRef (This);
		return S_OK;
	}
	*ppv = NULL;
	return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE env_handler_addref (
	ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *This)
{
	EnvCompletedHandler *self = (EnvCompletedHandler *) This;
	return (ULONG) InterlockedIncrement (&self->ref_count);
}

static ULONG STDMETHODCALLTYPE env_handler_release (
	ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *This)
{
	EnvCompletedHandler *self = (EnvCompletedHandler *) This;
	LONG count = InterlockedDecrement (&self->ref_count);
	if (count == 0) {
		CoTaskMemFree (self);
	}
	return (ULONG) count;
}

static HRESULT STDMETHODCALLTYPE controller_handler_qi (
	ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *This,
	REFIID riid,
	void **ppv)
{
	if (IsEqualIID (riid, &IID_IUnknown)
	    || IsEqualIID (riid, &IID_ICoreWebView2CreateCoreWebView2ControllerCompletedHandler)) {
		*ppv = This;
		ICoreWebView2CreateCoreWebView2ControllerCompletedHandler_AddRef (This);
		return S_OK;
	}
	*ppv = NULL;
	return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE controller_handler_addref (
	ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *This)
{
	ControllerCompletedHandler *self = (ControllerCompletedHandler *) This;
	return (ULONG) InterlockedIncrement (&self->ref_count);
}

static ULONG STDMETHODCALLTYPE controller_handler_release (
	ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *This)
{
	ControllerCompletedHandler *self = (ControllerCompletedHandler *) This;
	LONG count = InterlockedDecrement (&self->ref_count);
	if (count == 0) {
		CoTaskMemFree (self);
	}
	return (ULONG) count;
}

static HRESULT STDMETHODCALLTYPE controller_handler_invoke (
	ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *This,
	HRESULT error_code,
	ICoreWebView2Controller *controller)
{
	ICoreWebView2 *webview = NULL;
	HRESULT hr;

	(void) This;
	if (FAILED (error_code) || controller == NULL) {
		fprintf (stderr, "WebView2 controller failed: 0x%08lx\n", (unsigned long) error_code);
		return error_code;
	}

	hr = ICoreWebView2Controller_get_CoreWebView2 (controller, &webview);
	if (FAILED (hr) || webview == NULL) {
		fprintf (stderr, "get_CoreWebView2 failed: 0x%08lx\n", (unsigned long) hr);
		return hr;
	}

	vala_webview2_host_finish_setup (controller, webview, g_glue.parent);
	return S_OK;
}

static HRESULT STDMETHODCALLTYPE env_handler_invoke (
	ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *This,
	HRESULT error_code,
	ICoreWebView2Environment *environment)
{
	EnvCompletedHandler *self = (EnvCompletedHandler *) This;
	ControllerCompletedHandler *controller_handler;
	HRESULT hr;

	(void) self;
	if (FAILED (error_code) || environment == NULL) {
		fprintf (stderr, "WebView2 environment failed: 0x%08lx\n", (unsigned long) error_code);
		return error_code;
	}

	controller_handler = (ControllerCompletedHandler *) CoTaskMemAlloc (sizeof (ControllerCompletedHandler));
	if (controller_handler == NULL) {
		return E_OUTOFMEMORY;
	}
	ZeroMemory (controller_handler, sizeof (*controller_handler));
	controller_handler->iface.lpVtbl = &controller_handler->vtbl;
	controller_handler->vtbl.QueryInterface = controller_handler_qi;
	controller_handler->vtbl.AddRef = controller_handler_addref;
	controller_handler->vtbl.Release = controller_handler_release;
	controller_handler->vtbl.Invoke = controller_handler_invoke;
	controller_handler->ref_count = 1;

	hr = ICoreWebView2Environment_CreateCoreWebView2Controller (
		environment,
		g_glue.parent,
		&controller_handler->iface);
	ICoreWebView2CreateCoreWebView2ControllerCompletedHandler_Release (&controller_handler->iface);
	return hr;
}

BOOL vala_webview2_com_begin_host (HWND parent, LPCWSTR url)
{
	EnvCompletedHandler *env_handler;
	HRESULT hr;

	if (parent == NULL || url == NULL) {
		return FALSE;
	}

	ZeroMemory (&g_glue, sizeof (g_glue));
	g_glue.parent = parent;
	wcsncpy (g_glue.url, url, (sizeof (g_glue.url) / sizeof (g_glue.url[0])) - 1);
	g_glue.url[(sizeof (g_glue.url) / sizeof (g_glue.url[0])) - 1] = L'\0';

	if (!vala_webview2_loader_init ()) {
		return FALSE;
	}

	env_handler = (EnvCompletedHandler *) CoTaskMemAlloc (sizeof (EnvCompletedHandler));
	if (env_handler == NULL) {
		return FALSE;
	}
	ZeroMemory (env_handler, sizeof (*env_handler));
	env_handler->iface.lpVtbl = &env_handler->vtbl;
	env_handler->vtbl.QueryInterface = env_handler_qi;
	env_handler->vtbl.AddRef = env_handler_addref;
	env_handler->vtbl.Release = env_handler_release;
	env_handler->vtbl.Invoke = env_handler_invoke;
	env_handler->ref_count = 1;

	hr = vala_webview2_loader_create_environment (&env_handler->iface);
	ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler_Release (&env_handler->iface);
	if (FAILED (hr)) {
		fprintf (stderr, "CreateCoreWebView2EnvironmentWithOptions failed: 0x%08lx\n", (unsigned long) hr);
		return FALSE;
	}
	return TRUE;
}
