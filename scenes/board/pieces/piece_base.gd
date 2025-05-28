extends Node2D

# Future-proof dynamic type/texture logic for multiple piece categories (e.g., gems, gears)

func set_type(type_name: String):
    var sprite = $Sprite2D
    var texture_path = ""
    if type_name.begins_with("gem_"):
        texture_path = "res://assets/sprites/gems/" + type_name + ".png"
    elif type_name.begins_with("gear_"):
        texture_path = "res://assets/sprites/gears/" + type_name + ".png"
    # Add more categories as needed
    if texture_path != "":
        var texture = load(texture_path)
        if texture:
            sprite.texture = texture

func _ready():
    pass
