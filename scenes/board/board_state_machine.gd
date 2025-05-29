extends Node

enum BoardState {
    IDLE,            # Waiting for player input
    DRAGGING,        # Player is dragging a row/column
    SHIFTING_ROW,    # Row is being shifted
    SHIFTING_COLUMN, # Column is being shifted
    MATCH_FIND,      # Find all matches
    MATCH_ANIMATE,   # Animate and remove matches (with delay)
    CASCADE_ANIMATE  # Animate falling tiles and refill (with delay)
}

# TWEAK SETTINGS
var match_delay := 0.05 # seconds (simulate match disappear animation)
# Add more tweakable settings here as needed

# --- Signals for future use (connect in the editor or code) ---
@warning_ignore("unused_signal")
signal _line_raised(pieces)
@warning_ignore("unused_signal")
signal _line_lowered(pieces)
@warning_ignore("unused_signal")
signal _piece_fell(piece)

# Board state variables
var current_state: BoardState = BoardState.IDLE
var board: Node
var pending_matches := []
var combo_count := 0 # Tracks consecutive matches/cascades

# Drag state variables
var drag_start_pos := Vector2.ZERO
var drag_mode := ""      # "row" or "column"
var drag_index := -1     # Locked row or column index
var drag_last_shift := 0 # Prevents multiple shifts per cell

# Board lock state
var input_locked := false

const PieceTypes = preload("res://scenes/board/piece_types.gd")

# --- EffectsStateMachine integration ---
@onready var effects_state_machine = get_node_or_null("../effects_state_machine")
var effects_enabled := true # Toggle to enable/disable all effects

var debug_mode := false # Toggle debug output

func set_board(board_node):
    board = board_node

func enter_state(new_state: BoardState):
    var previous_state = current_state
    current_state = new_state
    # Lock/unlock input based on state
    if current_state in [BoardState.MATCH_FIND, BoardState.MATCH_ANIMATE, BoardState.CASCADE_ANIMATE]:
        input_locked = true
    else:
        input_locked = false
    if debug_mode:
        print("[State] Transition from ", previous_state, " to ", current_state, ", input_locked=", input_locked)
    # --- Lower raised line on any transition out of drag states ---
    if (previous_state == BoardState.SHIFTING_ROW or previous_state == BoardState.SHIFTING_COLUMN) and current_state != previous_state:
        if effects_enabled:
            if effects_state_machine:
                effects_state_machine.lower_line(board, drag_mode, drag_index)
            else:
                push_error("effects_state_machine is null in lower_line!")
    # --- End lower on any transition ---
    # --- Effect state machine integration ---
    if current_state == BoardState.SHIFTING_ROW:
        if effects_enabled:
            if effects_state_machine:
                effects_state_machine.raise_line(board, "row", drag_index)
            else:
                push_error("effects_state_machine is null in raise_line (row)!")
    elif current_state == BoardState.SHIFTING_COLUMN:
        if effects_enabled:
            if effects_state_machine:
                effects_state_machine.raise_line(board, "column", drag_index)
            else:
                push_error("effects_state_machine is null in raise_line (column)!")
    # --- End effect integration ---
    match current_state:
        BoardState.IDLE:
            drag_mode = ""
            drag_index = -1
            drag_last_shift = 0
            drag_start_pos = Vector2.ZERO
            combo_count = 0 # Reset combo on new player move
        BoardState.DRAGGING:
            pass
        BoardState.SHIFTING_ROW:
            pass
        BoardState.SHIFTING_COLUMN:
            pass
        BoardState.MATCH_FIND:
            await find_and_handle_matches()
        BoardState.MATCH_ANIMATE:
            await animate_and_remove_matches()
        BoardState.CASCADE_ANIMATE:
            await animate_and_refill_cascade()

func handle_input(event: InputEvent) -> void:
    if input_locked:
        return
    # Handle mouse/touch release in any state
    if (event is InputEventMouseButton or event is InputEventScreenTouch) and not event.pressed:
        if current_state == BoardState.SHIFTING_ROW or current_state == BoardState.SHIFTING_COLUMN:
            enter_state(BoardState.MATCH_FIND)
        else:
            enter_state(BoardState.IDLE)
        return

    match current_state:
        BoardState.IDLE:
            if event is InputEventMouseButton or event is InputEventScreenTouch:
                if event.pressed:
                    var local_pos = board.piece_container.get_local_mouse_position()
                    var grid_x = int(floor(local_pos.x / board.PIECE_SIZE))
                    var grid_y = int(floor(local_pos.y / board.PIECE_SIZE))
                    if grid_x >= 0 and grid_x < board.GRID_SIZE_X and grid_y >= 0 and grid_y < board.GRID_SIZE_Y:
                        drag_start_pos = event.position
                        enter_state(BoardState.DRAGGING)
        
        BoardState.DRAGGING:
            if event is InputEventMouseMotion or event is InputEventScreenDrag:
                handle_drag(event)
        
        BoardState.SHIFTING_ROW:
            if event is InputEventMouseMotion or event is InputEventScreenDrag:
                handle_drag(event)
        
        BoardState.SHIFTING_COLUMN:
            if event is InputEventMouseMotion or event is InputEventScreenDrag:
                handle_drag(event)

func handle_drag(event: InputEvent) -> void:
    var drag_delta = event.position - drag_start_pos

    if drag_mode == "":
        # Determine lock direction and index
        if abs(drag_delta.x) > abs(drag_delta.y) and abs(drag_delta.x) > board.PIECE_SIZE * 0.3:
            drag_mode = "row"
            var local_pos = board.piece_container.get_local_mouse_position()
            drag_index = int(floor(local_pos.y / board.PIECE_SIZE))
            drag_start_pos = event.position
            drag_last_shift = 0
            enter_state(BoardState.SHIFTING_ROW)
        elif abs(drag_delta.y) > abs(drag_delta.x) and abs(drag_delta.y) > board.PIECE_SIZE * 0.3:
            drag_mode = "column"
            var local_pos = board.piece_container.get_local_mouse_position()
            drag_index = int(floor(local_pos.x / board.PIECE_SIZE))
            drag_start_pos = event.position
            drag_last_shift = 0
            enter_state(BoardState.SHIFTING_COLUMN)
        else:
            return # Not enough movement to lock yet

    if current_state == BoardState.SHIFTING_ROW and drag_index >= 0:
        var cell_shift = int((event.position.x - drag_start_pos.x) / board.PIECE_SIZE)
        if abs(cell_shift) != 0 and cell_shift != drag_last_shift:
            board.operations.shift_row(drag_index, sign(cell_shift - drag_last_shift))
            drag_last_shift = cell_shift
            # Do NOT call MATCH_FIND here; wait for drag release
    elif current_state == BoardState.SHIFTING_COLUMN and drag_index >= 0:
        var cell_shift = int((event.position.y - drag_start_pos.y) / board.PIECE_SIZE)
        if abs(cell_shift) != 0 and cell_shift != drag_last_shift:
            board.operations.shift_column(drag_index, sign(cell_shift - drag_last_shift))
            drag_last_shift = cell_shift
            # Do NOT call MATCH_FIND here; wait for drag release

# Shift states are in board_operations.gd

# After a move, start the match-find cascade
func start_cascade():
    await enter_state(BoardState.MATCH_FIND)

# Find all matches and transition accordingly
func find_and_handle_matches():
    var matches = find_all_matches()
    if matches.size() > 0:
        combo_count += 1
        print("Matches found (combo #" + str(combo_count) + "): ", matches)
        pending_matches = matches
        await enter_state(BoardState.MATCH_ANIMATE)
    else:
        print("No matches found. Combo streak was: ", combo_count)
        await enter_state(BoardState.IDLE)

# Animate and remove matches, then refill and animate cascade
func animate_and_remove_matches():
    if effects_enabled:
        if effects_state_machine:
            await effects_state_machine.animate_match_removal(pending_matches, match_delay)
        else:
            push_error("effects_state_machine is null in animate_match_removal!")
            await get_tree().create_timer(match_delay).timeout
    else:
        await get_tree().create_timer(match_delay).timeout
    remove_matches(pending_matches) # Set matched cells to null, but don't move anything yet
    pending_matches = []
    await get_tree().create_timer(0.25).timeout # Pause before gravity
    await enter_state(BoardState.CASCADE_ANIMATE)

# Animate falling tiles and refill, then check for new matches
func animate_and_refill_cascade():
    # 1. Calculate all fall moves and new spawns, and update board state
    var fall_moves = [] # Each move: {piece, from: Vector2, to: Vector2, is_new: bool}
    var grid_x = board.GRID_SIZE_X
    var grid_y = board.GRID_SIZE_Y
    var piece_size = board.PIECE_SIZE
    for x in range(grid_x):
        var write_y = grid_y - 1
        for read_y in range(grid_y - 1, -1, -1):
            if board.grid[x][read_y] != null:
                if write_y != read_y:
                    var piece = board.piece_nodes[x][read_y]
                    fall_moves.append({"piece": piece, "from": Vector2(x, read_y), "to": Vector2(x, write_y), "is_new": false})
                    board.grid[x][write_y] = board.grid[x][read_y]
                    board.piece_nodes[x][write_y] = piece
                    board.grid[x][read_y] = null
                    board.piece_nodes[x][read_y] = null
                write_y -= 1
        for y in range(write_y, -1, -1):
            var allowed = board.ALLOWED_PIECE_TYPES
            var new_type = allowed[randi() % allowed.size()]
            board.grid[x][y] = new_type
            var piece_scene = board.piece_scenes.get(new_type, null)
            if piece_scene:
                var piece = piece_scene.instantiate()
                var from_y = y - 1 - (grid_y - write_y)
                var start_pos = Vector2(x, from_y) * piece_size
                var end_pos = Vector2(x, y) * piece_size
                piece.position = start_pos
                board.piece_container.add_child(piece)
                board.piece_nodes[x][y] = piece
                fall_moves.append({"piece": piece, "from": Vector2(x, from_y), "to": Vector2(x, y), "is_new": true})
            else:
                board.piece_nodes[x][y] = null
    # 2. Animate visuals (or instantly finish if effects are disabled)
    print("[Debug] About to animate cascade visuals")
    if effects_state_machine:
        effects_state_machine.animate_cascade_visuals(fall_moves, board)
    print("[Debug] Finished animating cascade visuals")
    # 3. Print board state for debugging
    print_board_state()
    var matches = find_all_matches()
    print("[Debug] Matches after cascade: ", matches)
    if matches.size() > 0:
        if matches == pending_matches:
            print("[Error] Infinite match loop detected! Breaking out.")
            await enter_state(BoardState.IDLE)
        else:
            pending_matches = matches
            await enter_state(BoardState.MATCH_ANIMATE)
    else:
        await enter_state(BoardState.IDLE)

func print_board_state():
    print("[Debug] Board state:")
    for y in range(board.GRID_SIZE_Y):
        var row = []
        for x in range(board.GRID_SIZE_X):
            row.append(board.grid[x][y])
        print(row)

# After a move/shift, start the cascade process
func check_for_matches():
    await start_cascade()

# Find all horizontal and vertical matches for self-matching types
func find_all_matches() -> Array:
    var matches = []
    var visited = {}
    # Horizontal
    for y in range(board.GRID_SIZE_Y):
        var run_type = null
        var run_start = 0
        var run_length = 0
        for x in range(board.GRID_SIZE_X):
            var piece_type = board.grid[x][y]
            var type_data = PieceTypes.PIECE_TYPES.get(piece_type, null)
            if type_data and type_data.get("matchable", false):
                if piece_type == run_type:
                    run_length += 1
                else:
                    if run_type != null and run_length >= board.MATCH_LENGTH:
                        for rx in range(run_start, run_start + run_length):
                            visited[[rx, y]] = true
                    run_type = piece_type
                    run_start = x
                    run_length = 1
            else:
                if run_type != null and run_length >= board.MATCH_LENGTH:
                    for rx in range(run_start, run_start + run_length):
                        visited[[rx, y]] = true
                run_type = null
                run_length = 0
        if run_type != null and run_length >= board.MATCH_LENGTH:
            for rx in range(run_start, run_start + run_length):
                visited[[rx, y]] = true
    # Vertical
    for x in range(board.GRID_SIZE_X):
        var run_type = null
        var run_start = 0
        var run_length = 0
        for y in range(board.GRID_SIZE_Y):
            var piece_type = board.grid[x][y]
            var type_data = PieceTypes.PIECE_TYPES.get(piece_type, null)
            if type_data and type_data.get("matchable", false):
                if piece_type == run_type:
                    run_length += 1
                else:
                    if run_type != null and run_length >= board.MATCH_LENGTH:
                        for ry in range(run_start, run_start + run_length):
                            visited[[x, ry]] = true
                    run_type = piece_type
                    run_start = y
                    run_length = 1
            else:
                if run_type != null and run_length >= board.MATCH_LENGTH:
                    for ry in range(run_start, run_start + run_length):
                        visited[[x, ry]] = true
                run_type = null
                run_length = 0
        if run_type != null and run_length >= board.MATCH_LENGTH:
            for ry in range(run_start, run_start + run_length):
                visited[[x, ry]] = true
    # Convert visited to array of positions
    for pos in visited.keys():
        matches.append(pos)
    return matches

# Remove matched pieces from the board and set to null
func remove_matches(matches: Array):
    for pos in matches:
        var x = pos[0]
        var y = pos[1]
        board.grid[x][y] = null
        if board.piece_nodes[x][y]:
            board.piece_nodes[x][y].queue_free()
            board.piece_nodes[x][y] = null

func handle_match_resolution():
    # Placeholder: implement match resolution logic here
    pass

func handle_no_match():
    # Placeholder: implement no match logic here
    pass

# Call this after the initial board population to clear any starting matches
func clear_initial_matches():
    while true:
        var matches = find_all_matches()
        if matches.size() == 0:
            break
        remove_matches(matches)
        # Refill and update visuals instantly (no animation)
        var fall_moves = []
        var grid_x = board.GRID_SIZE_X
        var grid_y = board.GRID_SIZE_Y
        var piece_size = board.PIECE_SIZE
        for x in range(grid_x):
            var write_y = grid_y - 1
            for read_y in range(grid_y - 1, -1, -1):
                if board.grid[x][read_y] != null:
                    if write_y != read_y:
                        var piece = board.piece_nodes[x][read_y]
                        fall_moves.append({"piece": piece, "from": Vector2(x, read_y), "to": Vector2(x, write_y), "is_new": false})
                        board.grid[x][write_y] = board.grid[x][read_y]
                        board.piece_nodes[x][write_y] = piece
                        board.grid[x][read_y] = null
                        board.piece_nodes[x][read_y] = null
                    write_y -= 1
            for y in range(write_y, -1, -1):
                var allowed = board.ALLOWED_PIECE_TYPES
                var new_type = allowed[randi() % allowed.size()]
                board.grid[x][y] = new_type
                var piece_scene = board.piece_scenes.get(new_type, null)
                if piece_scene:
                    var piece = piece_scene.instantiate()
                    var from_y = y - 1 - (grid_y - write_y)
                    var start_pos = Vector2(x, from_y) * piece_size
                    var end_pos = Vector2(x, y) * piece_size
                    piece.position = end_pos # Instantly set to final position
                    board.piece_container.add_child(piece)
                    board.piece_nodes[x][y] = piece
                else:
                    board.piece_nodes[x][y] = null
        # Instantly update visuals
        for move in fall_moves:
            if move["piece"]:
                move["piece"].position = move["to"] * board.PIECE_SIZE 

func set_debug_mode(enabled: bool):
    debug_mode = enabled

func toggle_debug_mode():
    debug_mode = !debug_mode 
