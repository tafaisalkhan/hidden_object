extends CanvasLayer

@onready var frame_box = $Dimmer/Center/FrameBox
@onready var share_btn = $Dimmer/Center/FrameBox/Panel/VBox/ShareBtn
@onready var close_btn = $Dimmer/Center/FrameBox/CloseBtn

const SHARE_MESSAGE := "🔎 Can you find all the hidden objects before time runs out? Play Difference Find with me!\nhttps://play.google.com/store/apps/details?id=com.hiddenobject"

func _ready():
	close_btn.pressed.connect(_close)
	share_btn.pressed.connect(_on_share_pressed)
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

func _on_share_pressed():
	if OS.has_feature("android"):
		var intent = JavaScriptBridge if OS.has_feature("web") else null
		# Native android share via OS
		DisplayServer.clipboard_set(SHARE_MESSAGE)
	else:
		DisplayServer.clipboard_set(SHARE_MESSAGE)
	
	share_btn.text = "COPIED TO CLIPBOARD! ✓"
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(self):
			_close()
	)
