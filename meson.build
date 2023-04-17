project('poppler2json', 'vala', 'c')

cc = meson.get_compiler('c')
dependencies = [
    dependency('gio-2.0'),
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('poppler-glib'),
    dependency('json-glib-1.0'),
    dependency('libarchive'),
    cc.find_library('m', required : false),
]

sources = files([
    'src/cli.vala',
    'src/reader.vala',
    'src/zip_writer.vala',
    'src/utils.vala',
])

executable('poppler2json', sources, dependencies: dependencies)