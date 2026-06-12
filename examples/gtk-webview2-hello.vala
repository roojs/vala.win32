/* GTK top-level window + WebView2 via gdk_win32_window_get_handle (Windows spike). */

using Gtk;
using Gdk;
using GLib;

[CCode (cheader_filename = "gdk/gdkwin32.h", cname = "gdk_win32_window_get_handle")]
extern void* gdk_win32_window_get_handle (Gdk.Window window);

[CCode (cheader_filename = "win32-ui-webview2-host.h", cname = "vala_webview2_host_create_with_xywh")]
extern bool webview2_create_with_xywh (void* parent_hwnd, int x, int y, int width, int height, uint16* url);

[CCode (cheader_filename = "win32-ui-webview2-host.h", cname = "vala_webview2_host_navigate")]
extern bool webview2_navigate (string url);

[CCode (cheader_filename = "win32-ui-webview2-host.h", cname = "vala_webview2_host_on_size")]
extern void webview2_on_size (void* parent_hwnd);

[CCode (cheader_filename = "win32-ui-webview2-host.h", cname = "vala_webview2_host_destroy")]
extern void webview2_destroy ();

private void* host_hwnd = null;
private Gtk.Window? host_window = null;
private Gtk.Widget? host_widget = null;
private bool webview_attached = false;

private bool on_delete(Gtk.Widget widget, Gdk.EventAny event) {
	webview2_destroy ();
	Gtk.main_quit ();
	return false;
}

private void attach_webview(Gtk.Window window, Gtk.Widget widget, string start_url) {
	if (webview_attached || host_widget == null) {
		return;
	}
	var top_gdk = window.get_window ();
	if (top_gdk == null) {
		stderr.printf ("gtk-webview2-hello: toplevel GdkWindow missing\n");
		return;
	}
	host_hwnd = gdk_win32_window_get_handle (top_gdk);
	if (host_hwnd == null) {
		stderr.printf ("gtk-webview2-hello: native handle null (wait for map)\n");
		return;
	}

	Gtk.Allocation alloc;
	widget.get_allocation (out alloc);
	int x = 0;
	int y = 0;
	widget.translate_coordinates (window, 0, 0, out x, out y);
	if (!webview2_create_with_xywh (host_hwnd, x, y, alloc.width, alloc.height, null)) {
		stderr.printf ("gtk-webview2-hello: WebView2 create_with_xywh failed\n");
		return;
	}
	if (!webview2_navigate (start_url)) {
		stderr.printf ("gtk-webview2-hello: navigate failed\n");
	}
	webview_attached = true;
	stderr.printf ("gtk-webview2-hello: WebView2 parent hwnd=%p at %d,%d size=%dx%d\n",
		host_hwnd, x, y, alloc.width, alloc.height);
}

public static int main (string[] args) {
	Gtk.init (ref args);

	var html = """
		<html><body style="font-family:sans-serif;margin:2em">
		<h1>Hello WebView2</h1>
		<p>Embedded in a GTK window via <code>gdk_win32_window_get_handle()</code>.</p>
		</body></html>
	""";
	var start_url = "data:text/html;charset=utf-8," + Uri.escape_string (html, null);

	var window = new Gtk.Window (Gtk.WindowType.TOPLEVEL);
	window.title = "Hello GTK + WebView2";
	window.default_width = 640;
	window.default_height = 480;
	window.window_position = Gtk.WindowPosition.CENTER;
	window.delete_event.connect (on_delete);
	host_window = window;

	var host = new Gtk.DrawingArea ();
	host.set_size_request (640, 480);
	host.expand = true;
	host_widget = host;
	window.add (host);

	host.map_event.connect ((event) => {
		attach_webview (window, host, start_url);
		return false;
	});
	host.size_allocate.connect ((alloc) => {
		if (host_hwnd != null) {
			webview2_on_size (host_hwnd);
		}
	});

	window.show_all ();

	Idle.add (() => {
		if (host_window != null && host_widget != null) {
			attach_webview (host_window, host_widget, start_url);
		}
		return false;
	});

	stderr.printf ("gtk-webview2-hello: GTK main loop (WebView2 bootstraps async)\n");
	Gtk.main ();
	return 0;
}
