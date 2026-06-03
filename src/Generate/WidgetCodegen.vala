/*
 * G1/G2 — Track B widget conventions (Phase 5 WidgetCodegen).
 * Catalog: WC_* / PROGRESS_CLASS from UI.Controls (metadata + gui.filter).
 * Mapping: metadata/widget-conventions.json (class names, Track B profiles).
 */

namespace Generate {

public enum WidgetDispatchRoute {
	NONE,
	WM_COMMAND,
	WM_SCROLL,
}

public struct WidgetBehaviorProfile {
	public WidgetDispatchRoute dispatch_route;
	public string? signal_name;
	public string? wm_notify_const;
	public bool uses_control_id;
	public string[] window_style_tokens;
	public string[] control_style_tokens;
	public string[] style_literal_exprs;
	public bool text_property;
	public bool selection_helpers;
	public bool scroll_value_property;
	public bool progress_value_property;
}

public struct WidgetControlDescriptor {
	public string wc_symbol;
	public string win32_class_text;
	public string vala_class_name;
	public WidgetBehaviorProfile? profile;

	public string class_name () {
		return vala_class_name;
	}

	public bool has_track_b_profile () {
		return profile != null;
	}

	public WidgetDispatchRoute dispatch_route () {
		return profile != null ? profile.dispatch_route : WidgetDispatchRoute.NONE;
	}

	public bool uses_wm_command_dispatch () {
		return dispatch_route () == WidgetDispatchRoute.WM_COMMAND;
	}

	public bool uses_control_id () {
		return profile != null ? profile.uses_control_id : false;
	}

	public string? signal_name () {
		return profile?.signal_name;
	}

	public string? wm_notify_const () {
		return profile?.wm_notify_const;
	}

	public string[] window_style_tokens () {
		if (profile == null) {
			return WidgetCodegen.EMPTY_TOKENS;
		}
		return profile.window_style_tokens;
	}

	public string[] control_style_tokens () {
		if (profile == null) {
			return WidgetCodegen.EMPTY_TOKENS;
		}
		return profile.control_style_tokens;
	}

	public string[] style_literal_exprs () {
		if (profile == null) {
			return WidgetCodegen.EMPTY_TOKENS;
		}
		return profile.style_literal_exprs;
	}

	public bool has_text_property () {
		return profile != null && profile.text_property;
	}

	public bool has_selection_helpers () {
		return profile != null && profile.selection_helpers;
	}

	public bool has_scroll_value_property () {
		return profile != null && profile.scroll_value_property;
	}

	public bool has_progress_value_property () {
		return profile != null && profile.progress_value_property;
	}
}

public class WidgetCodegen : Object {
	public SymbolFilter filter { get; construct; }

	public const string[] EMPTY_TOKENS = {};

	Gee.ArrayList<WidgetControlDescriptor?> _catalog = new Gee.ArrayList<WidgetControlDescriptor?> ();
	Parse.WidgetConventionsFile _conventions;
	Gee.HashMap<string, WidgetBehaviorProfile?> _profiles = new Gee.HashMap<string, WidgetBehaviorProfile?> ();
	Gee.HashMap<string, uint> _controls_uint_constants = new Gee.HashMap<string, uint> ();

	public WidgetCodegen (SymbolFilter filter, Parse.WidgetConventionsFile conventions) throws GLib.Error {
		Object (filter: filter);
		_conventions = conventions;
		foreach (var entry in _conventions.profiles) {
			_profiles[entry.key] = entry.value.to_profile (entry.key);
		}
	}

	public int catalog_size () {
		return _catalog.size;
	}

	public int profiled_size () {
		int n = 0;
		foreach (var d in _catalog) {
			if (d != null && d.has_track_b_profile ()) {
				n++;
			}
		}
		return n;
	}

	public unowned Gee.ArrayList<WidgetControlDescriptor?> catalog () {
		return _catalog;
	}

	public WidgetControlDescriptor?[] track_b_controls () {
		var list = new Gee.ArrayList<WidgetControlDescriptor?> ();
		foreach (var d in _catalog) {
			if (d != null && d.has_track_b_profile ()) {
				list.add (d);
			}
		}
		return list.to_array ();
	}

	/** All filtered WC_* / PROGRESS_CLASS entries (full widget API surface). */
	public WidgetControlDescriptor?[] catalog_controls () {
		return _catalog.to_array ();
	}

	public WidgetControlDescriptor? find_by_class_name (string vala_class_name) {
		foreach (var d in _catalog) {
			if (d != null && d.class_name () == vala_class_name) {
				return d;
			}
		}
		return null;
	}

	public void load_catalog (Parse.ApiFileEntry controls_entry) {
		_catalog.clear ();
		index_controls_uint_constants (controls_entry);
		var basename = controls_entry.basename;
		var claimed_wc = new Gee.HashSet<string> ();
		var claimed_class_names = new Gee.HashSet<string> ();

		foreach (var c in controls_entry.document.Constants) {
			if (NameMapper.skip_ansi_name (c.Name)) {
				continue;
			}
			if (!VapiEmitter.is_control_class_string (c.Name)) {
				continue;
			}
			if (!VapiEmitter.is_string_constant (c)) {
				continue;
			}
			var full = Parse.ApiFile.full_name (basename, c.Name);
			if (!filter.include_symbol (full)) {
				continue;
			}
			var wc = NameMapper.to_constant_name (c.Name);
			if (claimed_wc.contains (wc)) {
				continue;
			}
			claimed_wc.add (wc);

			WidgetBehaviorProfile? profile = null;
			if (_profiles.has_key (wc)) {
				profile = _profiles[wc];
			}

			var win32_text = decode_wide_constant_text (c);
			var vala_class = resolve_class_name (wc, win32_text);
			if (claimed_class_names.contains (vala_class)) {
				continue;
			}
			claimed_class_names.add (vala_class);

			var desc = WidgetControlDescriptor () {
				wc_symbol = wc,
				win32_class_text = win32_text,
				vala_class_name = vala_class,
				profile = profile,
			};
			_catalog.add (desc);
		}
	}

	string resolve_class_name (string wc_symbol, string win32_class_text) {
		if (_conventions.class_name_overrides.has_key (wc_symbol)) {
			return _conventions.class_name_overrides[wc_symbol];
		}
		if (win32_class_text.length > 0) {
			return win32_class_text;
		}
		if (wc_symbol.has_prefix ("WC_")) {
			return NameMapper.to_vala_type (wc_symbol.substring (3));
		}
		return NameMapper.to_vala_type (wc_symbol);
	}

	static string decode_wide_constant_text (Parse.Constant c) {
		/* Same source as VapiEmitter.emit_string_constant — ValueText is the wide literal. */
		return c.ValueText;
	}

	void index_controls_uint_constants (Parse.ApiFileEntry controls_entry) {
		_controls_uint_constants.clear ();
		foreach (var c in controls_entry.document.Constants) {
			if (c.ValueType != "UInt32" && c.ValueType != "UInt64") {
				continue;
			}
			if (c.ValueText.length > 0) {
				continue;
			}
			var name = NameMapper.to_constant_name (c.Name);
			_controls_uint_constants[name] = (uint) c.Value;
		}
	}

	/** Emit a Vala uint literal from metadata when vapi consts do not C-inline in companion builds. */
	public string uint_constant_expr (string symbol) {
		if (_controls_uint_constants.has_key (symbol)) {
			return "0x%04xu".printf (_controls_uint_constants[symbol]);
		}
		return symbol;
	}
}

}
