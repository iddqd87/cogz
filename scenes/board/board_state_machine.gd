extends Node

enum BoardState {
    IDLE,
    DRAGGING,
    SHIFTING_ROW,
    SHIFTING_COLUMN,
    MATCH_CHECK
}

var current_state: BoardState = BoardState.IDLE
var board: Node
var match_length := 3 # Default match length, can be set from board.gd

# Drag state variables
var drag_start_pos := Vector2.ZERO
var drag_mode := ""      # "row" or "column"
var drag_index := -1     # Locked row or column index
var drag_last_shift := 0 # Prevents multiple shifts per cell

const PieceTypes = preload("res://scenes/board/piece_types.gd")

func _init(board_node: Node):
    board = board_node

func enter_state(new_state: BoardState):
    current_state = new_state
    match current_state:
        BoardState.IDLE:
            drag_mode = ""
            drag_index = -1
            drag_last_shift = 0
            drag_start_pos = Vector2.ZERO
        BoardState.DRAGGING:
            pass
        BoardState.SHIFTING_ROW:
            pass
        BoardState.SHIFTING_COLUMN:
            pass
        BoardState.MATCH_CHECK:
            check_for_matches()

func handle_input(event: InputEvent) -> void:
    # Handle mouse/touch release in any state
    if (event is InputEventMouseButton or event is InputEventScreenTouch) and not event.pressed:
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
            # After a shift, check for matches
            enter_state(BoardState.MATCH_CHECK)
    elif current_state == BoardState.SHIFTING_COLUMN and drag_index >= 0:
        var cell_shift = int((event.position.y - drag_start_pos.y) / board.PIECE_SIZE)
        if abs(cell_shift) != 0 and cell_shift != drag_last_shift:
            board.operations.shift_column(drag_index, sign(cell_shift - drag_last_shift))
            drag_last_shift = cell_shift
            # After a shift, check for matches
            enter_state(BoardState.MATCH_CHECK)

func set_match_length(length: int):
    match_length = length

# Call this after a move/shift to check for matches
func check_for_matches():
    # Find all matches and queue cascades
    var matches = find_all_matches()
    if matches.size() > 0:
        print("Matches found: ", matches)
        remove_matches(matches)
        queue_cascade()
    else:
        print("No matches found.")
        enter_state(BoardState.IDLE)

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
            if PieceTypes.MATCHABLE_TYPES.get(piece_type, false):
                if piece_type == run_type:
                    run_length += 1
                else:
                    if run_type != null and run_length >= match_length:
                        for rx in range(run_start, run_start + run_length):
                            visited[[rx, y]] = true
                    run_type = piece_type
                    run_start = x
                    run_length = 1
            else:
                if run_type != null and run_length >= match_length:
                    for rx in range(run_start, run_start + run_length):
                        visited[[rx, y]] = true
                run_type = null
                run_length = 0
        if run_type != null and run_length >= match_length:
            for rx in range(run_start, run_start + run_length):
                visited[[rx, y]] = true
    # Vertical
    for x in range(board.GRID_SIZE_X):
        var run_type = null
        var run_start = 0
        var run_length = 0
        for y in range(board.GRID_SIZE_Y):
            var piece_type = board.grid[x][y]
            if PieceTypes.MATCHABLE_TYPES.get(piece_type, false):
                if piece_type == run_type:
                    run_length += 1
                else:
                    if run_type != null and run_length >= match_length:
                        for ry in range(run_start, run_start + run_length):
                            visited[[x, ry]] = true
                    run_type = piece_type
                    run_start = y
                    run_length = 1
            else:
                if run_type != null and run_length >= match_length:
                    for ry in range(run_start, run_start + run_length):
                        visited[[x, ry]] = true
                run_type = null
                run_length = 0
        if run_type != null and run_length >= match_length:
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

# Cascade pieces down and fill empty spaces, then check for new matches
func queue_cascade():
    # For each column, move pieces down to fill nulls
    for x in range(board.GRID_SIZE_X):
        var new_col = []
        for y in range(board.GRID_SIZE_Y-1, -1, -1):
            if board.grid[x][y] != null:
                new_col.append(board.grid[x][y])
        # Fill up with new random pieces at the top
        while new_col.size() < board.GRID_SIZE_Y:
            var allowed = board.ALLOWED_PIECE_TYPES
            new_col.append(allowed[randi() % allowed.size()])
        # Write back to grid (bottom to top)
        for y in range(board.GRID_SIZE_Y-1, -1, -1):
            board.grid[x][y] = new_col[board.GRID_SIZE_Y-1-y]
    # Respawn visuals
    board.spawn_visual_pieces()
    # Check for new matches after cascade
    call_deferred("check_for_matches")

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
        queue_cascade() 
