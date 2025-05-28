extends Node

enum BoardState {
    IDLE,
    DRAGGING,
    SHIFTING_ROW,
    SHIFTING_COLUMN
}

var current_state: BoardState = BoardState.IDLE
var board: Node

# Drag state variables
var drag_start_pos := Vector2.ZERO
var drag_mode := ""      # "row" or "column"
var drag_index := -1     # Locked row or column index
var drag_last_shift := 0 # Prevents multiple shifts per cell

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

func handle_input(event: InputEvent) -> void:
    # Handle mouse/touch release in any state
    if (event is InputEventMouseButton or event is InputEventScreenTouch) and not event.pressed:
        enter_state(BoardState.IDLE)
        return

    match current_state:
        BoardState.IDLE:
            if event is InputEventMouseButton or event is InputEventScreenTouch:
                if event.pressed:
                    var local_pos = board.gem_container.get_local_mouse_position()
                    var grid_x = int(floor(local_pos.x / board.GEM_SIZE))
                    var grid_y = int(floor(local_pos.y / board.GEM_SIZE))
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
        if abs(drag_delta.x) > abs(drag_delta.y) and abs(drag_delta.x) > board.GEM_SIZE * 0.3:
            drag_mode = "row"
            var local_pos = board.gem_container.get_local_mouse_position()
            drag_index = int(floor(local_pos.y / board.GEM_SIZE))
            drag_start_pos = event.position
            drag_last_shift = 0
            enter_state(BoardState.SHIFTING_ROW)
        elif abs(drag_delta.y) > abs(drag_delta.x) and abs(drag_delta.y) > board.GEM_SIZE * 0.3:
            drag_mode = "column"
            var local_pos = board.gem_container.get_local_mouse_position()
            drag_index = int(floor(local_pos.x / board.GEM_SIZE))
            drag_start_pos = event.position
            drag_last_shift = 0
            enter_state(BoardState.SHIFTING_COLUMN)
        else:
            return # Not enough movement to lock yet

    if current_state == BoardState.SHIFTING_ROW and drag_index >= 0:
        var cell_shift = int((event.position.x - drag_start_pos.x) / board.GEM_SIZE)
        if abs(cell_shift) != 0 and cell_shift != drag_last_shift:
            board.operations.shift_row(drag_index, sign(cell_shift - drag_last_shift))
            drag_last_shift = cell_shift
    elif current_state == BoardState.SHIFTING_COLUMN and drag_index >= 0:
        var cell_shift = int((event.position.y - drag_start_pos.y) / board.GEM_SIZE)
        if abs(cell_shift) != 0 and cell_shift != drag_last_shift:
            board.operations.shift_column(drag_index, sign(cell_shift - drag_last_shift))
            drag_last_shift = cell_shift 
