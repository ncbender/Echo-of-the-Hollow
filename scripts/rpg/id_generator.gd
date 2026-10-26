class_name IdGenerator
extends RefCounted
## Collision-resistant ids for runtime instances (characters, items).
## 64 random bits from the OS CSPRNG, hex encoded.

static var _crypto := Crypto.new()


static func new_id(prefix: String) -> String:
	return "%s_%s" % [prefix, _crypto.generate_random_bytes(8).hex_encode()]
