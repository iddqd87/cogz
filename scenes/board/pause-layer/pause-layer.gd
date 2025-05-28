extends Control

func _ready():
    hide()

func _input(event):
    if event.is_action_pressed("pause"):
        if visible:
            _on_resume_button_pressed()
        else:
            show()
            get_tree().paused = true

func _on_resume_button_pressed():
    hide()
    get_tree().paused = false

func _on_menu_button_pressed():
    get_tree().paused = false
    Game.change_scene_to_file("res://scenes/menu/menu.tscn") 
