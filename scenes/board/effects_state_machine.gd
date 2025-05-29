extends Node

# TWEAK SETTINGS (Juicy Animation & Timing)
# --- Raise/Pop Effect ---
var raise_offset := -20         # How high to raise the line (pixels, optional)
var raise_duration := 0.15      # How long the raise animation takes (seconds)
var raise_ease := Tween.TRANS_QUINT
var raise_ease_type := Tween.EASE_OUT
var raise_scale := 1.15         # How much to scale up when raising
var raise_z_index := 10         # z_index when raised
var normal_z_index := 0         # default z_index

# --- Fall/Refill Effect ---
# fall_speed_per_cell: Base seconds per cell fallen (lower = faster overall fall)
var fall_speed_per_cell := 0.01
# fall_exponent: Controls how much momentum longer falls have (0.5 = sqrt, 1.0 = linear, <1 = more snap)
var fall_exponent := 0.6
# min_fall_time: Minimum time for any fall, even for a single cell (prevents instant jumps)
var min_fall_time := 0.005
# fall_ease: Easing function for the fall (EXPO = fast, snappy)
var fall_ease := Tween.TRANS_EXPO

var effects_enabled := true # Toggle to enable/disable all effects

# --- Signals for future use (connect in the editor or code) ---
signal _line_raised(pieces)
signal _line_lowered(pieces)
signal _piece_fell(piece)

# State for tracking currently raised line
var _raised_pieces := []
var _raised_positions := []
var _raised_mode := ""
var _raised_index := -1

# Helper: Animate raising a line of pieces (row or column) with pop effect
func raise_line(board, mode: String, index: int):
    if not effects_enabled:
        return
    _raised_pieces.clear()
    _raised_positions.clear()
    _raised_mode = mode
    _raised_index = index
    if mode == "row":
        for x in range(board.GRID_SIZE_X):
            var piece = board.piece_nodes[x][index]
            _raised_pieces.append(piece)
            _raised_positions.append(piece.position)
    elif mode == "column":
        for y in range(board.GRID_SIZE_Y):
            var piece = board.piece_nodes[index][y]
            _raised_pieces.append(piece)
            _raised_positions.append(piece.position)
    for piece in _raised_pieces:
        var tween = piece.create_tween()
        tween.tween_property(piece, "scale", Vector2(raise_scale, raise_scale), raise_duration).set_trans(raise_ease).set_ease(raise_ease_type)
        # Optionally: tween.tween_property(piece, "position", piece.position + Vector2(0, raise_offset), raise_duration)
        piece.z_index = raise_z_index
    emit_signal("_line_raised", _raised_pieces)

# Helper: Animate lowering a line of pieces back to original position and scale
func lower_line(board, mode: String, index: int):
    if not effects_enabled:
        return
    # Only lower if the mode and index match the currently raised line
    if _raised_mode != mode or _raised_index != index:
        return
    for i in range(_raised_pieces.size()):
        var piece = _raised_pieces[i]
        var tween = piece.create_tween()
        tween.tween_property(piece, "scale", Vector2(1, 1), raise_duration).set_trans(raise_ease).set_ease(raise_ease_type)
        # Optionally: tween.tween_property(piece, "position", _raised_positions[i], raise_duration)
        piece.z_index = normal_z_index
    emit_signal("_line_lowered", _raised_pieces)
    _raised_pieces.clear()
    _raised_positions.clear()
    _raised_mode = ""
    _raised_index = -1

# Helper: Animate match removal (with delay, can be expanded for effects)
func animate_match_removal(matches: Array, match_delay: float) -> void:
    if not effects_enabled:
        await get_tree().create_timer(match_delay).timeout
        return
    # TODO: Add visual effects for match removal (e.g., fade, scale, particles)
    await get_tree().create_timer(match_delay).timeout

# Helper: Animate cascade (falling pieces and refill, with all juicy effects)
func animate_cascade(board) -> void:
    if not effects_enabled:
        await board.queue_cascade_with_delay()
        return
    var fall_anims = []
    var grid_x = board.GRID_SIZE_X
    var grid_y = board.GRID_SIZE_Y
    var piece_size = board.PIECE_SIZE
    for x in range(grid_x):
        var write_y = grid_y - 1
        for read_y in range(grid_y - 1, -1, -1):
            if board.grid[x][read_y] != null:
                if write_y != read_y:
                    var piece = board.piece_nodes[x][read_y]
                    var start_pos = piece.position
                    var end_pos = Vector2(x, write_y) * piece_size
                    var fall_distance = abs(write_y - read_y)
                    var fall_time = min_fall_time + fall_speed_per_cell * pow(fall_distance, fall_exponent)
                    fall_anims.append(await _fall_piece(piece, start_pos, end_pos, fall_time))
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
                var start_pos = Vector2(x, y - 1 - (grid_y - write_y)) * piece_size
                var end_pos = Vector2(x, y) * piece_size
                var fall_distance = abs((y - 1 - (grid_y - write_y)) - y)
                var fall_time = min_fall_time + fall_speed_per_cell * pow((grid_y - y), fall_exponent)
                piece.position = start_pos
                board.piece_container.add_child(piece)
                board.piece_nodes[x][y] = piece
                fall_anims.append(await _fall_piece(piece, start_pos, end_pos, fall_time))
            else:
                board.piece_nodes[x][y] = null
    for anim in fall_anims:
        pass # already awaited above

# Helper: Animate a single piece falling, awaits the tween internally
func _fall_piece(piece, start_pos, end_pos, fall_time):
    if piece == null:
        push_error("_fall_piece called with null piece!")
        return
    var tween = piece.create_tween()
    if tween == null:
        push_error("Failed to create tween for piece!")
        return
    tween.tween_property(piece, "position", end_pos, fall_time).from(start_pos).set_trans(fall_ease).set_ease(Tween.EASE_OUT)
    emit_signal("_piece_fell", piece)
    await tween.finished 
