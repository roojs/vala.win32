/* Ergo WebView2 widget shell — catalog API spliced at @WEBVIEW2_CATALOG@ */

using GLib;
using Win32.Ui.WebView;

[CCode(cheader_filename = "win32-ergo-webview2.h")]
namespace Win32 {

/**
 * Ergonomic WebView2 child — API from WebView2MethodCatalog; shell from profiles.WebView2.
 * One WebView per process today (Ui.WebView glue singleton).
 */
public class WebView : Widget {
/* @WEBVIEW2_SIGNALS@ */

	public int x { get; private set; }
	public int y { get; private set; }
	public int width { get; private set; }
	public int height { get; private set; }
	private bool attached;
	private bool resize_with_parent;

	public WebView(
		@CONSTRUCTOR_PARAMS@,
		bool resize_with_parent = false
	) {
		base(parent);
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
		this.resize_with_parent = resize_with_parent;
		if (parent.handle == null || width <= 0 || height <= 0) {
			return;
		}
		parent.destroyed.connect(on_parent_destroyed);
		if (this.resize_with_parent) {
			parent.resized.connect(on_parent_resized);
		}
		if (!Ui.WebView.create_with_xywh(parent.handle, x, y, width, height, null)) {
			stderr.printf("WebView: create_with_xywh failed(runtime/loader missing?)\n");
			return;
		}
		attached = true;
		wire_event_handlers();
	}

	private void wire_event_handlers() {
/* @EVENT_WIRING@ */
	}

	public bool ready {
		get { return attached && Ui.WebView.is_ready(); }
	}

	/** Update layout in parent client coordinates (same pattern as MoveWindow children). */
	public void set_bounds(int x, int y, int width, int height) {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
		push_layout();
	}

	public void move(int x, int y) {
		set_bounds(x, y, width, height);
	}

	public void resize(int width, int height) {
		set_bounds(x, y, width, height);
	}

/* @WEBVIEW2_CATALOG@ */

	void push_layout() {
		if (!attached || width <= 0 || height <= 0) {
			return;
		}
		Ui.WebView.set_bounds_xywh(x, y, width, height);
	}

	void on_parent_resized(uint parent_width, uint parent_height) {
		if (!resize_with_parent) {
			return;
		}
		set_bounds(0, 0, (int) parent_width, (int) parent_height);
	}

	void on_parent_destroyed() {
		if (attached) {
			Ui.WebView.destroy();
			attached = false;
		}
	}

}

}
