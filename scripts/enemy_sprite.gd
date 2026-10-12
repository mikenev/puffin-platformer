class_name EnemySprite
## Code-drawn 16x16 placeholder for the "Snapper" crab enemy (original art).

const PAL := {
	".": Color(0, 0, 0, 0),
	"K": Color8(40, 16, 16),     # outline
	"R": Color8(208, 64, 48),    # shell
	"r": Color8(152, 40, 32),    # shell shade
	"W": Color8(248, 248, 240),  # eye white
	"E": Color8(8, 8, 8),        # pupil
	"C": Color8(232, 112, 72),   # claws / legs
}
const WALK1 := [
	"................",
	"................",
	"................",
	"....W......W....",
	"...WEW....WEW...",
	"....K......K....",
	"CC..K.KKKK.K..CC",
	"CCK.KKRRRRKK.KCC",
	".CKKRRRRRRRRKKC.",
	"...KRRRRRRRRK...",
	"...KRRrrrrRRK...",
	"....KKKKKKKK....",
	"....C..C.C..C...",
	"...C..C...C..C..",
	"................",
	"................",
]
const WALK2 := [
	"................",
	"................",
	"................",
	"....W......W....",
	"...WEW....WEW...",
	"....K......K....",
	".CC.K.KKKK.K.CC.",
	"CCK.KKRRRRKK.KCC",
	"CCKKRRRRRRRRKKCC",
	"...KRRRRRRRRK...",
	"...KRRrrrrRRK...",
	"....KKKKKKKK....",
	".....C.C..C.C...",
	"....C..C..C..C..",
	"................",
	"................",
]
const SQUASH := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"...W.E....E.W...",
	"CCKKRRRRRRRRKKCC",
	"CKKRRrrrrrrRRKKC",
	"..KKKKKKKKKKKK..",
	"................",
]

## Palette swaps: "walker" is a green shore beetle that reuses the crab body.
const LOOKS := {
	"crab": {},
	"walker": {"R": Color8(72, 168, 88), "r": Color8(40, 112, 56), "C": Color8(200, 184, 96)},
}

static func _tex(rows: Array, pal: Dictionary = PAL) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, pal[rows[y][x]])
	return ImageTexture.create_from_image(img)

static func build(look := "crab") -> SpriteFrames:
	var pal := PAL.duplicate()
	pal.merge(LOOKS.get(look, {}), true)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in [["walk", [WALK1, WALK2], 6.0], ["squash", [SQUASH], 1.0]]:
		sf.add_animation(anim[0])
		sf.set_animation_speed(anim[0], anim[2])
		for f in anim[1]:
			sf.add_frame(anim[0], _tex(f, pal))
	return sf

## Gull flyer frames (wings up / down) and its squashed frame.
const GULL_PAL := {
	".": Color(0, 0, 0, 0), "K": Color8(48, 48, 64), "W": Color8(244, 244, 236),
	"G": Color8(168, 176, 192), "O": Color8(248, 176, 40), "E": Color8(8, 8, 8),
}
const GULL1 := [
	"................",
	"................",
	"..GG........GG..",
	"..GWG......GWG..",
	"...GWG....GWG...",
	"....GWWWWWWG....",
	"....KWWWWWWEWOO.",
	".....KWWWWWWK...",
	"......KKKKKK....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const GULL2 := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"....GWWWWWWG....",
	"...GKWWWWWWEWOO.",
	"..GWGKWWWWWWK...",
	".GWG..KKKKKKGWG.",
	".GG..........GG.",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const GULL_SQUASH := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	".GG.KWWWWWWEWOG.",
	"GWGKKKKKKKKKKGWG",
	"................",
	"................",
]

static func build_gull() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in [["walk", [GULL1, GULL2], 5.0], ["squash", [GULL_SQUASH], 1.0]]:
		sf.add_animation(anim[0])
		sf.set_animation_speed(anim[0], anim[2])
		for f in anim[1]:
			sf.add_frame(anim[0], _tex(f, GULL_PAL))
	return sf
