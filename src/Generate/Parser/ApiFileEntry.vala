/*
 * Loaded namespace JSON file plus basename for symbol naming.
 */

namespace Generate.Parse {
	/** Pair of win32json file basename and deserialized {@link ApiFile}. */
	public class ApiFileEntry : Object {
		public string basename { get; construct; }
		public ApiFile document { get; construct; }

		public ApiFileEntry(string basename, ApiFile document) {
			Object(basename: basename, document: document);
		}
	}
}