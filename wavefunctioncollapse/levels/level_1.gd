extends Node2D

func _ready():
	$sample.hide()
	$negative_sample.hide()
	$target.show()

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
			$generator.start()
