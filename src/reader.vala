using Json;
using GLib.Math;
using Cairo;
using Poppler;

class com.github.gjvnq.poppler2json.Reader : GLib.Object {
	private double dpi;
	private string input_filename;
	private Poppler.Document document;

	public Reader(string input_filename, string? password, double dpi) {
		this.dpi = dpi;
		this.input_filename = input_filename;
		var file = File.new_for_path(input_filename);
		this.document = new Poppler.Document.from_gfile(file, password);
	}

	public int n_pages {
        get { return this.document.get_n_pages(); }
    }

	public Json.Object extract_index() {
		Json.Object output = new Json.Object();

		output.set_string_member("author", this.document.author);
		output.set_string_member("title", this.document.title);
		output.set_string_member("subject", this.document.subject);
		output.set_string_member("creator", this.document.creator);
		output.set_string_member("format", this.document.format);
		output.set_string_member("producer", this.document.producer);
		output.set_string_member("keywords", this.document.keywords);
		output.set_string_member("creation_date", this.document.creation_datetime.format_iso8601());
		output.set_string_member("modification_date", this.document.mod_datetime.format_iso8601());
		output.set_boolean_member("linearized", this.document.linearized);
		output.set_boolean_member("has_javascript", this.document.has_javascript());
		output.set_string_member("metadata", this.document.metadata);
		output.set_string_member("pdf_version", this.document.get_pdf_version_string());
		output.set_int_member("n_pages", this.document.get_n_pages());
		output.set_int_member("n_attachments", this.document.get_n_attachments());

		Json.Array page_labels_array = new Json.Array();
		for (int i=0; i < this.n_pages; i++) {
			var page = this.document.get_page(i);
			page_labels_array.add_string_element(page.label);
		}
		output.set_array_member("page_labels", page_labels_array);

		return output;
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

	private Cairo.ImageSurface render_page_png_to_surface(int page_index, double dpi) {
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
		context.fill();

		//  Render page
		page.render(context);

		return surface;
	}

	public ByteArray? render_page_png(int page_index, double dpi) {
		Cairo.ImageSurface surface = this.render_page_png_to_surface(page_index, dpi);

		ByteArray output = new ByteArray();
		Cairo.Status status = surface.write_to_png_stream((data) => {
			output.append(data);
			return Cairo.Status.SUCCESS;
		});
		if (status == Cairo.Status.SUCCESS) {
			return output;
		} else {
			return null;
		}
	}

	public Cairo.Status render_page_png_to_file(int page_index, double dpi, string tmp_dir) {
		Cairo.ImageSurface surface = this.render_page_png_to_surface(page_index, dpi);
		return surface.write_to_png(build_filname(page_index, "png", tmp_dir));
	}
}
