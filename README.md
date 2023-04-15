# poppler2json

```bash
meson setup build
meson compile -C build
```

Basic file format: zip file with a gziped json file for each page, a png/svg for each page and an index.json that has page labels and thumbnails.