extends Node2D

var gem_type: int = 0

func _ready():
    pass

func set_type(type: int):
    gem_type = type
    var sprite = $Sprite2D
    var texture = load("res://assets/sprites/gems/gem_" + str(type) + ".png")
    if texture:
        sprite.texture = texture 
