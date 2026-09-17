extends "res://scripts/ui_racer_stage.gd"
## The Garage shares the native lineup's lighting and resolution handling.
var character_index := 0
var active := false
var kart: Node3D

func _ready() -> void:
	characters.assign([character_index])
	selected_character=character_index
	single_preview=true
	super._ready()
	if not karts.is_empty(): kart=karts[0]
	# The garage is a close-up showcase for every supplied asset-sheet cat.
	# Their transparent front-left sprites preserve the expressive fur, mouth,
	# and halo detail at this large scale; the live kart remains the fallback for
	# the two characters without a supplied sheet.
	if mode == "cats" and REFERENCE_SPRITES.has(character_index):
		if is_instance_valid(kart): kart.visible=false
		var sprite := TextureRect.new()
		sprite.name = "ReferenceGarageSprite"
		var garage_path: String = str(REFERENCE_GARAGE_SPRITES.get(character_index, REFERENCE_SPRITES[character_index]))
		sprite.texture = load(garage_path if ResourceLoader.exists(garage_path) else str(REFERENCE_SPRITES[character_index]))
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Garage previews are displayed several times larger than the roster cards.
		# Use the premultiplied 3x reference canvas with mipmapped bilinear sampling
		# so fur strands, paws and tire edges stay crisp instead of turning into a
		# low-resolution matte when the menu is resized.
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.position = Vector2(8, -4)
		sprite.size = size - Vector2(16, -8)
		sprite.z_index = 0
		add_child(sprite)
