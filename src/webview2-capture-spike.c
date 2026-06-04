/* Phase 7g: one-off capture probe (scroll + CapturePreview). Not part of the binding surface. */

#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <objbase.h>
#include <stdio.h>
#include <shlwapi.h>

#include "webview2-capture-spike.h"
#include "WebView2.h"

typedef struct CaptureSpikeState {
	BOOL enabled;
	BOOL wide_bounds;
	BOOL started;
	int result;
	wchar_t output_dir[MAX_PATH];
	HWND parent;
	ICoreWebView2 *webview;
	ICoreWebView2Controller *controller;
	IStream *stream;
} CaptureSpikeState;

static CaptureSpikeState g_spike;

static const wchar_t g_js_scroll_bottom[] =
	L"(function(){var h=Math.max(document.body?document.body.scrollHeight:0,document.documentElement?document.documentElement.scrollHeight:0);window.scrollTo(0,h);return String(h);})();";
static const wchar_t g_js_scroll_top[] = L"window.scrollTo(0,0);\"ok\";";

static void spike_finish (int result)
{
	g_spike.result = result;
	if (g_spike.parent != NULL) {
		PostMessageW (g_spike.parent, VALA_WEBVIEW2_WM_SPIKE_DONE, (WPARAM) (result > 0 ? 1 : 0), 0);
	}
}

static void spike_release_stream (void)
{
	if (g_spike.stream != NULL) {
		IStream_Release (g_spike.stream);
		g_spike.stream = NULL;
	}
}

static BOOL spike_build_path (const wchar_t *filename, wchar_t *out, size_t out_chars)
{
	if (g_spike.output_dir[0] != L'\0') {
		if (PathCombineW (out, g_spike.output_dir, filename) == NULL) {
			return FALSE;
		}
		return TRUE;
	}
	if (GetModuleFileNameW (NULL, out, (DWORD) out_chars) == 0) {
		return FALSE;
	}
	PathRemoveFileSpecW (out);
	return PathCombineW (out, out, filename) != NULL;
}

typedef struct ScriptCompletedHandler {
	ICoreWebView2ExecuteScriptCompletedHandler iface;
	ICoreWebView2ExecuteScriptCompletedHandlerVtbl vtbl;
	LONG ref_count;
	void (*on_done) (HRESULT error_code);
} ScriptCompletedHandler;

typedef struct CaptureCompletedHandler {
	ICoreWebView2CapturePreviewCompletedHandler iface;
	ICoreWebView2CapturePreviewCompletedHandlerVtbl vtbl;
	LONG ref_count;
	void (*on_done) (HRESULT error_code);
} CaptureCompletedHandler;

typedef struct NavCompletedHandler {
	ICoreWebView2NavigationCompletedEventHandler iface;
	ICoreWebView2NavigationCompletedEventHandlerVtbl vtbl;
	LONG ref_count;
} NavCompletedHandler;

static HRESULT STDMETHODCALLTYPE script_handler_qi (
	ICoreWebView2ExecuteScriptCompletedHandler *This,
	REFIID riid,
	void **ppv)
{
	if (IsEqualIID (riid, &IID_IUnknown)
	    || IsEqualIID (riid, &IID_ICoreWebView2ExecuteScriptCompletedHandler)) {
		*ppv = This;
		ICoreWebView2ExecuteScriptCompletedHandler_AddRef (This);
		return S_OK;
	}
	*ppv = NULL;
	return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE script_handler_addref (
	ICoreWebView2ExecuteScriptCompletedHandler *This)
{
	ScriptCompletedHandler *self = (ScriptCompletedHandler *) This;
	return (ULONG) InterlockedIncrement (&self->ref_count);
}

static ULONG STDMETHODCALLTYPE script_handler_release (
	ICoreWebView2ExecuteScriptCompletedHandler *This)
{
	ScriptCompletedHandler *self = (ScriptCompletedHandler *) This;
	LONG count = InterlockedDecrement (&self->ref_count);
	if (count == 0) {
		CoTaskMemFree (self);
	}
	return (ULONG) count;
}

static HRESULT STDMETHODCALLTYPE script_handler_invoke (
	ICoreWebView2ExecuteScriptCompletedHandler *This,
	HRESULT error_code,
	LPCWSTR result)
{
	ScriptCompletedHandler *self = (ScriptCompletedHandler *) This;
	void (*on_done) (HRESULT) = self->on_done;

	(void) result;
	ICoreWebView2ExecuteScriptCompletedHandler_Release (This);
	if (on_done != NULL) {
		on_done (error_code);
	}
	return S_OK;
}

static HRESULT STDMETHODCALLTYPE capture_handler_qi (
	ICoreWebView2CapturePreviewCompletedHandler *This,
	REFIID riid,
	void **ppv)
{
	if (IsEqualIID (riid, &IID_IUnknown)
	    || IsEqualIID (riid, &IID_ICoreWebView2CapturePreviewCompletedHandler)) {
		*ppv = This;
		ICoreWebView2CapturePreviewCompletedHandler_AddRef (This);
		return S_OK;
	}
	*ppv = NULL;
	return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE capture_handler_addref (
	ICoreWebView2CapturePreviewCompletedHandler *This)
{
	CaptureCompletedHandler *self = (CaptureCompletedHandler *) This;
	return (ULONG) InterlockedIncrement (&self->ref_count);
}

static ULONG STDMETHODCALLTYPE capture_handler_release (
	ICoreWebView2CapturePreviewCompletedHandler *This)
{
	CaptureCompletedHandler *self = (CaptureCompletedHandler *) This;
	LONG count = InterlockedDecrement (&self->ref_count);
	if (count == 0) {
		CoTaskMemFree (self);
	}
	return (ULONG) count;
}

static HRESULT STDMETHODCALLTYPE capture_handler_invoke (
	ICoreWebView2CapturePreviewCompletedHandler *This,
	HRESULT error_code)
{
	CaptureCompletedHandler *self = (CaptureCompletedHandler *) This;
	void (*on_done) (HRESULT) = self->on_done;

	ICoreWebView2CapturePreviewCompletedHandler_Release (This);
	spike_release_stream ();
	if (on_done != NULL) {
		on_done (error_code);
	}
	return S_OK;
}

static ScriptCompletedHandler *spike_alloc_script_handler (void (*on_done) (HRESULT))
{
	ScriptCompletedHandler *handler;

	handler = (ScriptCompletedHandler *) CoTaskMemAlloc (sizeof (*handler));
	if (handler == NULL) {
		return NULL;
	}
	ZeroMemory (handler, sizeof (*handler));
	handler->iface.lpVtbl = &handler->vtbl;
	handler->vtbl.QueryInterface = script_handler_qi;
	handler->vtbl.AddRef = script_handler_addref;
	handler->vtbl.Release = script_handler_release;
	handler->vtbl.Invoke = script_handler_invoke;
	handler->ref_count = 1;
	handler->on_done = on_done;
	return handler;
}

static CaptureCompletedHandler *spike_alloc_capture_handler (void (*on_done) (HRESULT))
{
	CaptureCompletedHandler *handler;

	handler = (CaptureCompletedHandler *) CoTaskMemAlloc (sizeof (*handler));
	if (handler == NULL) {
		return NULL;
	}
	ZeroMemory (handler, sizeof (*handler));
	handler->iface.lpVtbl = &handler->vtbl;
	handler->vtbl.QueryInterface = capture_handler_qi;
	handler->vtbl.AddRef = capture_handler_addref;
	handler->vtbl.Release = capture_handler_release;
	handler->vtbl.Invoke = capture_handler_invoke;
	handler->ref_count = 1;
	handler->on_done = on_done;
	return handler;
}

static BOOL spike_run_script (LPCWSTR javascript, void (*on_done) (HRESULT))
{
	ScriptCompletedHandler *handler;
	HRESULT hr;

	if (g_spike.webview == NULL) {
		return FALSE;
	}
	handler = spike_alloc_script_handler (on_done);
	if (handler == NULL) {
		return FALSE;
	}
	hr = ICoreWebView2_ExecuteScript (g_spike.webview, javascript, &handler->iface);
	ICoreWebView2ExecuteScriptCompletedHandler_Release (&handler->iface);
	return SUCCEEDED (hr);
}

static void spike_on_capture_top_done (HRESULT error_code);
static void spike_on_scroll_top_done (HRESULT error_code);
static void spike_on_capture_bottom_done (HRESULT error_code);
static void spike_on_scroll_bottom_done (HRESULT error_code);

static BOOL spike_run_capture (const wchar_t *filename, void (*on_done) (HRESULT))
{
	wchar_t path[MAX_PATH];
	CaptureCompletedHandler *handler;
	HRESULT hr;

	if (!spike_build_path (filename, path, MAX_PATH)) {
		fprintf (stderr, "spike: path build failed\n");
		return FALSE;
	}
	spike_release_stream ();
	hr = SHCreateStreamOnFileEx (
		path,
		STGM_CREATE | STGM_WRITE | STGM_SHARE_DENY_WRITE,
		FILE_ATTRIBUTE_NORMAL,
		TRUE,
		NULL,
		&g_spike.stream);
	if (FAILED (hr)) {
		fprintf (stderr, "spike: SHCreateStreamOnFileEx %ls failed: 0x%08lx\n", path, (unsigned long) hr);
		return FALSE;
	}
	handler = spike_alloc_capture_handler (on_done);
	if (handler == NULL) {
		spike_release_stream ();
		return FALSE;
	}
	fprintf (stderr, "spike: capturing %ls\n", path);
	hr = ICoreWebView2_CapturePreview (
		g_spike.webview,
		COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_PNG,
		g_spike.stream,
		&handler->iface);
	ICoreWebView2CapturePreviewCompletedHandler_Release (&handler->iface);
	if (FAILED (hr)) {
		spike_release_stream ();
		fprintf (stderr, "spike: CapturePreview failed: 0x%08lx\n", (unsigned long) hr);
		return FALSE;
	}
	return TRUE;
}

static void spike_on_capture_top_done (HRESULT error_code)
{
	if (FAILED (error_code)) {
		fprintf (stderr, "spike: top capture failed: 0x%08lx\n", (unsigned long) error_code);
		spike_finish (-1);
		return;
	}
	fprintf (stderr, "spike: done (scroll bottom -> capture -> scroll top -> capture)\n");
	spike_finish (1);
}

static void spike_on_scroll_top_done (HRESULT error_code)
{
	if (FAILED (error_code)) {
		fprintf (stderr, "spike: scroll top failed: 0x%08lx\n", (unsigned long) error_code);
		spike_finish (-1);
		return;
	}
	if (!spike_run_capture (L"webview2-spike-02-at-top.png", spike_on_capture_top_done)) {
		spike_finish (-1);
	}
}

static void spike_on_capture_bottom_done (HRESULT error_code)
{
	if (FAILED (error_code)) {
		fprintf (stderr, "spike: bottom capture failed: 0x%08lx\n", (unsigned long) error_code);
		spike_finish (-1);
		return;
	}
	if (!spike_run_script (g_js_scroll_top, spike_on_scroll_top_done)) {
		spike_finish (-1);
	}
}

static void spike_on_scroll_bottom_done (HRESULT error_code)
{
	if (FAILED (error_code)) {
		fprintf (stderr, "spike: scroll bottom failed: 0x%08lx\n", (unsigned long) error_code);
		spike_finish (-1);
		return;
	}
	Sleep (800);
	if (!spike_run_capture (L"webview2-spike-01-after-scroll-bottom.png", spike_on_capture_bottom_done)) {
		spike_finish (-1);
	}
}

static void spike_apply_wide_bounds (void)
{
	RECT bounds;

	if (!g_spike.wide_bounds || g_spike.controller == NULL || g_spike.parent == NULL) {
		return;
	}
	GetClientRect (g_spike.parent, &bounds);
	bounds.right = bounds.left + 1400;
	ICoreWebView2Controller_put_Bounds (g_spike.controller, bounds);
	fprintf (stderr, "spike: wide bounds %ld x %ld\n", (long) (bounds.right - bounds.left), (long) (bounds.bottom - bounds.top));
}

static void spike_run_pipeline (void)
{
	fprintf (stderr, "spike: navigation complete, starting scroll/capture probe\n");
	spike_apply_wide_bounds ();
	if (!spike_run_script (g_js_scroll_bottom, spike_on_scroll_bottom_done)) {
		spike_finish (-1);
	}
}

static HRESULT STDMETHODCALLTYPE nav_handler_qi (
	ICoreWebView2NavigationCompletedEventHandler *This,
	REFIID riid,
	void **ppv)
{
	if (IsEqualIID (riid, &IID_IUnknown)
	    || IsEqualIID (riid, &IID_ICoreWebView2NavigationCompletedEventHandler)) {
		*ppv = This;
		ICoreWebView2NavigationCompletedEventHandler_AddRef (This);
		return S_OK;
	}
	*ppv = NULL;
	return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE nav_handler_addref (
	ICoreWebView2NavigationCompletedEventHandler *This)
{
	NavCompletedHandler *self = (NavCompletedHandler *) This;
	return (ULONG) InterlockedIncrement (&self->ref_count);
}

static ULONG STDMETHODCALLTYPE nav_handler_release (
	ICoreWebView2NavigationCompletedEventHandler *This)
{
	NavCompletedHandler *self = (NavCompletedHandler *) This;
	LONG count = InterlockedDecrement (&self->ref_count);
	if (count == 0) {
		CoTaskMemFree (self);
	}
	return (ULONG) count;
}

static HRESULT STDMETHODCALLTYPE nav_handler_invoke (
	ICoreWebView2NavigationCompletedEventHandler *This,
	ICoreWebView2 *sender,
	ICoreWebView2NavigationCompletedEventArgs *args)
{
	NavCompletedHandler *self = (NavCompletedHandler *) This;
	BOOL is_success = FALSE;
	HRESULT hr;

	(void) self;
	(void) sender;
	if (!g_spike.enabled || g_spike.started) {
		return S_OK;
	}
	if (args != NULL) {
		hr = ICoreWebView2NavigationCompletedEventArgs_get_IsSuccess (args, &is_success);
		if (FAILED (hr) || !is_success) {
			fprintf (stderr, "spike: navigation failed, skipping\n");
			return S_OK;
		}
	}
	g_spike.started = TRUE;
	spike_run_pipeline ();
	return S_OK;
}

static void spike_register_navigation_handler (void)
{
	NavCompletedHandler *handler;
	EventRegistrationToken token;
	HRESULT hr;

	if (g_spike.webview == NULL) {
		return;
	}
	handler = (NavCompletedHandler *) CoTaskMemAlloc (sizeof (*handler));
	if (handler == NULL) {
		return;
	}
	ZeroMemory (handler, sizeof (*handler));
	handler->iface.lpVtbl = &handler->vtbl;
	handler->vtbl.QueryInterface = nav_handler_qi;
	handler->vtbl.AddRef = nav_handler_addref;
	handler->vtbl.Release = nav_handler_release;
	handler->vtbl.Invoke = nav_handler_invoke;
	handler->ref_count = 1;

	hr = ICoreWebView2_add_NavigationCompleted (g_spike.webview, &handler->iface, &token);
	ICoreWebView2NavigationCompletedEventHandler_Release (&handler->iface);
	if (FAILED (hr)) {
		fprintf (stderr, "spike: add_NavigationCompleted failed: 0x%08lx\n", (unsigned long) hr);
	}
}

BOOL vala_webview2_host_set_capture_spike (LPCWSTR output_dir, BOOL use_wide_bounds)
{
	g_spike.enabled = TRUE;
	g_spike.wide_bounds = use_wide_bounds;
	g_spike.started = FALSE;
	g_spike.result = 0;
	g_spike.output_dir[0] = L'\0';
	if (output_dir != NULL && output_dir[0] != L'\0') {
		wcsncpy (g_spike.output_dir, output_dir, MAX_PATH - 1);
		g_spike.output_dir[MAX_PATH - 1] = L'\0';
	}
	return TRUE;
}

int vala_webview2_host_capture_spike_result (void)
{
	return g_spike.result;
}

void vala_webview2_capture_spike_on_host_ready (
	ICoreWebView2 *webview,
	ICoreWebView2Controller *controller,
	HWND parent)
{
	if (!g_spike.enabled) {
		return;
	}
	g_spike.webview = webview;
	g_spike.controller = controller;
	g_spike.parent = parent;
	spike_register_navigation_handler ();
}

void vala_webview2_capture_spike_on_host_destroy (void)
{
	spike_release_stream ();
	ZeroMemory (&g_spike, sizeof (g_spike));
}
