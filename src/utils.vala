string build_filname(int page_index, string extension, string tmp_dir) {
    StringBuilder builder = new StringBuilder();
    builder.append(tmp_dir);
    builder.append(GLib.Path.DIR_SEPARATOR_S);
    builder.append_printf("%04d.%s", page_index, extension);
    return builder.str;
}

void bytearray_to_file(ByteArray array, string filename) {
    File file = File.new_for_path(filename);
    file.replace_contents(array.data, null, false, FileCreateFlags.PRIVATE, null);
}

string bytearray_to_base64(ByteArray array) {
    return Base64.encode(array.data);
}

string json_builder_to_string(Json.Builder builder) {
    Json.Generator generator = new Json.Generator();
    Json.Node root = builder.get_root();
    generator.set_root(root);
    generator.indent = 4;
    generator.pretty = true;
    return generator.to_data(null);
}

string json_object_to_string(Json.Object object) {
    Json.Generator generator = new Json.Generator();
    Json.Node root = new Json.Node(Json.NodeType.OBJECT);
    root.init_object(object);
    generator.set_root(root);
    generator.indent = 4;
    generator.pretty = true;
    return generator.to_data(null);
}