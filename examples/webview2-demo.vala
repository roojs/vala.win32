/* Track B: ergonomic WebView2 — Win32.Window + Win32.WebView (Phase 7h/7j baseline). */

using GLib;

static void dump_web_state(Win32.WebView web, string action) {
	stderr.printf(
		"--- [%s] ready=%s bounds=%d,%d %dx%d ---\n",
		action,
		web.ready ? "yes" : "no",
		web.x, web.y, web.width, web.height
	);
	stderr.printf("  source: %s\n", web.source);
	stderr.printf("  document_title: %s\n", web.document_title);
	stderr.printf(
		"  can_go_back=%s can_go_forward=%s visible=%s zoom=%.2f\n",
		web.can_go_back ? "true" : "false",
		web.can_go_forward ? "true" : "false",
		web.visible ? "true" : "false",
		web.zoom_factor
	);
}

static void layout_web(Win32.WebView web, int toolbar_height, uint client_w, uint client_h) {
	if (client_h <= toolbar_height) {
		return;
	}
	web.set_bounds(0, toolbar_height, (int) client_w, (int) client_h - toolbar_height);
}

public static int main(string[] args) {
	var start_url = "https://example.com/";
	if (args.length > 1) {
		start_url = args[1];
	}

	var WINDOW_WIDTH = 1024;
	var WINDOW_HEIGHT = 768;
	var TOOLBAR_HEIGHT = 40;
	var MARGIN = 8;
	var GAP = 6;
	var BUTTON_HEIGHT = 28;
	var BUTTON_WIDTH = 64;

	var frame = new Win32.Window(
		"ValaWin32WebView2Ergo",
		"vala.win32 WebView2 (ergo)",
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		true
	);
	if (frame.handle == null) {
		return 1;
	}

	int bx = MARGIN;
	var back_btn = new Win32.Button(frame, bx, MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT, "Back");
	bx += BUTTON_WIDTH + GAP;
	var fwd_btn = new Win32.Button(frame, bx, MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT, "Fwd");
	bx += BUTTON_WIDTH + GAP;
	var reload_btn = new Win32.Button(frame, bx, MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT, "Reload");
	bx += BUTTON_WIDTH + GAP;
	var stop_btn = new Win32.Button(frame, bx, MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT, "Stop");
	bx += BUTTON_WIDTH + GAP;
	var html_btn = new Win32.Button(frame, bx, MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT, "HTML");
	bx += BUTTON_WIDTH + GAP;
	var zoom_in_btn = new Win32.Button(frame, bx, MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT, "Zoom+");
	bx += BUTTON_WIDTH + GAP;
	var zoom_out_btn = new Win32.Button(frame, bx, MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT, "Zoom-");
	bx += BUTTON_WIDTH + GAP;
	var vis_btn = new Win32.Button(frame, bx, MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT, "Vis");
	bx += BUTTON_WIDTH + GAP;
	var dump_btn = new Win32.Button(frame, bx, MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT, "Dump");
	bx += BUTTON_WIDTH + GAP;
	var script_btn = new Win32.Button(frame, bx, MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT, "Script");
	bx += BUTTON_WIDTH + GAP;
	var post_btn = new Win32.Button(frame, bx, MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT, "Post");

	var web = new Win32.WebView(
		frame, 0, TOOLBAR_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT - TOOLBAR_HEIGHT, false
	);
	layout_web(web, TOOLBAR_HEIGHT, (uint) WINDOW_WIDTH, (uint) WINDOW_HEIGHT);

	frame.resized.connect((w, h) => {
		layout_web(web, TOOLBAR_HEIGHT, w, h);
	});

	web.navigation_starting.connect(() => {
		stderr.printf("WebView navigation_starting\n");
	});
	web.navigation_completed.connect((ok) => {
		stderr.printf("WebView navigation_completed success=%s\n", ok ? "true" : "false");
		dump_web_state(web, "navigation_completed");
		frame.title = "vala.win32 WebView2 — %s".printf(web.document_title);
	});
	web.document_title_changed.connect(() => {
		stderr.printf("WebView document_title_changed: %s\n", web.document_title);
		frame.title = "vala.win32 WebView2 — %s".printf(web.document_title);
	});

	web.navigate(start_url);

	back_btn.clicked.connect(() => {
		web.go_back();
		dump_web_state(web, "go_back");
	});
	fwd_btn.clicked.connect(() => {
		web.go_forward();
		dump_web_state(web, "go_forward");
	});
	reload_btn.clicked.connect(() => {
		web.reload();
		dump_web_state(web, "reload");
	});
	stop_btn.clicked.connect(() => {
		web.stop();
		dump_web_state(web, "stop");
	});
	html_btn.clicked.connect(() => {
		web.navigate_to_string(
			"""<html><body style="font-family:sans-serif;padding:2em">
<h1>navigate_to_string</h1>
<p>Loaded inline HTML from the ergo demo toolbar.</p>
<p><a href="https://example.com/">example.com</a> to exercise go_back.</p>
</body></html>"""
		);
		dump_web_state(web, "navigate_to_string");
	});
	zoom_in_btn.clicked.connect(() => {
		web.zoom_factor = web.zoom_factor + 0.25;
		dump_web_state(web, "zoom_factor+");
	});
	zoom_out_btn.clicked.connect(() => {
		web.zoom_factor = web.zoom_factor - 0.25;
		if (web.zoom_factor < 0.5) {
			web.zoom_factor = 0.5;
		}
		dump_web_state(web, "zoom_factor-");
	});
	vis_btn.clicked.connect(() => {
		web.visible = !web.visible;
		vis_btn.text = web.visible ? "Vis" : "Show";
		dump_web_state(web, "visible toggle");
	});
	dump_btn.clicked.connect(() => {
		dump_web_state(web, "manual dump");
	});
	script_btn.clicked.connect(() => {
		var ok = web.execute_script(
			"document.body.style.background='#eef8ff'; 'ergo execute_script ok';"
		);
		stderr.printf("WebView execute_script returned %s\n", ok ? "true" : "false");
		dump_web_state(web, "execute_script");
	});
	post_btn.clicked.connect(() => {
		var ok = web.post_web_message_as_json("{\"source\":\"webview2-demo\"}");
		stderr.printf("WebView post_web_message_as_json returned %s\n", ok ? "true" : "false");
		dump_web_state(web, "post_web_message_as_json");
	});

	stderr.printf(
		"webview2-demo: toolbar exercises WebView methods/properties/signals; stderr traces state\n"
	);

	return frame.run();
}
