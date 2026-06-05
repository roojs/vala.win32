/*
 * Optional sync COM wrapper override on ergo_native_map rows
 * (metadata/widget-conventions.json → sync_com).
 */

namespace Generate.Parse {
	public class SyncComSpec : Base {
		public string? glue { get; set; }
		public string? com { get; set; }
		public string? host { get; set; }
		public string? vala_call { get; set; }
	}
}
