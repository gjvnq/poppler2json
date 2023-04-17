using Json;
using GLib.Math;
using Cairo;
using Poppler;

class com.github.gjvnq.poppler2json.CLI : GLib.Object {
	private static int dpi = 200;
	private static string input_filename = "";
	private static string output_filename = "";
	private static string img_format = "";
	//  private static string page_range_str = "";
	private static string input_password = "";

	private const GLib.OptionEntry[] options = {
		{ "dpi", '\0', OptionFlags.NONE, OptionArg.INT, ref dpi, "Display version number", "INT" },
		{ "input", 'i', OptionFlags.NONE, OptionArg.FILENAME, ref input_filename, "Input filename", "FILENAME" },
		{ "output", 'o', OptionFlags.NONE, OptionArg.FILENAME, ref output_filename, "Output filename", "FILENAME" },
		{ "format", 'f', OptionFlags.NONE, OptionArg.STRING, ref img_format, "Image file format (json-png, json-svg, tiff-png, tiff-svg)", "IMG_FORMAT" },
		//  { "page", 'p', OptionFlags.NONE, OptionArg.STRING, ref page_range_str, "Page range string", "PAGE_RANGE" },
		{ "password", '\0', OptionFlags.NONE, OptionArg.STRING, ref input_password, "PDF password", "PASSWORD" },
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
		if (img_format == null) {
			img_format = "json-png";
		}
		if (output_filename == null) {
			output_filename = input_filename+".zip";
		}

		stdout.printf("Input filename %s\n", input_filename);
		stdout.printf("Output filename %s\n", output_filename);
		stdout.printf("Format %s\n", img_format);
		stdout.printf("DPI %d\n", dpi);

		Reader reader = new Reader(input_filename, input_password, dpi);
		ZipWriter writer = new ZipWriter(reader, dpi);
		writer.do_all(output_filename);
		//  writer.clean();

		//  var object = reader.extract_page(1);
		//  ByteArray img_stream = reader.render_page_png(1, dpi);
		//  object.set_string_member("png", bytearray_to_base64(img_stream)); // "data:image/png;base64,"

		//  stdout.printf("%s\n", json_object_to_string(object));
		//  bytearray_to_file(img_stream, "efwefe.png");


		return 0;
	}
}