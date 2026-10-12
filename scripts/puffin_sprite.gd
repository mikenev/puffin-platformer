class_name PuffinSprite
## Builds the placeholder 16x16 puffin frames in code (original art). Returns SpriteFrames.

const PAL := {
	".": Color(0, 0, 0, 0),
	"K": Color8(24, 20, 32),     # black plumage
	"W": Color8(240, 240, 232),  # white face/belly
	"G": Color8(160, 160, 176),  # face shading
	"O": Color8(248, 120, 24),   # beak orange
	"R": Color8(200, 40, 40),    # beak red tip
	"Y": Color8(248, 200, 56),   # beak yellow band
	"F": Color8(248, 104, 32),   # feet
	"E": Color8(8, 8, 8),        # eye
}

const IDLE := [
	"................",
	".....KKKK.......",
	"....KWWWWK......",
	"...KWWEWWWK.....",
	"...KWGWWWYOO....",
	"...KWWWWWRRR....",
	"...KKWWWKK......",
	"..KKKWWWWKK.....",
	"..KKWWWWWWKK....",
	".KKKWWWWWWKK....",
	".KKKWWWWWWKK....",
	"..KKWWWWWWK.....",
	"..KKKWWWWKK.....",
	"...KKKKKKK......",
	"....F...F.......",
	"...FF..FF.......",
]
const RUN1 := [
	"................",
	".....KKKK.......",
	"....KWWWWK......",
	"...KWWEWWWK.....",
	"...KWGWWWYOO....",
	"...KWWWWWRRR....",
	"...KKWWWKK......",
	"..KKKWWWWKK.....",
	".KKKWWWWWWKK....",
	"KKK.WWWWWWKK....",
	".K..WWWWWWKK....",
	"..KKWWWWWWK.....",
	"..KKKWWWWKK.....",
	"...KKKKKKK......",
	"...F.....F......",
	"..FF.....FF.....",
]
const RUN2 := [
	"................",
	"................",
	".....KKKK.......",
	"....KWWWWK......",
	"...KWWEWWWK.....",
	"...KWGWWWYOO....",
	"...KWWWWWRRR....",
	"..KKKWWWKKK.....",
	"..KKWWWWWWKK....",
	".KKKWWWWWWKK....",
	".KKKWWWWWWKK....",
	"..KKWWWWWWK.....",
	"..KKKWWWWKK.....",
	"...KKKKKKK......",
	".....FF.........",
	"....FF..........",
]
const JUMP := [
	"................",
	".....KKKK.......",
	"....KWWWWK......",
	"...KWWEWWWK.....",
	"...KWGWWWYOO....",
	"...KWWWWWRRR....",
	"K..KKWWWKK...K..",
	"KK.KKWWWWK..KK..",
	".KKKWWWWWWKKK...",
	"..KKWWWWWWKK....",
	"..KKWWWWWWK.....",
	"..KKWWWWWWK.....",
	"..KKKWWWWKK.....",
	"...KKKKKKK......",
	"...FF..FF.......",
	"................",
]

const SKID := [
	"................",
	"......KKKK......",
	".....KWWWWK.....",
	"....KWWEWWWK....",
	"....KWGWWWYOO...",
	"....KWWWWWRRR...",
	"....KKWWWKK.....",
	"...KKKWWWWKK....",
	"..KKWWWWWWKK....",
	"..KKWWWWWWKK....",
	"..KKWWWWWWKK....",
	"..KKWWWWWWK.....",
	"..KKKWWWWKK.....",
	"..KKKKKKKK......",
	".FF....F........",
	"FF.....FF.......",
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
	for anim in [["idle", [IDLE], 1.0], ["run", [RUN1, IDLE, RUN2, IDLE], 12.0], ["jump", [JUMP], 1.0], ["fall", [IDLE], 1.0], ["skid", [SKID], 1.0]]:
		sf.add_animation(anim[0])
		sf.set_animation_speed(anim[0], anim[2])
		for f in anim[1]:
			sf.add_frame(anim[0], _tex(f))
	return sf
