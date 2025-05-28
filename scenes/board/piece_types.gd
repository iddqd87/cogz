# Centralized piece type configuration
# Scene-to-Color Mapping:
# - gem_0.tscn is DEBUG (test piece)
# - gem_1.tscn is GREEN
# - gem_2.tscn is BLUE
# - gem_3.tscn is YELLOW
# - gem_4.tscn is RED
# - gem_5.tscn is PINK
# - gear_0.tscn is DEBUG GEAR (future use)
# - gear_1.tscn is GREEN GEAR (future use)
# - (add more here)

const PIECE_TYPES = {
    "debug": {
        "scene": "res://scenes/board/pieces/gem_0.tscn",
        "matchable": true
    },
    "green": {
        "scene": "res://scenes/board/pieces/gem_1.tscn",
        "matchable": true
    },
    "blue": {
        "scene": "res://scenes/board/pieces/gem_2.tscn",
        "matchable": true
    },
    "yellow": {
        "scene": "res://scenes/board/pieces/gem_3.tscn",
        "matchable": true
    },
    "red": {
        "scene": "res://scenes/board/pieces/gem_4.tscn",
        "matchable": true
    },
    "pink": {
        "scene": "res://scenes/board/pieces/gem_5.tscn",
        "matchable": true
    },
    "gear": {
        "scene": "res://scenes/board/pieces/gem_gear.tscn",
        "matchable": false
    }
} 
