extends CanvasLayer

@onready var frame_box = $Dimmer/Center/FrameBox
@onready var update_btn = $Dimmer/Center/FrameBox/Panel/VBox/UpdateBtn
@onready var close_btn = $Dimmer/Center/FrameBox/CloseBtn

const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=com.hiddenobject"
const MARKET_URL := "market://details?id=com.hiddenobject"

func _ready():
	close_btn.pressed.connect(_close)
	update_btn.pressed.connect(_on_update_pressed)
	_animate_in()

func _animate_in():
	frame_box.pivot_offset = frame_box.size * 0.5
	frame_box.scale = Vector2(0.7, 0.7)
	frame_box.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(frame_box, "modulate:a", 1.0, 0.2)

func _close():
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(frame_box, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)

func _on_update_pressed():
	if AdManager and AdManager.has_method("start_in_app_update") and AdManager._app_plugin:
		AdManager.start_in_app_update()
	else:
		if OS.get_name() == "Android":
			var err = OS.shell_open(MARKET_URL)
			if err != OK:
				OS.shell_open(PLAY_STORE_URL)
		else:
			OS.shell_open(PLAY_STORE_URL)
	_close()
