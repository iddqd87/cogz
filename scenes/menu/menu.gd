extends Control

@onready var btn_play = $MarginContainer/Control/VBoxContainer/PlayButton
@onready var btn_exit = $MarginContainer/Control/VBoxContainer/ExitButton

func _ready():
    # needed for gamepads to work
    btn_play.grab_focus()
    if OS.has_feature('web'):
        btn_exit.queue_free() # exit button dosn't make sense on HTML5

func _on_PlayButton_pressed() -> void:
    var params = {
        "show_progress_bar": false,
        "a_number": 10,
        "a_string": "Ciao!",
        "an_array": [1, 2, 3, 4],
        "a_dict": {
            "name": "test",
            "val": 15
        },
    }
    Game.change_scene_to_file("res://scenes/board/board.tscn", params)

func _on_ExitButton_pressed() -> void:
    # gently shutdown the game
    var transitions = get_node_or_null("/root/Transitions")
    if transitions:
        transitions.fade_in({
            'show_progress_bar': false
        })
        await transitions.anim.animation_finished
        await get_tree().create_timer(0.3).timeout
    get_tree().quit()
