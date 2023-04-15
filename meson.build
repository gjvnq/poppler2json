project('poppler2json', 'vala', 'c')

cc = meson.get_compiler('c')
dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('poppler-glib'),
    dependency('json-glib-1.0'),
    cc.find_library('m', required : false),
]

sources = files('src/poppler2json.vala')

executable('poppler2json', sources, dependencies: dependencies)