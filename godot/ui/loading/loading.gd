extends TextureRect

@onready var progress_bar := %ProgressBar
@onready var label := %Label
@onready var seconds_elapsed_label := %SecondsElapsedLabel
@onready var timer := %Timer

var progress_tween: Tween
var seconds_elapsed := 0


func render_loading(matchmaking: bool) -> void:
	if matchmaking:
		label.text = "FINDING MATCH..."
		seconds_elapsed_label.text = "0:00"
		progress_bar.hide()
		seconds_elapsed_label.show()
		timer.start()
	else:
		label.text = "LOADING..."
		progress_bar.value = 0.0
		progress_bar.show()
		seconds_elapsed_label.hide()


func set_progress(percent: float) -> void:
	if progress_tween:
		progress_tween.kill()

	progress_tween = create_tween()
	progress_tween.tween_property(
		progress_bar,
		"value",
		clampf(percent, 0.0, 100.0),
		0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_timer_timeout() -> void:
	seconds_elapsed += 1
	seconds_elapsed_label.text = "0:%02d" % seconds_elapsed
