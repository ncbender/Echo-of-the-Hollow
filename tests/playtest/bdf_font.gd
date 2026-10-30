extends RefCounted
## Body Font Final Selection 1.1 (preview only): builds a Godot FontFile from an original BDF bitmap
## font (GohuFont is distributed only as BDF). Every glyph bitmap is copied 1:1 into one atlas; glyph
## index = Unicode code point (as Godot's own bitmap fonts do). The font keeps its fixed pixel size and
## scales only by whole multiples (FIXED_SIZE_SCALE_INTEGER_ONLY), so it stays a true pixel font.


static func load_bdf(path: String) -> FontFile:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("BDF %s missing" % path)
		return null
	var ascent := 0
	var descent := 0
	var pixel_size := 0
	var name := path.get_file().get_basename()
	var glyphs: Array[Dictionary] = []
	var current: Dictionary = {}
	var rows: PackedStringArray = []
	var in_bitmap := false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		var parts := line.split(" ", false)
		if parts.is_empty():
			continue
		if in_bitmap:
			if parts[0] == "ENDCHAR":
				current.rows = rows
				glyphs.append(current)
				in_bitmap = false
			else:
				rows.append(parts[0])
			continue
		match parts[0]:
			"FAMILY_NAME":
				name = line.get_slice("\"", 1)
			"PIXEL_SIZE":
				pixel_size = int(parts[1])
			"FONT_ASCENT":
				ascent = int(parts[1])
			"FONT_DESCENT":
				descent = int(parts[1])
			"STARTCHAR":
				current = {"code": -1, "advance": 0, "w": 0, "h": 0, "x": 0, "y": 0}
			"ENCODING":
				current.code = int(parts[1])
			"DWIDTH":
				current.advance = int(parts[1])
			"BBX":
				current.w = int(parts[1])
				current.h = int(parts[2])
				current.x = int(parts[3])
				current.y = int(parts[4])
			"BITMAP":
				rows = PackedStringArray()
				in_bitmap = true
	var size := ascent + descent if pixel_size <= 0 else pixel_size
	# atlas: glyphs in rows, 1 px padding
	var atlas_width := 512
	var x := 1
	var y := 1
	var row_height := 0
	var places: Array[Vector2i] = []
	for glyph in glyphs:
		if x + glyph.w + 1 > atlas_width:
			x = 1
			y += row_height + 1
			row_height = 0
		places.append(Vector2i(x, y))
		x += glyph.w + 1
		row_height = maxi(row_height, glyph.h)
	var image := Image.create_empty(atlas_width, nearest_po2(y + row_height + 1), false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for i in glyphs.size():
		var glyph := glyphs[i]
		for r in glyph.rows.size():
			var hex: String = glyph.rows[r]
			for c in glyph.w:
				var nibble := hex.substr(c / 4, 1).hex_to_int()
				if nibble & (8 >> (c % 4)):
					image.set_pixel(places[i].x + c, places[i].y + r, Color.WHITE)
	var font := FontFile.new()
	font.font_name = name
	font.fixed_size = size
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.generate_mipmaps = false
	font.allow_system_fallback = false
	var key := Vector2i(size, 0)
	font.set_cache_ascent(0, size, ascent)
	font.set_cache_descent(0, size, descent)
	font.set_texture_image(0, key, 0, image)
	for i in glyphs.size():
		var glyph := glyphs[i]
		if glyph.code < 0:
			continue
		font.set_glyph_advance(0, size, glyph.code, Vector2(glyph.advance, 0))
		font.set_glyph_offset(0, key, glyph.code, Vector2(glyph.x, -(glyph.y + glyph.h)))
		font.set_glyph_size(0, key, glyph.code, Vector2(glyph.w, glyph.h))
		font.set_glyph_uv_rect(0, key, glyph.code, Rect2(places[i], Vector2(glyph.w, glyph.h)))
		font.set_glyph_texture_idx(0, key, glyph.code, 0)
	return font
