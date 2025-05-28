extends Control

const GRID_SIZE_X = 8
const GRID_SIZE_Y = 8
const PIECE_SIZE = 16
const PIECE_TYPES = 6

var grid := []
var piece_nodes := []
var piece_scenes := {}
var state_machine: Node
var operations: Node

const PieceTypes = preload("res://scenes/board/piece_types.gd")

# Use all types except 'debug' by default
var ALLOWED_PIECE_TYPES = []

# Toggle to include or exclude debug pieces
var INCLUDE_DEBUG_PIECE := false  # Set to true to include debug pieces

# Set the required number of connecting colors for a match
var MATCH_LENGTH := 4  # Change this to set how many connecting colors are required

@onready var piece_container = $PieceContainer

func _ready():
    ALLOWED_PIECE_TYPES = []
    for type_name in PieceTypes.PIECE_TYPES.keys():
        var type_data = PieceTypes.PIECE_TYPES[type_name]
        if type_data.has("scene") and type_data["scene"] != "" and ResourceLoader.exists(type_data["scene"]):
            if type_name != "debug":
                ALLOWED_PIECE_TYPES.append(type_name)
    var board_pixel_size = Vector2(GRID_SIZE_X * PIECE_SIZE, GRID_SIZE_Y * PIECE_SIZE)
    var win_size = get_viewport_rect().size
    piece_container.position = (win_size - board_pixel_size) / 2
    piece_container.size = board_pixel_size
    
    # Initialize state machine
    var state_machine_script = load("res://scenes/board/board_state_machine.gd")
    state_machine = state_machine_script.new(self)
    state_machine.set_match_length(MATCH_LENGTH) # Set match length on state machine
    add_child(state_machine)
    
    # Initialize operations
    var operations_script = load("res://scenes/board/board_operations.gd")
    operations = operations_script.new(self)
    add_child(operations)
    
    preload_piece_scenes()
    initialize_grid()
    spawn_visual_pieces()
    # Clear any initial matches (optionally, could avoid matches during population for efficiency)
    state_machine.clear_initial_matches()

func preload_piece_scenes():
    piece_scenes.clear()
    for type_name in ALLOWED_PIECE_TYPES:
        var type_data = PieceTypes.PIECE_TYPES.get(type_name, null)
        if type_data and type_data.has("scene") and ResourceLoader.exists(type_data["scene"]):
            piece_scenes[type_name] = load(type_data["scene"])
        else:
            push_error("Missing piece scene: %s" % (type_data["scene"] if type_data else type_name))
            piece_scenes[type_name] = null

func initialize_grid():
    grid = []
    for x in range(GRID_SIZE_X):
        grid.append([])
        for y in range(GRID_SIZE_Y):
            var allowed = ALLOWED_PIECE_TYPES
            var possible = allowed.duplicate()
            # Remove types that would cause a match horizontally
            if x >= MATCH_LENGTH - 1:
                var is_match = true
                for i in range(1, MATCH_LENGTH):
                    if grid[x - i][y] != grid[x - 1][y]:
                        is_match = false
                        break
                if is_match:
                    possible.erase(grid[x - 1][y])
            # Remove types that would cause a match vertically
            if y >= MATCH_LENGTH - 1:
                var is_match = true
                for i in range(1, MATCH_LENGTH):
                    if grid[x][y - i] != grid[x][y - 1]:
                        is_match = false
                        break
                if is_match:
                    possible.erase(grid[x][y - 1])
            # Pick randomly from possible types
            if possible.size() == 0:
                possible = allowed # fallback, should be rare
            grid[x].append(possible[randi() % possible.size()])

func spawn_visual_pieces():
    for child in piece_container.get_children():
        child.queue_free()
    piece_nodes = []
    for x in range(GRID_SIZE_X):
        piece_nodes.append([])
        for y in range(GRID_SIZE_Y):
            var piece_type = grid[x][y]
            var piece_scene = piece_scenes.get(piece_type, null)
            if piece_scene:
                var piece = piece_scene.instantiate()
                piece.position = Vector2(x, y) * PIECE_SIZE
                piece_container.add_child(piece)
                piece_nodes[x].append(piece)
            else:
                push_error("No piece scene for type %s at (%d, %d)" % [piece_type, x, y])
                piece_nodes[x].append(null)

func update_visual_positions():
    for x in range(GRID_SIZE_X):
        for y in range(GRID_SIZE_Y):
            if x < piece_nodes.size() and y < piece_nodes[x].size():
                var piece = piece_nodes[x][y]
                if piece:
                    piece.position = Vector2(x, y) * PIECE_SIZE
                else:
                    push_error("Null piece at (%d, %d)" % [x, y])
            else:
                push_error("Invalid grid index (%d, %d)" % [x, y])

func shift_row(y: int, direction: int):
    operations.shift_row(y, direction)

func shift_column(x: int, direction: int):
    operations.shift_column(x, direction)

func _input(event):
    state_machine.handle_input(event)
