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

static func _tex(rows: Array) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, PAL[rows[y][x]])
	return ImageTexture.create_from_image(img)

static func build() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in [["walk", [WALK1, WALK2], 6.0], ["squash", [SQUASH], 1.0]]:
		sf.add_animation(anim[0])
		sf.set_animation_speed(anim[0], anim[2])
		for f in anim[1]:
			sf.add_frame(anim[0], _tex(f))
	return sf
