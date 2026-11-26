extends Node

# Android's DailyChallengeReceiver owns the repeating alarm and restores it
# after reboot. Godot only requests runtime notification permission.
func _ready() -> void:
	if OS.get_name() == "Android":
		OS.request_permissions()
