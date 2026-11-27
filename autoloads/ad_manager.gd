extends Node
## AdManager - Google AdMob integration (Poing AdMob Plugin v5)
## Enforces Google AdMob Policy Standard & 10 Anti-Suspension Rules

# Google Ad Unit IDs for difference-find
const ADMOB_APP_ID: String = "ca-app-pub-1852108665659812~9828050799"
const BANNER_AD_ID: String = "ca-app-pub-1852108665659812/2570759337"
const INTERSTITIAL_AD_ID: String = "ca-app-pub-1852108665659812/1949560770"
const REWARDED_AD_ID: String = "ca-app-pub-1852108665659812/6071020642"
const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=com.hiddenobject"
const MARKET_URL := "market://details?id=com.hiddenobject"

# --- AdMob Anti-Suspension Policy Constants ---
const INTERSTITIAL_EVERY_N_LEVELS := 3
const MIN_INTERSTITIAL_INTERVAL_SEC := 120.0
const MAX_INTERSTITIALS_PER_HOUR := 10
const ROLLING_HOUR_SEC := 3600.0

static var instance: Node
static var is_initialized: bool = false
var _plugin_available: bool = false

signal rewarded_video_completed
signal rewarded_video_unavailable(message: String)
signal rewarded_ready_changed(ready: bool)
signal in_app_update_available(available: bool)
signal in_app_update_downloaded

# Policy tracking variables
var levels_since_interstitial: int = 0
var last_interstitial_unix_sec: float = -9999.0
var interstitial_timestamps_sec: Array[float] = []
var gameplay_active: bool = false
var ads_suspended: bool = false # Master switch: set true to suppress all ads if account suspended
var reward_pending: bool = false

# Backoff retry timers (Rule 9: Exponential backoff 2s -> 4s -> 8s -> 16s -> 32s -> 64s)
var _banner_retry_delay: float = 2.0
var _interstitial_retry_delay: float = 2.0
var _rewarded_retry_delay: float = 2.0

# Cached loaded ad objects
var _banner_view_bottom = null
var _interstitial_ad = null
var _rewarded_ad = null

# Callback references
var _init_listener = null
var _banner_cb = null
var _interstitial_cb = null
var _rewarded_cb = null
var _reward_listener = null

var banner_id: String = BANNER_AD_ID
var interstitial_id: String = INTERSTITIAL_AD_ID
var rewarded_id: String = REWARDED_AD_ID

var _app_plugin: Object = null

func _enter_tree() -> void:
	instance = self

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and OS.get_name() == "Android":
		check_in_app_update()

func _ready() -> void:
	_init_app_plugin()
	if SignalHub:
		SignalHub.ads_removed.connect(on_ads_removed_changed)
	if OS.get_name() == "Android":
		_plugin_available = true
		_load_local_ad_ids()
		if OS.has_feature("debug"):
			banner_id = BANNER_AD_ID
			interstitial_id = INTERSTITIAL_AD_ID
			rewarded_id = REWARDED_AD_ID
		_init_admob()
	else:
		print("[AdManager] Desktop/Editor mode - ads simulated")

func _init_app_plugin() -> void:
	if Engine.has_singleton("AppPlugin"):
		_app_plugin = Engine.get_singleton("AppPlugin")
	elif Engine.has_singleton("GodotGooglePlayUpdate"):
		_app_plugin = Engine.get_singleton("GodotGooglePlayUpdate")
	
	if _app_plugin:
		if _app_plugin.has_signal("in_app_update_available"):
			_app_plugin.connect("in_app_update_available", Callable(self, "_on_plugin_update_available"))
		if _app_plugin.has_signal("in_app_update_downloaded"):
			_app_plugin.connect("in_app_update_downloaded", Callable(self, "_on_plugin_update_downloaded"))

func _on_plugin_update_available(available: bool) -> void:
	in_app_update_available.emit(available)

func _on_plugin_update_downloaded() -> void:
	in_app_update_downloaded.emit()

func check_in_app_update() -> void:
	if _app_plugin and _app_plugin.has_method("check_for_update"):
		_app_plugin.check_for_update()

func start_in_app_update() -> void:
	if _app_plugin and _app_plugin.has_method("start_update"):
		_app_plugin.start_update()
	else:
		if OS.get_name() == "Android":
			if OS.shell_open(MARKET_URL) != OK:
				OS.shell_open(PLAY_STORE_URL)
		else:
			OS.shell_open(PLAY_STORE_URL)

func request_rate_app() -> void:
	if _app_plugin and _app_plugin.has_method("request_review"):
		_app_plugin.request_review()
	else:
		if OS.get_name() == "Android":
			if OS.shell_open(MARKET_URL) != OK:
				OS.shell_open(PLAY_STORE_URL)
		else:
			OS.shell_open(PLAY_STORE_URL)

func request_share_game(custom_message: String = "") -> void:
	var msg := custom_message if not custom_message.is_empty() else ("Find all the hidden objects before lives run out! Play Difference Find:\n" + PLAY_STORE_URL)
	if _app_plugin and _app_plugin.has_method("share_text"):
		_app_plugin.share_text(msg)
	else:
		DisplayServer.clipboard_set(msg)

static func show_toast(message: String) -> void:
	if message.is_empty():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var pm = tree.root.get_node_or_null("PopupManager")
		if pm and pm.has_method("show_toast"):
			pm.show_toast(message)
			return
	print("[Toast] ", message)

func _load_local_ad_ids() -> void:
	if ResourceLoader.exists("res://admob_secrets.gd"):
		var secrets = load("res://admob_secrets.gd")
		if secrets != null:
			if "BANNER_AD_ID" in secrets and not str(secrets.BANNER_AD_ID).is_empty():
				banner_id = str(secrets.BANNER_AD_ID)
			if "INTERSTITIAL_AD_ID" in secrets and not str(secrets.INTERSTITIAL_AD_ID).is_empty():
				interstitial_id = str(secrets.INTERSTITIAL_AD_ID)
			if "REWARDED_AD_ID" in secrets and not str(secrets.REWARDED_AD_ID).is_empty():
				rewarded_id = str(secrets.REWARDED_AD_ID)

func _init_admob() -> void:
	if not _plugin_available:
		return
	if ClassDB.class_exists("OnInitializationCompleteListener"):
		_init_listener = ClassDB.instantiate("OnInitializationCompleteListener")
		_init_listener.on_initialization_complete = func(_status) -> void:
			print("[AdManager] Native AdMob initialized!")
			is_initialized = true
			_load_banner_bottom()
			_load_interstitial()
			_load_rewarded()
		if Engine.has_singleton("MobileAds"):
			Engine.get_singleton("MobileAds").initialize(_init_listener)

func is_ad_free() -> bool:
	if ads_suspended:
		return true
	if InAppPurchaseManager and InAppPurchaseManager.is_ads_removed:
		return true
	if not is_inside_tree():
		return false
	var billing := get_node_or_null("/root/BillingManager")
	if billing != null and billing.has_method("is_remove_ads_owned") and billing.is_remove_ads_owned():
		return true
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		if gm.has_method("is_ad_free_active") and gm.is_ad_free_active():
			return true
		if "ads_removed" in gm and gm.ads_removed:
			return true
	return false

func grant_temporary_ad_removal(duration_sec: float = 86400.0) -> void:
	var gm := get_node_or_null("/root/GameManager") if is_inside_tree() else null
	if gm != null:
		var now_sec := Time.get_unix_time_from_system()
		var base_sec := maxf(now_sec, gm.ad_free_until_unix)
		gm.ad_free_until_unix = base_sec + duration_sec
		gm.save_game()
	on_ads_removed_changed()
	show_toast("No-Ads unlocked for the next 24 hours!")

func on_ads_removed_changed() -> void:
	hide_banner()
	destroy_banner()
	_interstitial_ad = null

func set_gameplay_active(active: bool) -> void:
	gameplay_active = active
	if gameplay_active:
		hide_banner()

# =================== BANNER (RULE 6, RULE 8, RULE 10) ===================
func _load_banner_bottom() -> void:
	if not is_initialized or _banner_view_bottom != null or is_ad_free():
		return
	if not ClassDB.class_exists("AdView"):
		return
	_banner_view_bottom = ClassDB.instantiate("AdView")
	if _banner_view_bottom.has_method("load_ad"):
		_banner_view_bottom.load_ad()

func show_banner(_is_top: bool = false) -> void:
	if is_ad_free() or gameplay_active:
		hide_banner(_is_top)
		return
	if _banner_view_bottom != null and _banner_view_bottom.has_method("show"):
		_banner_view_bottom.show()
	elif is_initialized and _banner_view_bottom == null:
		_load_banner_bottom()

func hide_banner(_is_top: bool = false) -> void:
	if _banner_view_bottom != null and _banner_view_bottom.has_method("hide"):
		_banner_view_bottom.hide()

func destroy_banner(_is_top: bool = false) -> void:
	if _banner_view_bottom != null and _banner_view_bottom.has_method("destroy"):
		_banner_view_bottom.destroy()
	_banner_view_bottom = null

# =================== INTERSTITIAL (RULES 2, 3, 4, 5, 6, 9, 10) ===================
func on_level_completed(completed_level: int) -> bool:
	set_gameplay_active(false)
	if is_ad_free():
		return false
	# Rule 2: Level 1 must NEVER show an interstitial
	if completed_level <= 1:
		return false
	levels_since_interstitial += 1
	# Rule 3: Interstitial only every 3 completed levels
	if levels_since_interstitial >= INTERSTITIAL_EVERY_N_LEVELS:
		if can_show_interstitial_now():
			levels_since_interstitial = 0
			show_interstitial()
			return true
	return false

func can_show_interstitial_now() -> bool:
	if is_ad_free() or gameplay_active:
		return false
	if not is_interstitial_ready():
		return false
	var now_sec := Time.get_unix_time_from_system()
	# Rule 4: Minimum 120 seconds between interstitials
	if (now_sec - last_interstitial_unix_sec) < MIN_INTERSTITIAL_INTERVAL_SEC:
		return false
	# Rule 5: Maximum 10 interstitials per rolling hour
	_prune_hourly_interstitial_log(now_sec)
	if interstitial_timestamps_sec.size() >= MAX_INTERSTITIALS_PER_HOUR:
		return false
	return true

func _prune_hourly_interstitial_log(now_sec: float) -> void:
	var cutoff := now_sec - ROLLING_HOUR_SEC
	var pruned: Array[float] = []
	for ts in interstitial_timestamps_sec:
		if ts >= cutoff:
			pruned.append(ts)
	interstitial_timestamps_sec = pruned

func is_interstitial_ready() -> bool:
	if OS.get_name() != "Android":
		return true
	return _interstitial_ad != null

func _load_interstitial() -> void:
	if not is_initialized or is_ad_free() or _interstitial_ad != null:
		return
	if not ClassDB.class_exists("InterstitialAdLoader"):
		return
	var loader = ClassDB.instantiate("InterstitialAdLoader")
	_interstitial_cb = ClassDB.instantiate("InterstitialAdLoadCallback")
	_interstitial_cb.on_ad_loaded = func(ad) -> void:
		_interstitial_ad = ad
		_interstitial_retry_delay = 2.0
		if ad and "full_screen_content_callback" in ad:
			ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
				_interstitial_ad = null
				_load_interstitial()
			ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err):
				_interstitial_ad = null
				_load_interstitial()
	_interstitial_cb.on_ad_failed_to_load = func(_err) -> void:
		_interstitial_ad = null
		# Rule 9: Exponential backoff
		get_tree().create_timer(_interstitial_retry_delay).timeout.connect(_load_interstitial)
		_interstitial_retry_delay = minf(_interstitial_retry_delay * 2.0, 64.0)
	
	if ClassDB.class_exists("AdRequest"):
		loader.load(interstitial_id, ClassDB.instantiate("AdRequest"), _interstitial_cb)

func show_interstitial() -> void:
	if is_ad_free() or gameplay_active:
		return
	var now_sec := Time.get_unix_time_from_system()
	if _interstitial_ad != null and _interstitial_ad.has_method("show"):
		last_interstitial_unix_sec = now_sec
		interstitial_timestamps_sec.append(now_sec)
		_interstitial_ad.show()
	else:
		if is_initialized and not is_ad_free():
			_load_interstitial()

# =================== REWARDED (RULES 1, 7, 9) ===================
func is_rewarded_ready() -> bool:
	if ads_suspended:
		return false
	if OS.get_name() != "Android":
		return true
	return _rewarded_ad != null

func _load_rewarded() -> void:
	if not is_initialized or _rewarded_ad != null:
		return
	if not ClassDB.class_exists("RewardedAdLoader"):
		return
	var loader = ClassDB.instantiate("RewardedAdLoader")
	_rewarded_cb = ClassDB.instantiate("RewardedAdLoadCallback")
	_rewarded_cb.on_ad_loaded = func(ad) -> void:
		_rewarded_ad = ad
		_rewarded_retry_delay = 2.0
		rewarded_ready_changed.emit(true)
		if ad and "full_screen_content_callback" in ad:
			ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
				_rewarded_ad = null
				rewarded_ready_changed.emit(false)
				if reward_pending:
					reward_pending = false
					rewarded_video_completed.emit()
				_load_rewarded()
			ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err):
				_rewarded_ad = null
				reward_pending = false
				rewarded_ready_changed.emit(false)
				_load_rewarded()
	_rewarded_cb.on_ad_failed_to_load = func(_err) -> void:
		_rewarded_ad = null
		rewarded_ready_changed.emit(false)
		get_tree().create_timer(_rewarded_retry_delay).timeout.connect(_load_rewarded)
		_rewarded_retry_delay = minf(_rewarded_retry_delay * 2.0, 64.0)

	if ClassDB.class_exists("AdRequest"):
		loader.load(rewarded_id, ClassDB.instantiate("AdRequest"), _rewarded_cb)

func show_rewarded_video() -> void:
	if _rewarded_ad != null and _rewarded_ad.has_method("show"):
		_reward_listener = ClassDB.instantiate("OnUserEarnedRewardListener")
		_reward_listener.on_user_earned_reward = func(_reward) -> void:
			reward_pending = true
		_rewarded_ad.show(_reward_listener)
	else:
		if OS.get_name() != "Android":
			rewarded_video_completed.emit()
		else:
			rewarded_video_unavailable.emit("Video ad is still loading. Please try again in a moment.")
			show_toast("Video ad is still loading. Please try again shortly.")
			_load_rewarded()

func show_rewarded_ad(callback: Callable = Callable()) -> void:
	if OS.get_name() == "Android" and not is_rewarded_ready():
		show_toast("Video ad is still loading. Please try again shortly.")
		_load_rewarded()
		if callback.is_valid() and callback.get_argument_count() > 0:
			callback.call(false)
		return
	if callback.is_valid():
		rewarded_video_completed.connect(func():
			if callback.get_argument_count() == 0:
				callback.call()
			else:
				callback.call(true)
		, CONNECT_ONE_SHOT)
	show_rewarded_video()

func show_rewarded(callback: Callable = Callable()) -> void:
	show_rewarded_ad(callback)
