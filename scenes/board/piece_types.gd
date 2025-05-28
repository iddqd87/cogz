# Gem type configuration for board
# Add new types and their properties here

const MATCHABLE_TYPES = {
    "red": true,
    "green": true,
    "blue": true,
    "yellow": true,
    "purple": true,
    "debug": true, # for gem_0
    "gear": false # example future type
}

const GEM_TYPE_SCENES = {
    "debug": "res://scenes/board/pieces/gem_0.tscn",
    "green": "res://scenes/board/pieces/gem_1.tscn",
    "blue": "res://scenes/board/pieces/gem_2.tscn",
    "yellow": "res://scenes/board/pieces/gem_3.tscn",
    "purple": "res://scenes/board/pieces/gem_4.tscn",
    "red": "res://scenes/board/pieces/gem_5.tscn",
    "gear": "res://scenes/board/pieces/gem_gear.tscn" # placeholder for future
} 