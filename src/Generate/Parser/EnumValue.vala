/*
 * win32json enum member(Types[].Values[]).
 */

namespace Generate.Parse {
	/** One named value inside a metadata enum type. */
	public class EnumValue : Base {
		public string Name { get; set; default = ""; }
		public int64 Value { get; set; default = 0; }
	}
}