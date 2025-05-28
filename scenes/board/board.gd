extends Control

const GRID_SIZE_X = 8
const GRID_SIZE_Y = 8
const GEM_SIZE = 16
const GEM_TYPES = 6

var grid := []
var gem_nodes := []
var gem_scenes := {}
var state_machine: Node
var operations: Node

# Toggle to include or exclude the debug gem (gem_0)
var INCLUDE_DEBUG_GEM := false  # Set to true to include the debug gem

# Use a dynamic list of allowed gem indices based on the toggle
var ALLOWED_GEM_INDICES = []

@onready var gem_container = $GemContainer

func _ready():
    ALLOWED_GEM_INDICES = range(0, 6) if INCLUDE_DEBUG_GEM else range(1, 6)
    var board_pixel_size = Vector2(GRID_SIZE_X * GEM_SIZE, GRID_SIZE_Y * GEM_SIZE)
    var win_size = get_viewport_rect().size
    gem_container.position = (win_size - board_pixel_size) / 2
    gem_container.size = board_pixel_size
    
    # Initialize state machine
    var state_machine_script = load("res://scenes/board/board_state_machine.gd")
    state_machine = state_machine_script.new(self)
    add_child(state_machine)
    
    # Initialize operations
    var operations_script = load("res://scenes/board/board_operations.gd")
    operations = operations_script.new(self)
    add_child(operations)
    
    preload_gem_scenes()
    initialize_grid()
    spawn_visual_gems()

func preload_gem_scenes():
    gem_scenes.clear()
    for i in ALLOWED_GEM_INDICES:
        var path = "res://scenes/board/gems/gem_%d.tscn" % i
        if ResourceLoader.exists(path):
            gem_scenes[i] = load(path)
        else:
            push_error("Missing gem scene: %s" % path)
            gem_scenes[i] = null

func initialize_grid():
    grid = []
    for x in range(GRID_SIZE_X):
        grid.append([])
        for y in range(GRID_SIZE_Y):
            # Only use allowed gem indices
            var allowed = ALLOWED_GEM_INDICES
            grid[x].append(allowed[randi() % allowed.size()])

func spawn_visual_gems():
    for child in gem_container.get_children():
        child.queue_free()
    gem_nodes = []
    for x in range(GRID_SIZE_X):
        gem_nodes.append([])
        for y in range(GRID_SIZE_Y):
            var gem_type = grid[x][y]
            var gem_scene = gem_scenes.get(gem_type, null)
            if gem_scene:
                var gem = gem_scene.instantiate()
                gem.position = Vector2(x, y) * GEM_SIZE
                gem_container.add_child(gem)
                gem_nodes[x].append(gem)
            else:
                push_error("No gem scene for type %d at (%d, %d)" % [gem_type, x, y])
                gem_nodes[x].append(null)

func update_visual_positions():
    for x in range(GRID_SIZE_X):
        for y in range(GRID_SIZE_Y):
            if x < gem_nodes.size() and y < gem_nodes[x].size():
                var gem = gem_nodes[x][y]
                if gem:
                    gem.position = Vector2(x, y) * GEM_SIZE
                else:
                    push_error("Null gem at (%d, %d)" % [x, y])
            else:
                push_error("Invalid grid index (%d, %d)" % [x, y])

func shift_row(y: int, direction: int):
    operations.shift_row(y, direction)

func shift_column(x: int, direction: int):
    operations.shift_column(x, direction)

func _input(event):
    state_machine.handle_input(event)
