extends Control

const BOARD_WIDTH := 10
const BOARD_HEIGHT := 20
const SIDE_UI_WIDTH := 4  # 左右に各4マス分のUIスペース
const VIRTUAL_BUTTON_HEIGHT := 160

var BLOCK_SIZE := 24
var board_margin := Vector2i(0, 0)
var FONT: Font

# スコア
var score := 0
var next_shape_data = null
var is_game_over := false
var piece_bag: Array = []

# スコアに応じて落下速度を上げる調整用
var base_fall_interval := 0.5  # 初期速度（秒）
var fall_interval_rate := 0.0001  # スコア加算ごとの減衰係数

# 仮想ボタンの定義（レイアウト調整後）
var virtual_buttons = {
	"←": Rect2i(),
	"→": Rect2i(),
	"↓": Rect2i(),
	"↑": Rect2i(),
	"⟳": Rect2i()
}

const SHAPES = [
	{ "blocks": [[Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]], "color": Color(1, 1, 0) },        # O
	{ "blocks": [[Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)],
				 [Vector2i(0,-1), Vector2i(0,0), Vector2i(0,1), Vector2i(0,2)]], "color": Color(0, 1, 1) },      # I
	{ "blocks": [[Vector2i(0,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(1,1)]], "color": Color(0, 1, 0) },      # S
	{ "blocks": [[Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,1)]], "color": Color(1, 0, 0) },      # Z
	{ "blocks": [[Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(0,1)]], "color": Color(0.6, 0, 1) },    # T
	{ "blocks": [[Vector2i(0, -1),Vector2i(0, 0),Vector2i(0, 1),Vector2i(1, 1)]], "color": Color(1, 0.5, 0) },     # L 修正
	{ "blocks": [[Vector2i(0, -1),Vector2i(0, 0),Vector2i(0, 1),Vector2i(-1, 1)]], "color": Color(0, 0, 1) }      # J 修正
]

var board = []
var current_shape = []
var current_color = Color.WHITE
var current_pos = Vector2i()
var fall_timer := 0.0
var fall_interval := 0.5

func _ready():
	board.resize(BOARD_HEIGHT)
	for y in range(BOARD_HEIGHT):
		board[y] = []
		board[y].resize(BOARD_WIDTH)
		for x in range(BOARD_WIDTH):
			board[y][x] = null
	FONT = get_theme_default_font()
	spawn_piece()
	set_process(true)

func _process(delta):
	update_board_layout()
	fall_timer += delta
	if fall_timer >= fall_interval:
		fall_timer = 0
		if !move(Vector2i(0, 1)):
			lock_piece()
			clear_lines()
			spawn_piece()
	fall_interval = max(0.1, base_fall_interval - score * fall_interval_rate)
	queue_redraw()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if is_game_over:
			reset_game()
			return
		match event.keycode:
			KEY_LEFT: move(Vector2i(-1, 0))
			KEY_RIGHT: move(Vector2i(1, 0))
			KEY_DOWN: move(Vector2i(0, 1))
			KEY_UP: hard_drop()
			KEY_SPACE: rotate()
		queue_redraw()

func _input(event):
	if event is InputEventScreenTouch and event.pressed:
		if is_game_over:
			reset_game()
			return
		for label in virtual_buttons.keys():
			if virtual_buttons[label].has_point(event.position):
				match label:
					"←": move(Vector2i(-1, 0))
					"→": move(Vector2i(1, 0))
					"↓": move(Vector2i(0, 1))
					"↑": hard_drop()
					"⟳": rotate()
				break
		queue_redraw()

func _draw():
	draw_background()
	draw_board()
	draw_piece(current_shape, current_color, current_pos)
	draw_ghost()
	draw_next()
	draw_score()

	if is_game_over:
		var text := "GAME OVER"
		var hint := "PRESS ANY KEY TO RESTART"
		var text_size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 48)
		var hint_size := FONT.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
		var center := Vector2(size.x / 2, size.y / 2)
		# アウトライン付き描画
		for offset in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_string(FONT, center - text_size / 2 + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.BLACK)
		draw_string(FONT, center - text_size / 2, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.RED)
		for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(FONT, center - hint_size / 2 + Vector2(0, 64) + offset, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.BLACK)
		draw_string(FONT, center - hint_size / 2 + Vector2(0, 64), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

	# ボタン描画（画像に準拠したレイアウト）
	var area_top = size.y - VIRTUAL_BUTTON_HEIGHT
	var btn_w = size.x / 6
	var btn_h = VIRTUAL_BUTTON_HEIGHT / 3
	var center_x = btn_w * 1.5
	var center_y = area_top + btn_h

	virtual_buttons["↑"] = Rect2i(Vector2i(center_x, center_y - btn_h), Vector2i(btn_w, btn_h))
	virtual_buttons["←"] = Rect2i(Vector2i(center_x - btn_w, center_y), Vector2i(btn_w, btn_h))
	virtual_buttons["→"] = Rect2i(Vector2i(center_x + btn_w, center_y), Vector2i(btn_w, btn_h))
	virtual_buttons["↓"] = Rect2i(Vector2i(center_x, center_y + btn_h), Vector2i(btn_w, btn_h))
	virtual_buttons["⟳"] = Rect2i(Vector2i(size.x - btn_w * 1.5, center_y), Vector2i(btn_w, btn_h))

	for label in virtual_buttons.keys():
		var rect = virtual_buttons[label]
		draw_rect(rect, Color(0.2, 0.2, 0.3, 0.8))
		draw_string(FONT, rect.position + Vector2i(10, 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

func update_board_layout():
	var total_width_in_blocks = BOARD_WIDTH + SIDE_UI_WIDTH * 2
	var max_block_size_x = size.x / total_width_in_blocks
	var max_block_size_y = (size.y - VIRTUAL_BUTTON_HEIGHT) / BOARD_HEIGHT
	BLOCK_SIZE = floor(min(max_block_size_x, max_block_size_y))

	var used_width = BLOCK_SIZE * total_width_in_blocks
	var used_height = BLOCK_SIZE * BOARD_HEIGHT
	board_margin = Vector2i(
		(size.x - used_width) / 2 + SIDE_UI_WIDTH * BLOCK_SIZE,
		(size.y - VIRTUAL_BUTTON_HEIGHT - used_height) / 2
	)

func draw_background():
	var gradient_top := Color(0.1, 0.1, 0.15)
	var gradient_bottom := Color(0.05, 0.05, 0.1)
	for y in range(size.y):
		var t := float(y) / size.y
		var color := gradient_top.lerp(gradient_bottom, t)
		draw_rect(Rect2(0, y, size.x, 1), color)

	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH + SIDE_UI_WIDTH * 2):
			var pos = Vector2i(x, y)
			var cell_pos = Vector2i(
				board_margin.x + (x - SIDE_UI_WIDTH) * BLOCK_SIZE,
				board_margin.y + y * BLOCK_SIZE
			)

			var cell_color: Color
			if x >= SIDE_UI_WIDTH and x < SIDE_UI_WIDTH + BOARD_WIDTH:
				cell_color = Color(1, 1, 1, 0.05)  # プレイエリア
			else:
				cell_color = Color(0.2, 0.2, 0.3, 0.08)  # UIエリア
			draw_rect(Rect2(cell_pos, Vector2(BLOCK_SIZE, BLOCK_SIZE)), cell_color)


func draw_board():
	for y in range(BOARD_HEIGHT):
		for x in range(BOARD_WIDTH):
			if board[y][x] != null:
				draw_block(Vector2i(x, y), board[y][x])

func draw_block(pos: Vector2i, color: Color):
	var top_left = board_margin + pos * BLOCK_SIZE
	var size_vec = Vector2(BLOCK_SIZE, BLOCK_SIZE)
	var rect = Rect2(top_left, size_vec)

	# 本体カラー（フラット）
	draw_rect(rect, color)

	# 外枠（わずかに暗い色でフレーム感）
	var border_color = color.lerp(Color.BLACK, 0.3)
	var thickness = 1.0

	var p1 = rect.position
	var p2 = rect.position + Vector2(rect.size.x, 0)
	var p3 = rect.position + rect.size
	var p4 = rect.position + Vector2(0, rect.size.y)

	draw_line(p1, p2, border_color, thickness)
	draw_line(p2, p3, border_color, thickness)
	draw_line(p3, p4, border_color, thickness)
	draw_line(p4, p1, border_color, thickness)

func draw_piece(shape, color, pos):
	for b in shape:
		draw_block(pos + b, color)

func draw_ghost():
	var ghost_pos = current_pos
	while can_move(ghost_pos + Vector2i(0, 1), current_shape):
		ghost_pos += Vector2i(0, 1)
	for b in current_shape:
		var p = ghost_pos + b
		var top_left = board_margin + p * BLOCK_SIZE
		var rect = Rect2i(top_left, Vector2i(BLOCK_SIZE - 1, BLOCK_SIZE - 1))
		draw_rect(rect, Color(current_color.r,current_color.g,current_color.b,0.3))

func draw_score():
	var offset = Vector2i(size.x - 120, 100)  # NEXTの下に表示（Y=100）
	draw_string(FONT, offset, "SCORE: %d" % score, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)

func spawn_piece():
	if next_shape_data == null:
		next_shape_data = get_next_piece()

	var shape_data = next_shape_data
	next_shape_data = get_next_piece()

	current_shape = shape_data.blocks[0]
	current_color = shape_data.color
	current_pos = Vector2i(BOARD_WIDTH / 2.0, 0)

	if !can_move(current_pos, current_shape):
		is_game_over = true
		set_process(false)

func move(offset: Vector2i) -> bool:
	var new_pos = current_pos + offset
	if can_move(new_pos, current_shape):
		current_pos = new_pos
		return true
	return false

func rotate():
	var rotated = []
	for b in current_shape:
		rotated.append(Vector2i(-b.y, b.x))
	if can_move(current_pos, rotated):
		current_shape = rotated

func can_move(pos: Vector2i, shape) -> bool:
	for b in shape:
		var p = pos + b
		if p.x < 0 or p.x >= BOARD_WIDTH or p.y >= BOARD_HEIGHT:
			return false
		if p.y >= 0 and board[p.y][p.x] != null:
			return false
	return true

func lock_piece():
	for b in current_shape:
		var p = current_pos + b
		if p.y >= 0:
			board[p.y][p.x] = current_color

func clear_lines():
	var cleared = 0
	for y in range(BOARD_HEIGHT - 1, -1, -1):
		if board[y].all(func(v): return v != null):
			for yy in range(y, 0, -1):
				board[yy] = board[yy - 1]
			board[0] = []
			board[0].resize(BOARD_WIDTH)
			for x in range(BOARD_WIDTH):
				board[0][x] = null
			y += 1
			cleared += 1
	score += cleared * 100
	
	# 落下速度をスコアに応じて速くする
	fall_interval = max(0.1, base_fall_interval - score * fall_interval_rate)

func hard_drop():
	while move(Vector2i(0, 1)):
		pass
	lock_piece()
	clear_lines()
	spawn_piece()

func draw_next():
	if next_shape_data != null:
		var offset = Vector2i(size.x - 120, 20)  # 右上付近
		draw_string(FONT, offset, "NEXT", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)
		for b in next_shape_data.blocks[0]:
			var pos = offset + Vector2i(0, 20) + Vector2i(b.x, b.y) * int(BLOCK_SIZE * 0.5)
			draw_rect(Rect2(pos, Vector2(BLOCK_SIZE * 0.5 - 1, BLOCK_SIZE * 0.5 - 1)), next_shape_data.color)

func reset_game():
	is_game_over = false
	set_process(true)
	score = 0
	next_shape_data = null

	# ボード初期化
	board.clear()
	board.resize(BOARD_HEIGHT)
	for y in range(BOARD_HEIGHT):
		board[y] = []
		board[y].resize(BOARD_WIDTH)
		for x in range(BOARD_WIDTH):
			board[y][x] = null
			
	fall_interval = base_fall_interval

	spawn_piece()

func get_next_piece() -> Dictionary:
	if piece_bag.is_empty():
		piece_bag = SHAPES.duplicate()
		piece_bag.shuffle()
	return piece_bag.pop_back()
