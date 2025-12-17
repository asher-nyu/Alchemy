extends Node

var player

func _ready():
	player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = load("res://assets/Audio Pack/background2.ogg")
	player.volume_db = linear_to_db(0.1)
	player.play()
	player.connect("finished", Callable(self, "_on_music_finished"))

func _on_music_finished():
	player.play()
