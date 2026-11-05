extends Node3D
## Penaltı Ustası 3D
## Ekranda parmağını yukarı doğru kaydır: yön = sağ/sol, uzunluk = yükseklik, hız = şut gücü.
## 5 şutta kaleciyi geçip en çok golü atmaya çalış. Her golde kaleci biraz daha iyi tahmin eder.

const GOAL_Z := -11.0
const GOAL_HALF_W := 3.66
const GOAL_H := 2.44
const BALL_R := 0.11
const MAX_SHOTS := 5
const GRAVITY := 9.8
const KEEPER_Z := GOAL_Z + 0.4

var ball: MeshInstance3D
var keeper: Node3D
var cam: Camera3D
var score_label: Label
var msg_label: Label

var state := "ready"  # ready, flying, over
var ball_vel := Vector3.ZERO
var dragging := false
var drag_start := Vector2.ZERO
var drag_time := 0.0
var decided := false
var passed_keeper := false
var result_timer := 0.0

var keeper_target_x := 0.0
var keeper_target_tilt := 0.0
var keeper_delay := 0.0
var idle_t := 0.0

var goals := 0
var shots := 0
var best := 0


func _ready() -> void:
	_load_best()
	_build_world()
	_build_ui()
	_reset_shot()
	_update_ui()
	_show_msg("Parmağını yukarı kaydır, şut çek!", 2.5)


# ---------------- Oyun döngüsü ----------------

func _process(delta: float) -> void:
	if dragging:
		drag_time += delta

	if msg_label.visible and state != "over":
		msg_label.modulate.a = move_toward(msg_label.modulate.a, 0.0, delta * 0.5)
		if msg_label.modulate.a <= 0.0:
			msg_label.visible = false

	if state == "ready":
		idle_t += delta
		keeper.position.x = sin(idle_t * 1.6) * 0.5
		return

	if state != "flying":
		return

	_move_keeper(delta)
	_move_ball(delta)

	if decided:
		result_timer -= delta
		if result_timer <= 0.0:
			_next_shot()


func _move_ball(delta: float) -> void:
	var prev := ball.position
	ball_vel.y -= GRAVITY * delta
	ball.position += ball_vel * delta
	ball.rotate_x(-ball_vel.z * delta / BALL_R * 0.5)
	ball.rotate_z(-ball_vel.x * delta / BALL_R * 0.5)

	# Zeminden sekme
	if ball.position.y < BALL_R:
		ball.position.y = BALL_R
		ball_vel.y = absf(ball_vel.y) * 0.45
		ball_vel.x *= 0.85
		ball_vel.z *= 0.85

	if decided:
		# Ağın içinde dur
		if absf(ball.position.x) < GOAL_HALF_W and ball.position.z < GOAL_Z - 1.4:
			ball.position.z = GOAL_Z - 1.4
			ball_vel = Vector3(ball_vel.x * 0.2, ball_vel.y, 0.5)
		return

	# Kaleci kontrolü
	if not passed_keeper and prev.z > KEEPER_Z and ball.position.z <= KEEPER_Z:
		passed_keeper = true
		if _keeper_touches(Vector2(ball.position.x, ball.position.y)):
			ball_vel = Vector3(ball_vel.x * 0.3 + randf_range(-2, 2), 2.5, 5.0)
			_finish(false, "Kaleci kurtardı!")
			return

	# Kale çizgisi kontrolü
	if prev.z > GOAL_Z and ball.position.z <= GOAL_Z:
		var x := absf(ball.position.x)
		var y := ball.position.y
		if x < GOAL_HALF_W - BALL_R and y < GOAL_H - BALL_R:
			ball_vel *= 0.35
			_finish(true, "GOOOL!")
		elif x < GOAL_HALF_W + 0.2 and y < GOAL_H + 0.2:
			ball_vel = Vector3(-ball_vel.x * 0.4, ball_vel.y * 0.5, 6.0)
			_finish(false, "Direk!")
		else:
			_finish(false, "Dışarı!")
		return

	# Çok uzağa gitti
	if absf(ball.position.x) > 15 or ball.position.y > 12 or ball.position.z > 6:
		_finish(false, "Dışarı!")


func _move_keeper(delta: float) -> void:
	if keeper_delay > 0.0:
		keeper_delay -= delta
		return
	keeper.position.x = move_toward(keeper.position.x, keeper_target_x, 6.5 * delta)
	keeper.rotation.z = move_toward(keeper.rotation.z, keeper_target_tilt, 5.0 * delta)


func _keeper_touches(p: Vector2) -> bool:
	# Gövde: ayaklardan başa bir çizgi; kollar: omuz hizasında yatay çizgi
	var feet := keeper.global_position
	var head := keeper.to_global(Vector3(0, 1.85, 0))
	var arm_l := keeper.to_global(Vector3(-0.8, 1.4, 0))
	var arm_r := keeper.to_global(Vector3(0.8, 1.4, 0))
	var d_body := _seg_dist(p, Vector2(feet.x, feet.y), Vector2(head.x, head.y))
	var d_arms := _seg_dist(p, Vector2(arm_l.x, arm_l.y), Vector2(arm_r.x, arm_r.y))
	return d_body < 0.42 or d_arms < 0.22


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ---------------- Girdi ----------------

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		if state == "over":
			_restart()
		elif state == "ready":
			dragging = true
			drag_start = mb.position
			drag_time = 0.0
	elif dragging:
		dragging = false
		_shoot(mb.position - drag_start)


func _shoot(swipe: Vector2) -> void:
	var vs := get_viewport().get_visible_rect().size
	var up := -swipe.y / vs.y
	if up < 0.06:
		_show_msg("Yukarı doğru kaydır!", 1.2)
		return
	var side := swipe.x / vs.x
	var speed := swipe.length() / vs.y / maxf(drag_time, 0.05)
	var power := clampf(speed / 2.5, 0.65, 1.35)

	var vz := -19.0 * power
	var t := absf(GOAL_Z / vz)
	var aim_x := clampf(side * 13.0, -7.0, 7.0) + randf_range(-0.25, 0.25)
	var aim_y := clampf((up - 0.06) * 5.0, 0.0, 4.0) + randf_range(-0.15, 0.15)
	ball_vel = Vector3(aim_x / t, (aim_y + 0.5 * GRAVITY * t * t) / t, vz)

	_keeper_decide(aim_x, t)
	state = "flying"
	decided = false
	passed_keeper = false


func _keeper_decide(aim_x: float, t: float) -> void:
	var skill := minf(0.4 + goals * 0.08 + shots * 0.03, 0.8)
	var guess: float
	if randf() < skill:
		guess = aim_x + randf_range(-0.6, 0.6)
	else:
		guess = randf_range(-3.0, 3.0)
	guess = clampf(guess, -3.4, 3.4)

	var dx := guess - keeper.position.x
	var tilt := clampf(absf(dx) / 2.4, 0.0, 1.0) * 1.3
	keeper_target_tilt = -signf(dx) * tilt
	# Yatınca eller hedefe ulaşsın diye gövde biraz daha az kayar
	keeper_target_x = guess - signf(dx) * sin(tilt) * 1.1
	keeper_delay = clampf(0.15 - (skill - 0.4) * 0.2, 0.05, 0.15)


# ---------------- Akış ----------------

func _finish(goal: bool, text: String) -> void:
	decided = true
	shots += 1
	if goal:
		goals += 1
	result_timer = 1.6
	_show_msg(text, 1.6, Color(1, 0.9, 0.2) if goal else Color(1, 1, 1))
	_update_ui()


func _next_shot() -> void:
	if shots >= MAX_SHOTS:
		state = "over"
		if goals > best:
			best = goals
			_save_best()
		_update_ui()
		_show_msg("Bitti! %d / %d gol\nTekrar oynamak için dokun" % [goals, MAX_SHOTS], 999.0)
		_reset_shot()
		state = "over"
		return
	_reset_shot()


func _restart() -> void:
	goals = 0
	shots = 0
	_reset_shot()
	_update_ui()
	_show_msg("Yeni seri! Şut çek.", 1.5)


func _reset_shot() -> void:
	state = "ready"
	decided = false
	ball_vel = Vector3.ZERO
	ball.position = Vector3(0, BALL_R, 0)
	keeper.position = Vector3(0, 0, KEEPER_Z)
	keeper.rotation = Vector3.ZERO
	keeper_target_tilt = 0.0


# ---------------- Arayüz ----------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	score_label = Label.new()
	layer.add_child(score_label)
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_top = 50
	score_label.offset_bottom = 120
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(score_label, 40)

	msg_label = Label.new()
	layer.add_child(msg_label)
	msg_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(msg_label, 60)


func _style_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 10)


func _update_ui() -> void:
	score_label.text = "Gol %d   Şut %d/%d   Rekor %d" % [goals, shots, MAX_SHOTS, best]


func _show_msg(text: String, _seconds: float, color: Color = Color.WHITE) -> void:
	msg_label.text = text
	msg_label.add_theme_color_override("font_color", color)
	msg_label.modulate.a = 1.0
	msg_label.visible = true


# ---------------- Dünya ----------------

func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.76, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	# Çim ve şeritler
	_box(Vector3(0, -0.05, -8), Vector3(60, 0.1, 50), Color(0.2, 0.58, 0.24))
	for i in 10:
		if i % 2 == 0:
			_box(Vector3(0, -0.045, 6 - i * 3.0 - 1.5), Vector3(60, 0.1, 3.0), Color(0.23, 0.64, 0.28))

	# Çizgiler
	var w := Color(0.97, 0.97, 0.97)
	_box(Vector3(0, 0.006, GOAL_Z), Vector3(60, 0.02, 0.12), w)
	_box(Vector3(0, 0.006, GOAL_Z + 5.5), Vector3(18.32, 0.02, 0.12), w)
	_box(Vector3(-9.16, 0.006, GOAL_Z + 2.75), Vector3(0.12, 0.02, 5.5), w)
	_box(Vector3(9.16, 0.006, GOAL_Z + 2.75), Vector3(0.12, 0.02, 5.5), w)
	_box(Vector3(-20.16, 0.006, GOAL_Z + 8.25), Vector3(0.12, 0.02, 16.5), w)
	_box(Vector3(20.16, 0.006, GOAL_Z + 8.25), Vector3(0.12, 0.02, 16.5), w)
	_cyl(Vector3(0, 0.006, 0), 0.15, 0.02, w)

	# Kale
	_cyl(Vector3(-GOAL_HALF_W - 0.06, GOAL_H / 2.0, GOAL_Z), 0.06, GOAL_H + 0.12, w)
	_cyl(Vector3(GOAL_HALF_W + 0.06, GOAL_H / 2.0, GOAL_Z), 0.06, GOAL_H + 0.12, w)
	_cyl(Vector3(0, GOAL_H + 0.06, GOAL_Z), 0.06, GOAL_HALF_W * 2.0 + 0.24, w, Vector3(0, 0, 90))
	var net := Color(1, 1, 1, 0.28)
	_box(Vector3(0, GOAL_H / 2.0, GOAL_Z - 1.5), Vector3(GOAL_HALF_W * 2.0, GOAL_H, 0.02), net, true)
	_box(Vector3(0, GOAL_H, GOAL_Z - 0.75), Vector3(GOAL_HALF_W * 2.0, 0.02, 1.5), net, true)
	_box(Vector3(-GOAL_HALF_W, GOAL_H / 2.0, GOAL_Z - 0.75), Vector3(0.02, GOAL_H, 1.5), net, true)
	_box(Vector3(GOAL_HALF_W, GOAL_H / 2.0, GOAL_Z - 0.75), Vector3(0.02, GOAL_H, 1.5), net, true)

	# Reklam panoları
	for i in 6:
		var c := Color(0.1, 0.2, 0.6) if i % 2 == 0 else Color(0.8, 0.15, 0.15)
		_box(Vector3(-15.0 + i * 6.0, 0.5, GOAL_Z - 4.0), Vector3(5.9, 1.0, 0.2), c)

	# Kaleci (orijin ayaklarda, böylece yana yatınca uçuyormuş gibi görünür)
	keeper = Node3D.new()
	add_child(keeper)
	var shirt := Color(1.0, 0.75, 0.1)
	_capsule(Vector3(0, 0.85, 0), 0.28, 1.4, shirt, keeper)
	_sphere(Vector3(0, 1.72, 0), 0.15, Color(0.9, 0.72, 0.58), keeper)
	_box(Vector3(0, 1.4, 0), Vector3(1.5, 0.13, 0.13), shirt, false, keeper)
	_sphere(Vector3(-0.78, 1.4, 0), 0.1, Color(0.2, 0.85, 0.3), keeper)
	_sphere(Vector3(0.78, 1.4, 0), 0.1, Color(0.2, 0.85, 0.3), keeper)

	# Top (dama desenli ki dönüşü görünsün)
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	var bm := StandardMaterial3D.new()
	var img := Image.create(8, 4, false, Image.FORMAT_RGB8)
	for y in 4:
		for x in 8:
			img.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color(0.12, 0.12, 0.12))
	bm.albedo_texture = ImageTexture.create_from_image(img)
	bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sm.material = bm
	ball.mesh = sm
	add_child(ball)

	# Kamera: topun arkasından kaleye bakar
	cam = Camera3D.new()
	cam.fov = 60
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.5, 3.4), Vector3(0, 0.9, GOAL_Z))
	cam.current = true


func _mat(c: Color, transparent: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _add(mi: MeshInstance3D, pos: Vector3, parent: Node) -> MeshInstance3D:
	mi.position = pos
	if parent == null:
		add_child(mi)
	else:
		parent.add_child(mi)
	return mi


func _box(pos: Vector3, size: Vector3, c: Color, transparent: bool = false, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	m.material = _mat(c, transparent)
	mi.mesh = m
	if transparent:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return _add(mi, pos, parent)


func _cyl(pos: Vector3, r: float, h: float, c: Color, rot_deg: Vector3 = Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.material = _mat(c)
	mi.mesh = m
	mi.rotation_degrees = rot_deg
	return _add(mi, pos, parent)


func _sphere(pos: Vector3, r: float, c: Color, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.material = _mat(c)
	mi.mesh = m
	return _add(mi, pos, parent)


func _capsule(pos: Vector3, r: float, h: float, c: Color, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.material = _mat(c)
	mi.mesh = m
	return _add(mi, pos, parent)


# ---------------- Kayıt ----------------

func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://save.cfg") == OK:
		best = int(cf.get_value("game", "best", 0))


func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "best", best)
	cf.save("user://save.cfg")
