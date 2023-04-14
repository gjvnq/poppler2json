class com.github.gjvnq.poppler2json : GLib.Object {
	private static int dpi = 300;
	private static string input_filename = "";
	private static string output_filename = "";
	private static string img_format = "";
	private static string page_range_str = "";

	private const GLib.OptionEntry[] options = {
		{ "dpi", '\0', OptionFlags.NONE, OptionArg.INT, ref dpi, "Display version number", "INT" },
		{ "input", 'i', OptionFlags.NONE, OptionArg.FILENAME, ref input_filename, "Input filename", "FILENAME" },
		{ "output", 'o', OptionFlags.NONE, OptionArg.FILENAME, ref output_filename, "Output filename", "FILENAME" },
		{ "format", 'f', OptionFlags.NONE, OptionArg.STRING, ref img_format, "Image file format (json-png, json-svg, tiff-png, tiff-svg)", "IMG_FORMAT" },
		{ "page", 'p', OptionFlags.NONE, OptionArg.STRING, ref page_range_str, "Page range string", "PAGE_RANGE" },
		{ null }
	};
	public static int main(string[] args) {
		try {
			var opt_context = new OptionContext("- Uses poppler to extract data in exchangable file formats");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);
			opt_context.parse (ref args);
		} catch (OptionError e) {
			printerr("error: %s\n", e.message);
			printerr("Run '%s --help' to see a full list of available command line options.\n", args[0]);
			return 1;
		}
		if (page_range_str == null) {
			page_range_str = "all";
		}
		if (img_format == null) {
			img_format = "json-png";
		}


		stdout.printf("Input filename %s\n", input_filename);
		stdout.printf("Output filename %s\n", output_filename);
		stdout.printf("Page range %s\n", page_range_str);
		stdout.printf("Format %s\n", img_format);
		stdout.printf("DPI %d\n", dpi);
		return 0;
	}
}