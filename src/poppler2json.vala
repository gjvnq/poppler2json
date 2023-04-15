using Json;
using GLib.Math;
using Cairo;
using Poppler;

class com.github.gjvnq.poppler2json.Reader : GLib.Object {
	private double dpi;
	private string input_filename;
	private Poppler.Document document;

	public Reader(string input_filename, double dpi) {
		this.dpi = dpi;
		this.input_filename = input_filename;
		var file = File.new_for_path(input_filename);
		this.document = new Poppler.Document.from_gfile(file, null);
	}

	public Json.Object extract_page(int page_index) {
		Poppler.Page page = this.document.get_page(page_index);

		Json.Object output = new Json.Object();

		//  Add full text
		output.set_string_member("text", page.get_text());

		//  Add duration (in case of slide shows)
		output.set_double_member("duration", page.get_duration());

		//  Add page index and label
		output.set_double_member("page_index", page.get_index());
		output.set_string_member("page_label", page.get_label());

		//  Crop box
		Poppler.Rectangle crop_box = page.get_crop_box();
		Json.Array crop_box_array = new Json.Array();
		crop_box_array.add_double_element(crop_box.x1);
		crop_box_array.add_double_element(crop_box.x2);
		crop_box_array.add_double_element(crop_box.y1);
		crop_box_array.add_double_element(crop_box.x2);
		output.set_array_member("crop_box", crop_box_array);

		//  Bounding box
		Poppler.Rectangle bounding_box;
		if (page.get_bounding_box(out bounding_box)) {
			Json.Array bounding_box_array = new Json.Array();
			bounding_box_array.add_double_element(bounding_box.x1);
			bounding_box_array.add_double_element(bounding_box.x2);
			bounding_box_array.add_double_element(bounding_box.y1);
			bounding_box_array.add_double_element(bounding_box.x2);
			output.set_array_member("bounding_box", bounding_box_array);
		}

		//  Add text formatting
		List<Poppler.TextAttributes> formatting_attrs = page.get_text_attributes();
		Json.Array formatting_array = new Json.Array();
		foreach (Poppler.TextAttributes attr in formatting_attrs) {
			Json.Object formatting_object = new Json.Object();
			formatting_object.set_int_member("start_index", attr.start_index);
			formatting_object.set_int_member("end_index", attr.end_index);
			formatting_object.set_double_member("font_size", attr.font_size);
			formatting_object.set_string_member("font_name", attr.font_name);
			formatting_object.set_boolean_member("is_underlined", attr.is_underlined);

			Json.Array color_array = new Json.Array();
			Poppler.Color* color = (Poppler.Color*) &attr.color; // No clue why this line is needed
			color_array.add_int_element(color->red);
			color_array.add_int_element(color->green);
			color_array.add_int_element(color->blue);
			formatting_object.set_array_member("color", color_array);

			formatting_array.add_object_element(formatting_object);
		}
		output.set_array_member("formatting", formatting_array);

		//  Add the rectangles of each char
		Poppler.Rectangle[] char_rects;
		if (page.get_text_layout(out char_rects)) {
			Json.Array char_rects_array = new Json.Array();
			foreach (var rect in char_rects) {
				Json.Array pos_array = new Json.Array();
				pos_array.add_double_element(rect.x1);
				pos_array.add_double_element(rect.x2);
				pos_array.add_double_element(rect.y1);
				pos_array.add_double_element(rect.y2);
				char_rects_array.add_array_element(pos_array);
			}
			output.set_array_member("char_rects", char_rects_array);
		}

		return output;
	}

	//  public ByteArray render_page_svg(int page_index) {
	//  	Poppler.Page page = this.document.get_page(page_index);
	//  	return null;
	//  }

	public ByteArray render_page_png(int page_index, double dpi) {
		Poppler.Page page = this.document.get_page(page_index);
		Poppler.Rectangle crop_box = page.get_crop_box();
		double width_in_points  = crop_box.x2 - crop_box.x1;
		double height_in_points = crop_box.y2 - crop_box.y1;
		double width_in_inches  = width_in_points / 72;
		double height_in_inches = height_in_points / 72;
		int width_in_pixels  = (int) Math.round(width_in_inches * dpi);
		int height_in_pixels = (int) Math.round(height_in_inches * dpi);

		Cairo.ImageSurface surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, width_in_pixels, height_in_pixels);
		Cairo.Context context = new Cairo.Context (surface);
		context.scale(width_in_pixels/width_in_points, height_in_pixels/height_in_points);
		context.translate(crop_box.x1, crop_box.y1);

		//  White background
		context.set_source_rgba(1, 1, 1, 1);
		context.rectangle(0, 0, width_in_points, height_in_points);
		context.fill ();

		//  Render page
		page.render(context);

		ByteArray output = new ByteArray();
		Cairo.Status status = surface.write_to_png_stream((data) => {
			output.append(data);
			return Cairo.Status.SUCCESS;
		});
		print(status.to_string());
		stdout.printf("output = %p\n", output);
		stdout.printf("output.len = %d\n", output.data.length);
		return output;
	}
}


class com.github.gjvnq.poppler2json.CLI : GLib.Object {
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

	private static void bytearray_to_file(ByteArray array, string filename) {
		File file = File.new_for_path(filename);
		file.replace_contents(array.data, null, false, FileCreateFlags.PRIVATE, null);
	}

	private static string bytearray_to_base64(ByteArray array) {
		return Base64.encode(array.data);
	}

	private static string json_builder_to_string(Json.Builder builder) {
		Json.Generator generator = new Json.Generator();
		Json.Node root = builder.get_root();
		generator.set_root(root);
		generator.indent = 4;
		generator.pretty = true;
		return generator.to_data(null);
	}

	private static string json_object_to_string(Json.Object object) {
		Json.Generator generator = new Json.Generator();
		Json.Node root = new Json.Node(Json.NodeType.OBJECT);
		root.init_object(object);
		generator.set_root(root);
		generator.indent = 4;
		generator.pretty = true;
		return generator.to_data(null);
	}

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

		Reader reader = new Reader(input_filename, dpi);
		var object = reader.extract_page(1);
		ByteArray img_stream = reader.render_page_png(1, dpi);
		object.set_string_member("png", CLI.bytearray_to_base64(img_stream)); // "data:image/png;base64,"

		stdout.printf("%s\n", CLI.json_object_to_string(object));
		CLI.bytearray_to_file(img_stream, "efwefe.png");


		return 0;
	}
}