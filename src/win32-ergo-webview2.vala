/* Hand-maintained ergonomic baseline (Phase 7h).
 * Target for generator: pkg win32-ergo-webview2 / Win32.WebView widget profile.
 * One WebView per process today (Ui.WebView glue singleton).
 *
 * Layout lives here (x, y, width, height) — glue only receives set_bounds_xywh. */

using GLib;
using Win32.Ui.WebView;

namespace Win32 {

/**
 * Ergonomic WebView2 child — positioned like other {@link Window} children (x, y, width, height).
 * Delegates to {@link Win32.Ui.WebView} glue (same verb names as win32-ui-webview2.vapi).
 */
public class WebView {
	public signal void navigation_completed (bool success);
	public signal void navigation_starting ();
	public signal void document_title_changed ();

	public Window parent { get; private set; }
	public int x { get; private set; }
	public int y { get; private set; }
	public int width { get; private set; }
	public int height { get; private set; }
	bool _attached;
	bool _resize_with_parent;

	public WebView (
		Window parent,
		int x, int y, int width, int height,
		bool resize_with_parent = false
	) {
		this.parent = parent;
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
		_resize_with_parent = resize_with_parent;
		if (parent.handle == null || width <= 0 || height <= 0) {
			return;
		}
		parent.destroyed.connect (on_parent_destroyed);
		if (_resize_with_parent) {
			parent.resized.connect (on_parent_resized);
		}
		if (!Ui.WebView.create_with_xywh (parent.handle, x, y, width, height, null)) {
			stderr.printf ("WebView: create_with_xywh failed (runtime/loader missing?)\n");
			return;
		}
		_attached = true;
	}

	public bool ready {
		get { return _attached && Ui.WebView.is_ready (); }
	}

	/** Update layout in parent client coordinates (same pattern as MoveWindow children). */
	public void set_bounds (int x, int y, int width, int height) {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
		push_layout ();
	}

	public void move (int x, int y) {
		set_bounds (x, y, width, height);
	}

	public void resize (int width, int height) {
		set_bounds (x, y, width, height);
	}

	public void navigate (string url) {
		if (!_attached || !Ui.WebView.navigate (url)) {
			stderr.printf ("WebView: navigate failed\n");
		}
	}

	public void navigate_to_string (string html) {
		if (!_attached || !Ui.WebView.navigate_to_string (html)) {
			stderr.printf ("WebView: navigate_to_string failed\n");
		}
	}

	public void reload () {
		if (!_attached || !Ui.WebView.reload ()) {
			stderr.printf ("WebView: reload failed\n");
		}
	}

	public void stop () {
		if (!_attached || !Ui.WebView.stop ()) {
			stderr.printf ("WebView: stop failed\n");
		}
	}

	public void go_back () {
		if (!_attached || !Ui.WebView.go_back ()) {
			stderr.printf ("WebView: go_back failed\n");
		}
	}

	public void go_forward () {
		if (!_attached || !Ui.WebView.go_forward ()) {
			stderr.printf ("WebView: go_forward failed\n");
		}
	}

	public bool execute_script (string js) {
		return _attached && Ui.WebView.execute_script (js);
	}

	public bool post_web_message_as_json (string json) {
		return _attached && Ui.WebView.post_web_message_as_json (json);
	}

	public string source {
		get { return _attached ? Ui.WebView.get_source () : ""; }
	}

	public bool can_go_back {
		get { return _attached && Ui.WebView.get_can_go_back (); }
	}

	public bool can_go_forward {
		get { return _attached && Ui.WebView.get_can_go_forward (); }
	}

	public string document_title {
		get { return _attached ? Ui.WebView.get_document_title () : ""; }
	}

	public bool visible {
		get { return _attached && Ui.WebView.get_is_visible (); }
		set {
			if (_attached) {
				Ui.WebView.put_is_visible (value);
			}
		}
	}

	public double zoom_factor {
		get { return _attached ? Ui.WebView.get_zoom_factor () : 1.0; }
		set {
			if (_attached) {
				Ui.WebView.put_zoom_factor (value);
			}
		}
	}

	void push_layout () {
		if (!_attached || width <= 0 || height <= 0) {
			return;
		}
		Ui.WebView.set_bounds_xywh (x, y, width, height);
	}

	void on_parent_resized (uint parent_width, uint parent_height) {
		if (!_resize_with_parent) {
			return;
		}
		set_bounds (0, 0, (int) parent_width, (int) parent_height);
	}

	void on_parent_destroyed () {
		if (_attached) {
			Ui.WebView.destroy ();
			_attached = false;
		}
	}
}

}
