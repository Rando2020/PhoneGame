class_name JsRng
extends RefCounted
## Bit-exact port of meta.js makeRng (xorshift32).
##
## JS does this with a mix of unsigned (>>>) and signed (>>) shifts on 32-bit
## integers. GDScript ints are 64-bit, so every step is masked back to 32 bits,
## and the >> 17 step is done on the SIGNED value, exactly as JS does it.

const MASK32 := 0xFFFFFFFF

var s: int


func _init(seed: int) -> void:
	s = seed & MASK32


func next() -> float:
	# s ^= s << 13; s >>>= 0
	s = (s ^ (s << 13)) & MASK32
	# s ^= s >> 17   (arithmetic shift on the int32 view)
	var si: int = s - 0x100000000 if s >= 0x80000000 else s
	si = si ^ (si >> 17)
	# s ^= s << 5; s >>>= 0
	s = (si ^ (si << 5)) & MASK32
	return s / 4294967296.0
