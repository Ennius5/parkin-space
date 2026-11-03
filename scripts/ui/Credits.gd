extends Control
## Credits: who made the art, sound and music, and under which licences.

const MODE_SELECT := "res://scenes/ui/ModeSelect.tscn"
const CREDITS_TEXT := """Parkin' Space

Ships and all other art: original, by ETHAN CAMPOMANES.

ART
Space Shooter Redux by Kenney (kenney.nl), CC0 1.0

FONT
Orbitron by The Orbitron Project Authors (Matt McInerney), SIL Open Font License 1.1

SOUND EFFECTS
Sci-Fi Sounds, Impact Sounds, Interface Sounds and Casino Audio
by Kenney (kenney.nl), CC0 1.0

MUSIC
Descent Mind Ascent – Mr. Pepino (https://ccmixter.org/files/Mr_Pepino/58734), CC BY-NC 3.0
Strange – Psykick (https://ccmixter.org/files/Psykick/52703), CC BY-NC 3.0
Never Stop Rising (Attic Ella Remix) – Attic Ella (https://ccmixter.org/files/Levihica/64389), CC BY-NC 3.0
squidgy – turkdirty (https://ccmixter.org/files/turkdirty/24695), CC BY-NC 3.0
just not right – turkdirty (https://ccmixter.org/files/turkdirty/21587), CC BY-NC 3.0

The music is licensed for non-commercial use only.
CC BY-NC 3.0: https://creativecommons.org/licenses/by-nc/3.0/

MADE for LAB 5 Activity in Special Topics in Software Development
Central Mindanao University College of Information Sciences and Computing -- Software Development -- BSIT 4C
November 2026 
Instructor: Rinante M. Buntod"""


func _ready() -> void:
	Sound.play_menu_music()
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 30
	box.offset_bottom = -30
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var text := Label.new()
	text.name = "Text"
	text.text = CREDITS_TEXT
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 28)
	scroll.add_child(text)
	text.owner = self
	text.unique_name_in_owner = true
	var back := Button.new()
	back.name = "Back"
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 96)
	back.add_theme_font_size_override("font_size", 32)
	back.pressed.connect(get_tree().change_scene_to_file.bind(MODE_SELECT))
	box.add_child(back)
	back.owner = self
	back.unique_name_in_owner = true
	Sound.wire_clicks(self)


## Where Android's back gesture leads from this screen ("" = quit the app).
func back_target() -> String:
	return MODE_SELECT


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if back_target() == "":
			get_tree().quit()
		else:
			get_tree().change_scene_to_file(back_target())
