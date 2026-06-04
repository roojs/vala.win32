/* Phase 7b: minimal WebView2 host bootstrap (loader + env + controller). */

#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <objbase.h>
#include <initguid.h>
#include <stdio.h>

#include "webview2-plumbing.h"
#include "webview2-capture-spike.h"
#include "WebView2.h"

typedef HRESULT (STDMETHODCALLTYPE *PFN_CreateCoreWebView2EnvironmentWithOptions)(
	PCWSTR browserExecutableFolder,
	PCWSTR userDataFolder,
	ICoreWebView2EnvironmentOptions *environmentOptions,
	ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *environmentCreatedHandler);

typedef struct WebView2HostState {
	HWND parent;
	wchar_t url[2048];
	ICoreWebView2Environment *environment;
	ICoreWebView2Controller *controller;
	ICoreWebView2 *webview;
	BOOL ready;
} WebView2HostState;

static WebView2HostState g_state;
static HMODULE g_loader_module;
static PFN_CreateCoreWebView2EnvironmentWithOptions g_create_env_with_options;

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
	ControllerCompletedHandler *self = (ControllerCompletedHandler *) This;
	RECT bounds;
	HRESULT hr;

	(void) self;
	if (FAILED (error_code) || controller == NULL) {
		fprintf (stderr, "WebView2 controller failed: 0x%08lx\n", (unsigned long) error_code);
		return error_code;
	}

	g_state.controller = controller;
	ICoreWebView2Controller_AddRef (g_state.controller);
	hr = ICoreWebView2Controller_get_CoreWebView2 (g_state.controller, &g_state.webview);
	if (FAILED (hr) || g_state.webview == NULL) {
		fprintf (stderr, "get_CoreWebView2 failed: 0x%08lx\n", (unsigned long) hr);
		return hr;
	}

	GetClientRect (g_state.parent, &bounds);
	ICoreWebView2Controller_put_Bounds (g_state.controller, bounds);
	vala_webview2_capture_spike_on_host_ready (g_state.webview, g_state.controller, g_state.parent);
	ICoreWebView2_Navigate (g_state.webview, g_state.url);
	g_state.ready = TRUE;
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

	g_state.environment = environment;
	ICoreWebView2Environment_AddRef (g_state.environment);

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
		g_state.environment,
		g_state.parent,
		&controller_handler->iface);
	ICoreWebView2CreateCoreWebView2ControllerCompletedHandler_Release (&controller_handler->iface);
	return hr;
}

static BOOL load_webview2_loader (void)
{
	if (g_create_env_with_options != NULL) {
		return TRUE;
	}

	g_loader_module = LoadLibraryW (L"WebView2Loader.dll");
	if (g_loader_module == NULL) {
		fprintf (stderr, "LoadLibrary WebView2Loader.dll failed: %lu\n", (unsigned long) GetLastError ());
		return FALSE;
	}

	g_create_env_with_options = (PFN_CreateCoreWebView2EnvironmentWithOptions) (void *) GetProcAddress (
		g_loader_module,
		"CreateCoreWebView2EnvironmentWithOptions");
	if (g_create_env_with_options == NULL) {
		fprintf (stderr, "GetProcAddress CreateCoreWebView2EnvironmentWithOptions failed\n");
		FreeLibrary (g_loader_module);
		g_loader_module = NULL;
		return FALSE;
	}
	return TRUE;
}

BOOL vala_webview2_host_create (HWND parent, LPCWSTR url)
{
	EnvCompletedHandler *env_handler;
	HRESULT hr;

	if (parent == NULL || url == NULL) {
		return FALSE;
	}

	ZeroMemory (&g_state, sizeof (g_state));
	g_state.parent = parent;
	wcsncpy (g_state.url, url, (sizeof (g_state.url) / sizeof (g_state.url[0])) - 1);
	g_state.url[(sizeof (g_state.url) / sizeof (g_state.url[0])) - 1] = L'\0';

	if (!load_webview2_loader ()) {
		return FALSE;
	}

	hr = CoInitializeEx (NULL, COINIT_APARTMENTTHREADED);
	if (FAILED (hr) && hr != RPC_E_CHANGED_MODE) {
		fprintf (stderr, "CoInitializeEx failed: 0x%08lx\n", (unsigned long) hr);
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

	hr = g_create_env_with_options (NULL, NULL, NULL, &env_handler->iface);
	ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler_Release (&env_handler->iface);
	if (FAILED (hr)) {
		fprintf (stderr, "CreateCoreWebView2EnvironmentWithOptions failed: 0x%08lx\n", (unsigned long) hr);
		return FALSE;
	}
	return TRUE;
}

void vala_webview2_host_on_size (HWND parent)
{
	RECT bounds;

	if (g_state.controller == NULL || parent != g_state.parent) {
		return;
	}
	GetClientRect (parent, &bounds);
	ICoreWebView2Controller_put_Bounds (g_state.controller, bounds);
}

void vala_webview2_host_destroy (void)
{
	vala_webview2_capture_spike_on_host_destroy ();
	if (g_state.webview != NULL) {
		ICoreWebView2_Release (g_state.webview);
		g_state.webview = NULL;
	}
	if (g_state.controller != NULL) {
		ICoreWebView2Controller_Release (g_state.controller);
		g_state.controller = NULL;
	}
	if (g_state.environment != NULL) {
		ICoreWebView2Environment_Release (g_state.environment);
		g_state.environment = NULL;
	}
	g_state.ready = FALSE;
}

BOOL vala_webview2_host_is_ready (void)
{
	return g_state.ready;
}
