extends CanvasLayer

const GAME_FONT: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")

@onready var frame_box: Control = $Dimmer/Center/FrameBox
@onready var balance_label: Label = $Dimmer/Center/FrameBox/Panel/Margin/Layout/BalanceLabel
@onready var items_container: VBoxContainer = $Dimmer/Center/FrameBox/Panel/Margin/Layout/Scroll/Items
@onready var close_btn: Button = $Dimmer/Center/FrameBox/CloseBtn
@onready var bottom_close_btn: Button = $Dimmer/Center/FrameBox/Panel/Margin/Layout/BottomCloseBtn

const STORE_ITEMS := [
	{
		"id": "coins_1000",
		"icon": "🪙",
		"title": "1,000 COINS",
		"desc": "Great starter pack for quick hints!",
		"price": "$0.99",
		"type": "coins"
	},
	{
		"id": "coins_2000",
		"icon": "🪙",
		"title": "2,000 COINS",
		"desc": "Popular choice! Solve any tricky room.",
		"price": "$1.29",
		"type": "coins"
	},
	{
		"id": "coins_3000",
		"icon": "🪙",
		"title": "3,000 COINS",
		"desc": "Best value pack with maximum coins!",
		"price": "$1.99",
		"type": "coins"
	},
	{
		"id": "cofee",
		"icon": "☕",
		"title": "BUY COFFEE",
		"desc": "Support dev + get 300 bonus coins!",
		"price": "$1.49",
		"type": "coffee"
	},
	{
		"id": "remove_ads",
		"icon": "🚫",
		"title": "REMOVE ADS",
		"desc": "Uninterrupted ad-free detective experience!",
		"price": "$4.99",
		"type": "remove_ads"
	}
]

func _ready() -> void:
	close_btn.pressed.connect(_close)
	bottom_close_btn.pressed.connect(_close)
	_setup_restore_button()
	_update_balance()
	_build_items()
	_animate_in()

	if BillingManager:
		BillingManager.coin_purchase_changed.connect(func(_id, _coins):
			_update_balance()
			if PopupManager and PopupManager.has_method("play_flying_coins_effect"):
				var from_pos: Vector2 = balance_label.global_position + balance_label.size * 0.5
				PopupManager.play_flying_coins_effect(self, from_pos, Vector2.ZERO)
		)
		BillingManager.remove_ads_purchase_changed.connect(func(_owned):
			_build_items()
		)
		if BillingManager.has_signal("prices_updated"):
			BillingManager.prices_updated.connect(_build_items)
	if SignalHub:
		SignalHub.coins_updated.connect(func(_bal):
			_update_balance()
		)
		SignalHub.ads_removed.connect(_build_items)

func _setup_restore_button() -> void:
	var layout := $Dimmer/Center/FrameBox/Panel/Margin/Layout
	if not layout or layout.has_node("BottomRow"):
		return
	var row := HBoxContainer.new()
	row.name = "BottomRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	layout.add_child(row)

	var restore_btn := Button.new()
	restore_btn.name = "RestoreBtn"
	restore_btn.text = "Restore"
	restore_btn.custom_minimum_size = Vector2(150, 44)
	if PopupManager and PopupManager.has_method("style_primary_button"):
		PopupManager.style_primary_button(restore_btn, 17, Color(0.9, 0.95, 1.0))
	restore_btn.pressed.connect(func():
		if BillingManager and BillingManager.has_method("restore_purchases"):
			BillingManager.restore_purchases(func(_ok: bool):
				if is_instance_valid(self):
					_build_items()
			)
	)
	row.add_child(restore_btn)

	bottom_close_btn.reparent(row)

func _animate_in() -> void:
	var box_size := frame_box.size if frame_box.size != Vector2.ZERO else frame_box.custom_minimum_size
	frame_box.pivot_offset = box_size * 0.5
	frame_box.scale = Vector2(0.7, 0.7)
	frame_box.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(frame_box, "modulate:a", 1.0, 0.2)

func _close() -> void:
	var box_size := frame_box.size if frame_box.size != Vector2.ZERO else frame_box.custom_minimum_size
	frame_box.pivot_offset = box_size * 0.5
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(frame_box, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)

func _update_balance() -> void:
	var coins: int = GameManager.coins if GameManager else 0
	balance_label.text = "🪙  %s COINS" % _format_number(coins)

func _format_number(num: int) -> String:
	var s := str(num)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "," + result
	return result

func _build_items() -> void:
	for child in items_container.get_children():
		child.queue_free()

	for data in STORE_ITEMS:
		var item_card := _create_item_card(data)
		items_container.add_child(item_card)

func _create_item_card(data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(410, 88)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.17, 0.28, 0.95)
	sb.border_color = Color(0.3, 0.45, 0.65, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	card.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_child(hbox)
	card.add_child(margin)

	if str(data.get("type", "")) == "coins":
		var coin_tex := TextureRect.new()
		coin_tex.texture = preload("res://assets/main/coin_icon.png")
		coin_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin_tex.custom_minimum_size = Vector2(44, 44)
		hbox.add_child(coin_tex)
	else:
		var icon_lbl := Label.new()
		icon_lbl.text = data["icon"]
		icon_lbl.custom_minimum_size = Vector2(44, 44)
		icon_lbl.add_theme_font_size_override("font_size", 34)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(icon_lbl)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_lbl := Label.new()
	title_lbl.text = data["title"]
	title_lbl.add_theme_font_override("font", GAME_FONT)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color("#ffd54f"))
	title_lbl.add_theme_color_override("font_outline_color", Color(0.0823529, 0.12549, 0.243137, 1))
	title_lbl.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = data["desc"]
	desc_lbl.add_theme_font_override("font", GAME_FONT)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color("#e0e8f5"))
	desc_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	desc_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(desc_lbl)

	hbox.add_child(vbox)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(105, 46)

	var product_id := str(data.get("id", ""))
	var is_remove_ads_owned: bool = (product_id == "remove_ads" and BillingManager and BillingManager.is_remove_ads_owned())

	if is_remove_ads_owned:
		buy_btn.text = "OWNED ✓"
		buy_btn.disabled = true
		var dis_sb := StyleBoxFlat.new()
		dis_sb.bg_color = Color(0.3, 0.35, 0.45, 0.8)
		dis_sb.set_corner_radius_all(14)
		buy_btn.add_theme_stylebox_override("disabled", dis_sb)
		buy_btn.add_theme_font_override("font", GAME_FONT)
		buy_btn.add_theme_font_size_override("font_size", 14)
		buy_btn.add_theme_color_override("font_color", Color("#b0bec5"))
	else:
		var price_text: String = str(data["price"])
		if BillingManager and BillingManager.has_method("get_product_price"):
			price_text = BillingManager.get_product_price(product_id, price_text)
		buy_btn.text = price_text
		var btn_tex = preload("res://assets/main/button.png")
		var sb_norm := StyleBoxTexture.new()
		sb_norm.texture = btn_tex
		sb_norm.texture_margin_left = 12.0
		sb_norm.texture_margin_top = 10.0
		sb_norm.texture_margin_right = 12.0
		sb_norm.texture_margin_bottom = 10.0

		var sb_hov := StyleBoxTexture.new()
		sb_hov.texture = btn_tex
		sb_hov.texture_margin_left = 12.0
		sb_hov.texture_margin_top = 10.0
		sb_hov.texture_margin_right = 12.0
		sb_hov.texture_margin_bottom = 10.0
		sb_hov.modulate_color = Color(1.1, 1.1, 1.2, 1.0)

		var sb_press := StyleBoxTexture.new()
		sb_press.texture = btn_tex
		sb_press.texture_margin_left = 12.0
		sb_press.texture_margin_top = 10.0
		sb_press.texture_margin_right = 12.0
		sb_press.texture_margin_bottom = 10.0
		sb_press.modulate_color = Color(0.7, 0.7, 0.8, 1.0)

		buy_btn.add_theme_stylebox_override("normal", sb_norm)
		buy_btn.add_theme_stylebox_override("hover", sb_hov)
		buy_btn.add_theme_stylebox_override("pressed", sb_press)
		buy_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		buy_btn.add_theme_font_override("font", GAME_FONT)
		buy_btn.add_theme_font_size_override("font_size", 16)
		buy_btn.add_theme_color_override("font_color", Color("#fff9c4"))
		buy_btn.add_theme_color_override("font_outline_color", Color(0.0823529, 0.12549, 0.243137, 1))
		buy_btn.add_theme_constant_override("outline_size", 4)
		buy_btn.pressed.connect(_on_buy_pressed.bind(product_id))

	hbox.add_child(buy_btn)
	return card

func _on_buy_pressed(product_id: String) -> void:
	if BillingManager:
		BillingManager.purchase_product(product_id)
