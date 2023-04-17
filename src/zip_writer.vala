using Json;
using GLib.Math;
using Cairo;

class com.github.gjvnq.poppler2json.ZipWriter : GLib.Object {
    private double dpi;
    private Reader reader;
    private string tmp_dir;

    public ZipWriter(Reader reader, double dpi) {
        this.dpi = dpi;
        this.reader = reader;
        this.tmp_dir = DirUtils.mkdtemp(Environment.get_tmp_dir()+GLib.Path.DIR_SEPARATOR_S+"poppler-XXXXXX");
        stdout.printf(this.tmp_dir+"\n");
	}

    public void do_index() {
        var json_data = this.reader.extract_index();
        var json_str = json_object_to_string(json_data);
        var json_filename = GLib.Path.build_filename(this.tmp_dir, "index.json");
        File json_file = File.new_for_path(json_filename);
        try {
            json_file.replace_contents(json_str.data, null, false, FileCreateFlags.PRIVATE, null);
        } catch (Error e) {
            stdout.printf("Failed to save index JSON. Error: %s\n", e.message);
        }
    }

    public void do_page(int page_index) {
        //  Do the JSON file
        var json_data = this.reader.extract_page(page_index);
        var json_str = json_object_to_string(json_data);
        var json_filename = build_filname(page_index, "json", this.tmp_dir);
        File json_file = File.new_for_path(json_filename);
        try {
            json_file.replace_contents(json_str.data, null, false, FileCreateFlags.PRIVATE, null);
        } catch (Error e) {
            stdout.printf("Failed to save JSON for page %d. Error: %s\n", page_index, e.message);
        }

        //  Do the image
        reader.render_page_png_to_file(page_index, this.dpi, this.tmp_dir);
    }

    private void add_file_to_zip(Archive.Write archive, string filename) {
        try {
            var file = GLib.File.new_for_path(GLib.Path.build_filename(this.tmp_dir, filename));
            stdout.printf("Adding %s to zip\n", file.get_path());
            var file_info = file.query_info(GLib.FileAttribute.STANDARD_SIZE, GLib.FileQueryInfoFlags.NONE);
            var input_stream = file.read();
            var data_input_stream = new DataInputStream(input_stream);

            Archive.Entry entry = new Archive.Entry();
            entry.set_pathname(filename);

            entry.set_size((Archive.int64_t) file_info.get_size());
            entry.set_filetype((uint)Posix.S_IFREG);
            entry.set_perm(0644);
            if (archive.write_header (entry) != Archive.Result.OK) {
                error("Error writing '%s': %s (%d)", file.get_path(), archive.error_string(), archive.errno());
                return;
            }

            // Add the actual content of the file
            size_t bytes_read;
            uint8[] buffer = new uint8[64];
            while (data_input_stream.read_all(buffer, out bytes_read)) {
                if (bytes_read <= 0) {
                    break;
                }
                archive.write_data(buffer);
            }
        } catch (Error e) {
            error("Failed to add file %s: %s", filename, e.message);
        }
    }

    public void do_compress(string output_filename) {
        var archive = new Archive.Write();
        archive.set_format_zip();
		archive.open_filename(output_filename);

        this.add_file_to_zip(archive, "index.json");

        try {
            var dir = Dir.open(this.tmp_dir);
            string? name = null;
            while ((name = dir.read_name ()) != null) {
                if (name == "index.json") {
                    continue;
                }
                this.add_file_to_zip(archive, name);
            }
        } catch (Error e) {
            error("Failed to list directory %s. Error: %s\n", this.tmp_dir, e.message);
        }

        if (archive.close () != Archive.Result.OK) {
            error("Failed to finish zip archive: %s (%d)", archive.error_string(), archive.errno ());
        }
    }

    public void do_all(string output_filename) {
        this.do_index();
        for (int i=0; i < this.reader.n_pages; i++) {
            this.do_page(i);
        }
        do_compress(output_filename);
    }

    public void clean() {
        try {
            var dir = Dir.open(this.tmp_dir);
            string? name = null;
            while ((name = dir.read_name ()) != null) {
                var file = File.new_for_path(GLib.Path.build_filename(this.tmp_dir, name));
                file.delete(null);
            }
            var file = File.new_for_path(this.tmp_dir);
            file.delete(null);
        } catch (Error e) {
            error("Failed to clean directory %s. Error: %s\n", this.tmp_dir, e.message);
        }
    }
}