extends Node

# Google AdMob App ID and Ad Unit IDs
const ADMOB_APP_ID: String = "ca-app-pub-1852108665659812~9828050799"
const BANNER_AD_ID: String = "ca-app-pub-1852108665659812/2570759337"
const INTERSTITIAL_AD_ID: String = "ca-app-pub-1852108665659812/1949560770"
const REWARDED_AD_ID: String = "ca-app-pub-1852108665659812/6071020642"

static var instance: Node
static var is_initialized: bool = false
signal on_admob_initialized

# Cached loaded ad objects (Poing AdMob v5 pattern)
var _banner_view = null
var _interstitial_ad = null
var _rewarded_ad = null


func _enter_tree() -> void:
	print("[AdManager] _enter_tree")
	instance = self


func _ready() -> void:
	print("[AdManager] _ready start")
	if ClassDB.class_exists("MobileAds") or Engine.has_singleton("MobileAds") or ClassDB.class_exists("OnInitializationCompleteListener"):
		_init_admob()
	else:
		print("[AdManager] MobileAds classes not present in this build environment (Editor/Desktop mode).")


func _init_admob() -> void:
	if not ClassDB.class_exists("OnInitializationCompleteListener"):
		return
		
	var init_listener = ClassDB.instantiate("OnInitializationCompleteListener") if ClassDB.can_instantiate("OnInitializationCompleteListener") else null
	if not init_listener:
		return
		
	init_listener.on_initialization_complete = func(_status) -> void:
		print("[AdManager] MobileAds native initialization complete!")
		is_initialized = true
		on_admob_initialized.emit()
		_load_banner()
		_load_interstitial()
		_load_rewarded()
		
	if ClassDB.class_exists("MobileAds"):
		var mobile_ads_script = load("res://addons/admob/gdscript/mobile_ads.gd")
		if mobile_ads_script and mobile_ads_script.has_method("initialize"):
			mobile_ads_script.initialize(init_listener)
		elif Engine.has_singleton("MobileAds"):
			Engine.get_singleton("MobileAds").initialize(init_listener)
	print("[AdManager] MobileAds initialization requested.")


# ── Banner Ad ───────────────────────────────────────────────────────────────

func _load_banner() -> void:
	if InAppPurchaseManager.is_ads_removed:
		print("[AdManager] Banner skipped: Ads removed via IAP.")
		return
	if not is_initialized or not ClassDB.class_exists("AdView"):
		return
		
	if _banner_view != null:
		return # Already loaded
		
	var ad_size = ClassDB.instantiate("AdSize")
	var banner_size = ad_size.BANNER if ("BANNER" in ad_size) else null
	var ad_position = ClassDB.instantiate("AdPosition")
	var bottom_pos = ad_position.BOTTOM if ("BOTTOM" in ad_position) else 1
	
	_banner_view = ClassDB.instantiate("AdView")
	_banner_view.create(BANNER_AD_ID, banner_size, bottom_pos)
	
	var cb = ClassDB.instantiate("AdListener")
	cb.on_ad_loaded = func():
		print("[AdManager] Banner loaded successfully!")
	cb.on_ad_failed_to_load = func(_err):
		print("[AdManager] Banner failed to load.")
	_banner_view.ad_listener = cb
	
	var req = ClassDB.instantiate("AdRequest")
	_banner_view.load_ad(req)


static func show_banner() -> void:
	if InAppPurchaseManager.is_ads_removed:
		return
	if instance:
		if instance._banner_view == null:
			instance._load_banner()
		elif instance._banner_view.has_method("show"):
			instance._banner_view.show()


static func hide_banner() -> void:
	if instance and instance._banner_view and instance._banner_view.has_method("hide"):
		instance._banner_view.hide()


static func destroy_banner() -> void:
	if instance and instance._banner_view and instance._banner_view.has_method("destroy"):
		instance._banner_view.destroy()
		instance._banner_view = null


# ── Interstitial Ad ─────────────────────────────────────────────────────────

func _load_interstitial() -> void:
	if not is_initialized or not ClassDB.class_exists("InterstitialAdLoader"):
		print("[AdManager] Interstitial load postponed: Waiting for AdMob initialization.")
		return
		
	var loader = ClassDB.instantiate("InterstitialAdLoader")
	var cb = ClassDB.instantiate("InterstitialAdLoadCallback")
	var req = ClassDB.instantiate("AdRequest")
	
	cb.on_ad_loaded = func(ad) -> void:
		_interstitial_ad = ad
		print("[AdManager] Interstitial Ad loaded successfully!")
		# Auto-reload after dismiss so a fresh ad is ready next time
		ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
			_interstitial_ad = null
			_load_interstitial()
		ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err):
			_interstitial_ad = null
			_load_interstitial()
			
	cb.on_ad_failed_to_load = func(_err) -> void:
		_interstitial_ad = null
		print("[AdManager] Interstitial Ad failed to load.")
		
	loader.load(INTERSTITIAL_AD_ID, req, cb)


static func show_interstitial_ad() -> void:
	if InAppPurchaseManager.is_ads_removed:
		print("[AdManager] Interstitial Ad skipped: Ads removed via IAP.")
		return
		
	if instance and instance._interstitial_ad:
		instance._interstitial_ad.show()
	else:
		show_toast("Ad not ready yet.")
		if instance:
			instance._load_interstitial()


# ── Rewarded Ad ─────────────────────────────────────────────────────────────

func _load_rewarded() -> void:
	if not is_initialized or not ClassDB.class_exists("RewardedAdLoader"):
		print("[AdManager] Rewarded ad load postponed: Waiting for AdMob initialization.")
		return
		
	var loader = ClassDB.instantiate("RewardedAdLoader")
	var cb = ClassDB.instantiate("RewardedAdLoadCallback")
	var req = ClassDB.instantiate("AdRequest")
	
	cb.on_ad_loaded = func(ad) -> void:
		_rewarded_ad = ad
		print("[AdManager] Rewarded Ad loaded successfully!")
		ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
			_rewarded_ad = null
			_load_rewarded()
		ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err):
			_rewarded_ad = null
			_load_rewarded()
			
	cb.on_ad_failed_to_load = func(_err) -> void:
		_rewarded_ad = null
		print("[AdManager] Rewarded Ad failed to load.")
		
	loader.load(REWARDED_AD_ID, req, cb)


static func show_rewarded_ad(on_reward_earned: Callable) -> void:
	print("[AdManager] Showing Google Rewarded Ad: ", REWARDED_AD_ID)
	if instance and instance._rewarded_ad:
		var user_rewarded: Array[bool] = [false]
		
		var reward_listener = ClassDB.instantiate("OnUserEarnedRewardListener")
		reward_listener.on_user_earned_reward = func(_item):
			user_rewarded[0] = true
			
		instance._rewarded_ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
			instance._rewarded_ad = null
			instance._load_rewarded()
			if user_rewarded[0] and on_reward_earned.is_valid():
				on_reward_earned.call()
				
		instance._rewarded_ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err):
			instance._rewarded_ad = null
			instance._load_rewarded()
			if on_reward_earned.is_valid():
				on_reward_earned.call()
				
		instance._rewarded_ad.show(reward_listener)
	else:
		show_toast("Ad not ready yet. Granting reward...")
		if instance:
			instance._load_rewarded()
		# Fallback invoke callback so game flow doesn't freeze in editor/simulator
		if on_reward_earned.is_valid():
			on_reward_earned.call()


# ── Toast helper ────────────────────────────────────────────────────────────

static func show_toast(message: String) -> void:
	print("[AdManager Toast]: ", message)
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root: return

	var toast_bg = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.85, 0.2, 0.9)
	toast_bg.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_font_size_override("font_size", 18)
	toast_bg.add_child(label)

	toast_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_bg.offset_top = -100
	toast_bg.offset_bottom = -50
	toast_bg.z_index = 300
	toast_bg.modulate.a = 0.0

	tree.root.add_child(toast_bg)

	var tween = toast_bg.create_tween()
	tween.tween_property(toast_bg, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(toast_bg, "modulate:a", 0.0, 0.3)
	tween.tween_callback(toast_bg.queue_free)
