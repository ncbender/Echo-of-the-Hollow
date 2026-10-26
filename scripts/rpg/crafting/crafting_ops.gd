class_name CraftingOps
extends RefCounted
## Stable ids of the crafting operations (engine verbs, not content). Costs and
## texts of each operation are data (CraftingOperationDefinition).

const IMPRINT := &"imprint"
const AUGMENT := &"augment"
const REFORGE := &"reforge"
const ESSENCE_INSERT := &"essence_insert"
const ESSENCE_EXTRACT := &"essence_extract"
const SOCKET_OPEN := &"socket_open"
const SOCKET_INSERT := &"socket_insert"
const SOCKET_REMOVE := &"socket_remove"
const QUALITY := &"quality"
const EVOLVE := &"evolve"

const ALL: Array[StringName] = [IMPRINT, AUGMENT, REFORGE, ESSENCE_INSERT, ESSENCE_EXTRACT,
	SOCKET_OPEN, SOCKET_INSERT, SOCKET_REMOVE, QUALITY, EVOLVE]
## Operations that roll affixes (the preview shows their weighted outcome pool).
const ROLLING: Array[StringName] = [IMPRINT, AUGMENT, REFORGE]
