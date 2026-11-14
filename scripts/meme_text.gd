class_name MemeText
extends RefCounted
## Loads and caches meme popup messages from res://data/meme_text.json.

const PATH: String = "res://data/meme_text.json"
const FALLBACK: PackedStringArray = PackedStringArray([
	"Hop!", "Much bounce", "Respect", "Hopy moment", "Too fast", "Wow"
])

static var _cache: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


static func load_messages() -> PackedStringArray:
	if _loaded:
		return _cache
	_loaded = true
	_cache = FALLBACK
	if not FileAccess.file_exists(PATH):
		return _cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Array):
		push_warning("MemeText: %s is not a JSON array. Using fallback messages." % PATH)
		return _cache
	var result := PackedStringArray()
	for item in parsed:
		if item is String and not str(item).strip_edges().is_empty():
			result.append(str(item))
	if not result.is_empty():
		_cache = result
	return _cache
