extends Node

# --- Member Variables ---
var board: Node

# --- Built-in Functions ---
func _init(board_node: Node):
    board = board_node

# --- Board Operation Methods ---
func shift_row(y: int, direction: int):
    if not board:
        push_error("Board is null in shift_row!")
        return
    if y < 0 or y >= board.GRID_SIZE_Y:
        push_error("Invalid row index %d" % y)
        return
    var new_row = []
    var new_nodes = []
    if direction > 0:  # Right
        new_row.append(board.grid[board.GRID_SIZE_X-1][y])
        for x in range(0, board.GRID_SIZE_X-1):
            new_row.append(board.grid[x][y])
        new_nodes.append(board.piece_nodes[board.GRID_SIZE_X-1][y])
        for x in range(0, board.GRID_SIZE_X-1):
            new_nodes.append(board.piece_nodes[x][y])
    else:  # Left
        for x in range(1, board.GRID_SIZE_X):
            new_row.append(board.grid[x][y])
        new_row.append(board.grid[0][y])
        for x in range(1, board.GRID_SIZE_X):
            new_nodes.append(board.piece_nodes[x][y])
        new_nodes.append(board.piece_nodes[0][y])
    for x in range(board.GRID_SIZE_X):
        board.grid[x][y] = new_row[x]
        board.piece_nodes[x][y] = new_nodes[x]
    board.update_visual_positions()

func shift_column(x: int, direction: int):
    if not board:
        push_error("Board is null in shift_column!")
        return
    if x < 0 or x >= board.GRID_SIZE_X:
        push_error("Invalid column index %d" % x)
        return
    var new_col = []
    var new_nodes = []
    if direction > 0:  # Down
        new_col.append(board.grid[x][board.GRID_SIZE_Y-1])
        new_nodes.append(board.piece_nodes[x][board.GRID_SIZE_Y-1])
        for y in range(0, board.GRID_SIZE_Y-1):
            new_col.append(board.grid[x][y])
            new_nodes.append(board.piece_nodes[x][y])
    else:  # Up
        for y in range(1, board.GRID_SIZE_Y):
            new_col.append(board.grid[x][y])
            new_nodes.append(board.piece_nodes[x][y])
        new_col.append(board.grid[x][0])
        new_nodes.append(board.piece_nodes[x][0])
    for y in range(board.GRID_SIZE_Y):
        board.grid[x][y] = new_col[y]
        board.piece_nodes[x][y] = new_nodes[y]
    board.update_visual_positions() 
