extends Node

signal item_found(item_name: String)
signal items_progress_updated(found_count: int, total_count: int)
signal score_updated(new_score: int)
signal lives_updated(new_lives: int)
signal game_over(won: bool)
signal ads_removed()
signal coins_updated(new_balance: int)

func emit_on_ads_removed() -> void:
	ads_removed.emit()
