extends Node3D
## Penaltı Ustası 3D
## Parmağını yukarı doğru kaydır: sağa/sola çekmek yönü, kaydırma uzunluğu yüksekliği,
## kaydırma hızı şutun gücünü belirler. 5 şutluk seride kaleciyi geç.

const KALE_Z := -11.0
const KALE_YARI := 3.66
const KALE_H := 2.44
const DIREK_R := 0.06
const TOP_R := 0.11
const YERCEKIMI := 9.8
const SUT_SAYISI := 5
const KARAKTER_BOY := 2.187  # KayKit modelinin Blender'daki boyu
const OYUNCU_OLCEK := 1.8 / KARAKTER_BOY
const KALECI_OLCEK := 1.9 / KARAKTER_BOY
const KALECI_Z := KALE_Z + 0.45
const KOSU_BAS := Vector3(-0.85, 0.0, 1.5)
const KOSU_SON := Vector3(-0.32, 0.0, 0.55)
const KOSU_SURE := 0.5
const TEMAS_SURE := 0.36  # şut animasyonunda ayağın topa değdiği an

enum Durum { HAZIR, KOSU, UCUS, SONUC, BITTI }

var durum: Durum = Durum.HAZIR

# Sahne parçaları
var top: Node3D
var oyuncu: Node3D
var oyuncu_anim: AnimationPlayer
var kaleci: Node3D
var kaleci_anim: AnimationPlayer
var ag: Node3D
var kamera: Camera3D
var nisan_noktalari: Array[MeshInstance3D] = []

# Arayüz
var skor_etiket: Label
var mesaj_etiket: Label
var sut_isaretleri: Array[Panel] = []
var sut_sonuclari: Array[int] = []  # 1 gol, 0 kaçtı

# Sesler
var ses_tekme: AudioStreamPlayer
var ses_gol: AudioStreamPlayer
var ses_of: AudioStreamPlayer
var ses_duduk: AudioStreamPlayer

# Şut durumu
var top_hiz := Vector3.ZERO
var top_dur := false
var karar_verildi := false
var kaleciyi_gecti := false
var sonuc_sayac := 0.0
var kosu_sayac := 0.0
var bekleyen_kaydirma := Vector2.ZERO
var bekleyen_guc := 1.0

# Dokunma
var parmak_basili := false
var parmak_bas := Vector2.ZERO
var parmak_simdi := Vector2.ZERO
var parmak_sure := 0.0

# Kaleci
var kaleci_hedef_x := 0.0
var kaleci_hedef_egim := 0.0
var kaleci_gecikme := 0.0
var kaleci_ziplama := 0.0
var bos_zaman := 0.0

var goller := 0
var sutlar := 0
var rekor := 0


func _ready() -> void:
	_rekor_yukle()
	_dunya_kur()
	_karakterleri_kur()
	_arayuz_kur()
	_sesleri_kur()
	_sutu_sifirla()
	_arayuz_guncelle()
	_mesaj("Parmağını yukarı kaydır, şut çek!")
	var argumanlar := OS.get_cmdline_user_args()
	for a in argumanlar:
		if a.begins_with("--onizleme="):
			_onizleme_cek(a.trim_prefix("--onizleme="))


func _notification(what: int) -> void:
	# Arka plandayken pili korumak için kare hızını düşür
	if what == NOTIFICATION_APPLICATION_PAUSED:
		Engine.max_fps = 5
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		Engine.max_fps = 0


# ================================================================ DÖNGÜ

func _process(delta: float) -> void:
	if parmak_basili:
		parmak_sure += delta
	_mesaj_solsun(delta)

	match durum:
		Durum.HAZIR:
			bos_zaman += delta
			kaleci.position.x = sin(bos_zaman * 1.3) * 0.45
		Durum.KOSU:
			_kosu_isle(delta)
			_kaleci_hareket(delta)
		Durum.UCUS, Durum.SONUC:
			_kaleci_hareket(delta)
			if not top_dur:
				_top_hareket(delta)
			if durum == Durum.SONUC:
				sonuc_sayac -= delta
				if sonuc_sayac <= 0.0:
					_sonraki_sut()


func _kosu_isle(delta: float) -> void:
	kosu_sayac += delta
	if kosu_sayac < KOSU_SURE:
		var t := kosu_sayac / KOSU_SURE
		oyuncu.position = KOSU_BAS.lerp(KOSU_SON, t)
		return
	if oyuncu_anim.current_animation != "Unarmed_Melee_Attack_Kick":
		oyuncu.position = KOSU_SON
		oyuncu.rotation.y = PI
		oyuncu_anim.play("Unarmed_Melee_Attack_Kick", 0.08)
	if kosu_sayac >= KOSU_SURE + TEMAS_SURE:
		_topa_vur()


func _top_hareket(delta: float) -> void:
	var once := top.position
	top_hiz.y -= YERCEKIMI * delta
	top.position += top_hiz * delta
	var dikey := Vector3(top_hiz.x, 0, top_hiz.z)
	if dikey.length() > 0.1:
		top.rotate(dikey.cross(Vector3.UP).normalized(), -dikey.length() * delta / TOP_R)

	if top.position.y < TOP_R:
		top.position.y = TOP_R
		top_hiz.y = absf(top_hiz.y) * 0.45
		top_hiz.x *= 0.85
		top_hiz.z *= 0.85
		if top_hiz.length() < 0.4:
			top_dur = true

	if karar_verildi:
		# Ağın içinde yavaşla
		if absf(top.position.x) < KALE_YARI and top.position.z < KALE_Z - 1.5:
			top.position.z = KALE_Z - 1.5
			top_hiz = Vector3(top_hiz.x * 0.2, minf(top_hiz.y, 0.0), 0.6)
		return

	# Kaleci
	if not kaleciyi_gecti and once.z > KALECI_Z and top.position.z <= KALECI_Z:
		kaleciyi_gecti = true
		if _kaleci_degdi(Vector2(top.position.x, top.position.y)):
			top_hiz = Vector3(top_hiz.x * 0.25 + randf_range(-2.5, 2.5), 3.0, 6.0)
			kaleci_anim.play("Cheer", 0.3)
			_bitir(false, "Kaleci kurtardı!")
			return

	# Kale çizgisi
	if once.z > KALE_Z and top.position.z <= KALE_Z:
		var x := absf(top.position.x)
		var y := top.position.y
		if x < KALE_YARI - TOP_R and y < KALE_H - TOP_R:
			top_hiz *= 0.4
			_ag_salla()
			_bitir(true, "GOOOL!")
		elif x < KALE_YARI + DIREK_R + TOP_R and y < KALE_H + DIREK_R + TOP_R:
			top_hiz = Vector3(-top_hiz.x * 0.4, top_hiz.y * 0.5, 7.0)
			_bitir(false, "Direk!")
		else:
			_bitir(false, "Dışarı!")
		return

	if absf(top.position.x) > 20.0 or top.position.y > 15.0 or top.position.z > 8.0:
		_bitir(false, "Dışarı!")


func _kaleci_hareket(delta: float) -> void:
	if kaleci_gecikme > 0.0:
		kaleci_gecikme -= delta
		if kaleci_gecikme <= 0.0:
			_kaleci_atla()
		return
	kaleci.position.x = move_toward(kaleci.position.x, kaleci_hedef_x, 7.0 * delta)
	kaleci.rotation.z = move_toward(kaleci.rotation.z, kaleci_hedef_egim, 5.5 * delta)
	kaleci_ziplama = maxf(kaleci_ziplama - delta, 0.0)
	var t := 1.0 - kaleci_ziplama / 0.55
	kaleci.position.y = sin(clampf(t, 0.0, 1.0) * PI) * 0.35 if kaleci_ziplama > 0.0 else 0.0


func _kaleci_degdi(p: Vector2) -> bool:
	# Gövde: ayaklardan başa bir çizgi; kollar: omuz hizasında yatay çizgi
	var ayak := kaleci.global_position
	var bas := kaleci.to_global(Vector3(0, 1.8 / KALECI_OLCEK, 0))
	var kol_sol := kaleci.to_global(Vector3(-0.95 / KALECI_OLCEK, 1.35 / KALECI_OLCEK, 0))
	var kol_sag := kaleci.to_global(Vector3(0.95 / KALECI_OLCEK, 1.35 / KALECI_OLCEK, 0))
	var govde_mesafe := _parca_mesafe(p, Vector2(ayak.x, ayak.y), Vector2(bas.x, bas.y))
	var kol_mesafe := _parca_mesafe(p, Vector2(kol_sol.x, kol_sol.y), Vector2(kol_sag.x, kol_sag.y))
	return govde_mesafe < 0.42 or kol_mesafe < 0.25


func _parca_mesafe(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ================================================================ GİRDİ

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var dokunma := event as InputEventScreenTouch
		if dokunma.index != 0:
			return
		if dokunma.pressed:
			_parmak_indi(dokunma.position)
		else:
			_parmak_kalkti(dokunma.position)
	elif event is InputEventScreenDrag:
		var surukle := event as InputEventScreenDrag
		if surukle.index == 0 and parmak_basili:
			parmak_simdi = surukle.position
			_nisan_guncelle()


func _parmak_indi(konum: Vector2) -> void:
	if durum == Durum.BITTI:
		_yeniden_basla()
		return
	if durum != Durum.HAZIR:
		return
	parmak_basili = true
	parmak_bas = konum
	parmak_simdi = konum
	parmak_sure = 0.0


func _parmak_kalkti(konum: Vector2) -> void:
	if not parmak_basili:
		return
	parmak_basili = false
	_nisan_gizle()
	var kaydirma := konum - parmak_bas
	var ekran := get_viewport().get_visible_rect().size
	if -kaydirma.y / ekran.y < 0.06:
		_mesaj("Yukarı doğru kaydır!")
		return
	var hiz := kaydirma.length() / ekran.y / maxf(parmak_sure, 0.05)
	bekleyen_kaydirma = kaydirma
	bekleyen_guc = clampf(hiz / 2.5, 0.7, 1.35)
	_kosuya_basla()


func _sut_hizi(kaydirma: Vector2, guc: float, rastgele: bool) -> Vector3:
	var ekran := get_viewport().get_visible_rect().size
	var yukari := -kaydirma.y / ekran.y
	var yan := kaydirma.x / ekran.x
	var vz := -19.0 * guc
	var t := absf(KALE_Z / vz)
	var hedef_x := clampf(yan * 13.0, -7.0, 7.0)
	var hedef_y := clampf((yukari - 0.06) * 5.0, 0.0, 4.0)
	if rastgele:
		hedef_x += randf_range(-0.25, 0.25)
		hedef_y += randf_range(-0.15, 0.15)
	return Vector3(hedef_x / t, (hedef_y + 0.5 * YERCEKIMI * t * t - TOP_R) / t, vz)


# ================================================================ ŞUT AKIŞI

func _kosuya_basla() -> void:
	durum = Durum.KOSU
	kosu_sayac = 0.0
	oyuncu.position = KOSU_BAS
	var yon := KOSU_SON - KOSU_BAS
	oyuncu.rotation.y = atan2(yon.x, yon.z)
	oyuncu_anim.play("Running_A", 0.1)


func _topa_vur() -> void:
	top_hiz = _sut_hizi(bekleyen_kaydirma, bekleyen_guc, true)
	top_dur = false
	karar_verildi = false
	kaleciyi_gecti = false
	durum = Durum.UCUS
	ses_tekme.play()
	_kaleci_karar(top_hiz)


func _kaleci_karar(hiz: Vector3) -> void:
	var t := absf((KALECI_Z - top.position.z) / hiz.z)
	var tahmin_x := top.position.x + hiz.x * t
	var tahmin_y := top.position.y + hiz.y * t - 0.5 * YERCEKIMI * t * t
	# Her golde biraz daha iyi tahmin eder, ama asla kusursuz değil
	var beceri := minf(0.35 + goller * 0.08 + sutlar * 0.03, 0.75)
	var hedef: float
	if randf() < beceri:
		hedef = tahmin_x + randf_range(-0.7, 0.7)
	else:
		hedef = randf_range(-3.0, 3.0)
	hedef = clampf(hedef, -3.4, 3.4)
	var fark := hedef - kaleci.position.x
	if absf(fark) < 0.7:
		kaleci_hedef_egim = 0.0
		kaleci_hedef_x = hedef
	else:
		var egim := clampf(absf(fark) / 2.6, 0.0, 1.0) * 1.35
		kaleci_hedef_egim = -signf(fark) * egim
		kaleci_hedef_x = hedef - signf(fark) * sin(egim) * 1.1
	kaleci.set_meta("yukarida", tahmin_y > 1.7 and absf(fark) < 1.2)
	# Tepki gecikmesi: 0.2 - 0.35 sn
	kaleci_gecikme = lerpf(0.35, 0.2, (beceri - 0.35) / 0.4)


func _kaleci_atla() -> void:
	var fark := kaleci_hedef_x - kaleci.position.x
	if bool(kaleci.get_meta("yukarida", false)):
		kaleci_anim.play("Jump_Full_Short", 0.08)
		kaleci_ziplama = 0.55
	elif absf(kaleci_hedef_egim) < 0.01:
		kaleci_anim.play("Block", 0.08)
	else:
		# Kaleci kameraya bakıyor: onun solu ekranın sağı (+X)
		kaleci_anim.play("Dodge_Left" if fark > 0.0 else "Dodge_Right", 0.05)
		kaleci_ziplama = 0.55


func _bitir(gol: bool, metin: String) -> void:
	karar_verildi = true
	durum = Durum.SONUC
	sutlar += 1
	sut_sonuclari.append(1 if gol else 0)
	if gol:
		goller += 1
		oyuncu_anim.play("Cheer", 0.25)
		kaleci_anim.play("Hit_A", 0.3)
		ses_gol.play()
	else:
		oyuncu_anim.play("Hit_A", 0.25)
		ses_of.play()
	sonuc_sayac = 2.0
	_mesaj(metin, Color(1.0, 0.86, 0.2) if gol else Color.WHITE)
	_arayuz_guncelle()


func _sonraki_sut() -> void:
	if sutlar >= SUT_SAYISI:
		if goller > rekor:
			rekor = goller
			_rekor_kaydet()
		_sutu_sifirla()
		durum = Durum.BITTI
		ses_duduk.play()
		_arayuz_guncelle()
		_mesaj("Seri bitti!\n%d / %d gol\n\nTekrar için dokun" % [goller, SUT_SAYISI], Color.WHITE, true)
		return
	_sutu_sifirla()


func _yeniden_basla() -> void:
	goller = 0
	sutlar = 0
	sut_sonuclari.clear()
	_sutu_sifirla()
	_arayuz_guncelle()
	_mesaj("Yeni seri! Şut çek.")


func _sutu_sifirla() -> void:
	durum = Durum.HAZIR
	karar_verildi = false
	top_dur = false
	top_hiz = Vector3.ZERO
	top.position = Vector3(0, TOP_R, 0)
	top.rotation = Vector3.ZERO
	oyuncu.position = KOSU_BAS
	oyuncu.rotation.y = atan2(-KOSU_BAS.x, -KOSU_BAS.z)
	oyuncu_anim.play("Unarmed_Idle", 0.3)
	kaleci.position = Vector3(0, 0, KALECI_Z)
	kaleci.rotation = Vector3.ZERO
	kaleci_hedef_egim = 0.0
	kaleci_gecikme = 0.0
	kaleci_ziplama = 0.0
	kaleci_anim.play("Unarmed_Idle", 0.3)


func _ag_salla() -> void:
	if ag == null:
		return
	var tw := create_tween()
	var z0 := ag.position.z
	tw.tween_property(ag, "position:z", z0 - 0.35, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(ag, "position:z", z0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ================================================================ NİŞAN

func _nisan_guncelle() -> void:
	var kaydirma := parmak_simdi - parmak_bas
	var ekran := get_viewport().get_visible_rect().size
	if -kaydirma.y / ekran.y < 0.06:
		_nisan_gizle()
		return
	var hiz := _sut_hizi(kaydirma, 1.0, false)
	var t_son := absf(KALE_Z / hiz.z)
	for i in nisan_noktalari.size():
		var t := t_son * float(i + 1) / nisan_noktalari.size()
		var p := Vector3(0, TOP_R, 0) + hiz * t + Vector3(0, -0.5 * YERCEKIMI * t * t, 0)
		var n := nisan_noktalari[i]
		n.visible = p.y > 0.0
		n.position = p


func _nisan_gizle() -> void:
	for n in nisan_noktalari:
		n.visible = false


# ================================================================ ARAYÜZ

func _arayuz_kur() -> void:
	var katman := CanvasLayer.new()
	add_child(katman)

	var ust_bosluk := 40.0
	var guvenli := DisplayServer.get_display_safe_area()
	var pencere := DisplayServer.window_get_size()
	if pencere.y > 0:
		ust_bosluk += guvenli.position.y * get_viewport().get_visible_rect().size.y / pencere.y

	var serit := ColorRect.new()
	serit.color = Color(0, 0, 0, 0.35)
	serit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	katman.add_child(serit)
	serit.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	serit.offset_bottom = ust_bosluk + 120

	skor_etiket = Label.new()
	katman.add_child(skor_etiket)
	skor_etiket.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	skor_etiket.offset_top = ust_bosluk
	skor_etiket.offset_bottom = ust_bosluk + 60
	skor_etiket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiket_stili(skor_etiket, 40)

	var kutu := HBoxContainer.new()
	katman.add_child(kutu)
	kutu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	kutu.offset_top = ust_bosluk + 66
	kutu.offset_bottom = ust_bosluk + 100
	kutu.offset_left = -130
	kutu.offset_right = 130
	kutu.alignment = BoxContainer.ALIGNMENT_CENTER
	kutu.add_theme_constant_override("separation", 18)
	for i in SUT_SAYISI:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(34, 34)
		kutu.add_child(p)
		sut_isaretleri.append(p)

	mesaj_etiket = Label.new()
	katman.add_child(mesaj_etiket)
	mesaj_etiket.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mesaj_etiket.offset_top = ust_bosluk + 120
	mesaj_etiket.offset_bottom = ust_bosluk + 420
	mesaj_etiket.offset_left = 30
	mesaj_etiket.offset_right = -30
	mesaj_etiket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesaj_etiket.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mesaj_etiket.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mesaj_etiket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etiket_stili(mesaj_etiket, 64)


func _etiket_stili(l: Label, boyut: int) -> void:
	l.add_theme_font_size_override("font_size", boyut)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 12)


func _arayuz_guncelle() -> void:
	skor_etiket.text = "GOL %d    REKOR %d" % [goller, rekor]
	for i in sut_isaretleri.size():
		var stil := StyleBoxFlat.new()
		stil.set_corner_radius_all(17)
		stil.set_border_width_all(3)
		stil.border_color = Color(1, 1, 1, 0.9)
		if i < sut_sonuclari.size():
			stil.bg_color = Color(0.2, 0.8, 0.3) if sut_sonuclari[i] == 1 else Color(0.85, 0.2, 0.2)
		else:
			stil.bg_color = Color(1, 1, 1, 0.15)
		sut_isaretleri[i].add_theme_stylebox_override("panel", stil)


func _mesaj(metin: String, renk: Color = Color.WHITE, kalici: bool = false) -> void:
	mesaj_etiket.text = metin
	mesaj_etiket.add_theme_color_override("font_color", renk)
	mesaj_etiket.modulate.a = 1.0
	mesaj_etiket.visible = true
	mesaj_etiket.set_meta("kalici", kalici)
	mesaj_etiket.set_meta("bekle", 1.0)


func _mesaj_solsun(delta: float) -> void:
	if not mesaj_etiket.visible or bool(mesaj_etiket.get_meta("kalici", false)):
		return
	var bekle := float(mesaj_etiket.get_meta("bekle", 0.0)) - delta
	mesaj_etiket.set_meta("bekle", bekle)
	if bekle < 0.0:
		mesaj_etiket.modulate.a = maxf(mesaj_etiket.modulate.a - delta * 1.5, 0.0)
		if mesaj_etiket.modulate.a <= 0.0:
			mesaj_etiket.visible = false


# ================================================================ DÜNYA

func _dunya_kur() -> void:
	# Gökyüzü
	var ortam_dugum := WorldEnvironment.new()
	var ortam := Environment.new()
	var gok := Sky.new()
	var gok_malzeme := PanoramaSkyMaterial.new()
	gok_malzeme.panorama = load("res://assets/polyhaven/kloofendal_48d_partly_cloudy_puresky/sky.jpg")
	gok.sky_material = gok_malzeme
	ortam.background_mode = Environment.BG_SKY
	ortam.sky = gok
	ortam.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	ortam.ambient_light_energy = 0.7
	ortam.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ortam_dugum.environment = ortam
	add_child(ortam_dugum)

	var gunes := DirectionalLight3D.new()
	gunes.rotation_degrees = Vector3(-50, 30, 0)
	gunes.light_energy = 1.15
	gunes.shadow_enabled = true
	gunes.directional_shadow_max_distance = 40.0
	add_child(gunes)

	# Çim: gerçek doku, dünya koordinatına göre döşenir; biçilmiş şeritler için iki ton
	var cim_doku: Texture2D = load("res://assets/polyhaven/grass_ground/Diffuse.jpg")
	var cim_normal: Texture2D = load("res://assets/polyhaven/grass_ground/nor_gl.jpg")
	for i in 12:
		var m := StandardMaterial3D.new()
		m.albedo_texture = cim_doku
		m.normal_enabled = true
		m.normal_texture = cim_normal
		m.normal_scale = 0.6
		m.roughness = 0.95
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.35, 0.35, 0.35)
		m.albedo_color = Color(0.62, 0.95, 0.5) if i % 2 == 0 else Color(0.52, 0.82, 0.42)
		var serit := MeshInstance3D.new()
		var duz := PlaneMesh.new()
		duz.size = Vector2(90, 3.6)
		duz.material = m
		serit.mesh = duz
		serit.position = Vector3(0, 0, 6.0 - i * 3.6 - 1.8)
		add_child(serit)
	# Tribünlerin altında kalan zemin
	_kutu(Vector3(0, -0.06, -40), Vector3(120, 0.1, 60), Color(0.28, 0.45, 0.22))

	# Saha çizgileri
	var beyaz := Color(0.96, 0.96, 0.96)
	_kutu(Vector3(0, 0.006, KALE_Z), Vector3(90, 0.012, 0.12), beyaz)
	_kutu(Vector3(0, 0.006, KALE_Z + 16.5), Vector3(40.32, 0.012, 0.12), beyaz)
	_kutu(Vector3(-20.16, 0.006, KALE_Z + 8.25), Vector3(0.12, 0.012, 16.5), beyaz)
	_kutu(Vector3(20.16, 0.006, KALE_Z + 8.25), Vector3(0.12, 0.012, 16.5), beyaz)
	_kutu(Vector3(0, 0.006, KALE_Z + 5.5), Vector3(18.32, 0.012, 0.12), beyaz)
	_kutu(Vector3(-9.16, 0.006, KALE_Z + 2.75), Vector3(0.12, 0.012, 5.5), beyaz)
	_kutu(Vector3(9.16, 0.006, KALE_Z + 2.75), Vector3(0.12, 0.012, 5.5), beyaz)
	var nokta := MeshInstance3D.new()
	var silindir := CylinderMesh.new()
	silindir.top_radius = 0.11
	silindir.bottom_radius = 0.11
	silindir.height = 0.004
	silindir.material = _malzeme(beyaz)
	nokta.mesh = silindir
	nokta.position = Vector3(0, 0.003, 0)
	add_child(nokta)
	# Ceza yayı
	for i in 24:
		var aci := lerpf(-0.93, 0.93, float(i) / 23.0)
		var p := Vector3(sin(aci) * 9.15, 0.006, cos(aci) * 9.15)
		if p.z > 16.5 + KALE_Z - 0.0 and p.z > 5.5:
			_kutu(p, Vector3(0.12, 0.012, 1.25), beyaz, Vector3(0, aci + PI / 2, 0))

	# Blender'da modellenen nesneler
	var kale := _model("res://assets/modeller/kale.glb")
	kale.position = Vector3(0, 0, KALE_Z)
	ag = kale.find_child("Ag", true, false) as Node3D
	var tribun := _model("res://assets/modeller/tribun.glb")
	tribun.position = Vector3(0, 0, KALE_Z)
	# Çatının alt yüzü kameradan çok koyu görünüyor: açık metal tonu
	for mi in tribun.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat and mat.resource_name == "Cati" and mat is StandardMaterial3D:
				var yeni := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				yeni.albedo_color = Color(0.72, 0.76, 0.82)
				(mi as MeshInstance3D).set_surface_override_material(i, yeni)
	for x in [-34.0, 34.0]:
		var b := _model("res://assets/modeller/bayrak.glb")
		b.position = Vector3(x, 0, KALE_Z)

	top = _model("res://assets/modeller/top.glb")

	# Nişan noktaları
	var nokta_malzeme := StandardMaterial3D.new()
	nokta_malzeme.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nokta_malzeme.albedo_color = Color(1, 1, 1, 0.75)
	nokta_malzeme.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 14:
		var n := MeshInstance3D.new()
		var k := SphereMesh.new()
		k.radius = 0.06 + i * 0.004
		k.height = k.radius * 2.0
		k.radial_segments = 8
		k.rings = 4
		k.material = nokta_malzeme
		n.mesh = k
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.visible = false
		add_child(n)
		nisan_noktalari.append(n)

	# Kamera: oyuncunun arkasından kaleye; ekran genişliği ne olursa olsun kale sığsın
	kamera = Camera3D.new()
	kamera.keep_aspect = Camera3D.KEEP_WIDTH
	kamera.fov = 30.0
	kamera.far = 300.0
	add_child(kamera)
	kamera.look_at_from_position(Vector3(0.45, 2.9, 7.0), Vector3(0, 1.0, KALE_Z))
	kamera.current = true


func _karakterleri_kur() -> void:
	oyuncu = _model("res://assets/modeller/oyuncu.glb")
	oyuncu.scale = Vector3.ONE * OYUNCU_OLCEK
	oyuncu_anim = oyuncu.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	kaleci = _model("res://assets/modeller/kaleci.glb")
	kaleci.scale = Vector3.ONE * KALECI_OLCEK
	kaleci_anim = kaleci.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for ap in [oyuncu_anim, kaleci_anim]:
		for ad in ["Idle", "Unarmed_Idle", "Running_A", "Blocking", "Cheer"]:
			if ap.has_animation(ad):
				ap.get_animation(ad).loop_mode = Animation.LOOP_LINEAR


func _model(yol: String) -> Node3D:
	var sahne: PackedScene = load(yol)
	var n := sahne.instantiate() as Node3D
	add_child(n)
	return n


func _malzeme(renk: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = renk
	m.roughness = 0.9
	return m


func _kutu(konum: Vector3, boyut: Vector3, renk: Color, donus: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = boyut
	m.material = _malzeme(renk)
	mi.mesh = m
	mi.position = konum
	mi.rotation = donus
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# ================================================================ SESLER (kodla üretilir)

func _sesleri_kur() -> void:
	ses_tekme = _ses_oynatici(_ses_uret("tekme", 0.25), -2.0)
	ses_gol = _ses_oynatici(_ses_uret("gol", 2.6), -4.0)
	ses_of = _ses_oynatici(_ses_uret("of", 1.3), -6.0)
	ses_duduk = _ses_oynatici(_ses_uret("duduk", 0.9), -8.0)


func _ses_oynatici(akis: AudioStreamWAV, db: float) -> AudioStreamPlayer:
	var o := AudioStreamPlayer.new()
	o.stream = akis
	o.volume_db = db
	add_child(o)
	return o


func _ses_uret(tur: String, sure: float) -> AudioStreamWAV:
	const ORAN := 22050
	var n := int(sure * ORAN)
	var veri := PackedByteArray()
	veri.resize(n * 2)
	var suzgec := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tur)
	for i in n:
		var t := float(i) / ORAN
		var gurultu := rng.randf_range(-1.0, 1.0)
		var s := 0.0
		match tur:
			"tekme":
				s = sin(TAU * (110.0 - t * 160.0) * t) * exp(-t * 22.0) + gurultu * exp(-t * 70.0) * 0.6
			"gol":
				suzgec += (gurultu - suzgec) * 0.18
				var zarf := minf(t / 0.25, 1.0) * exp(-maxf(t - 0.6, 0.0) * 1.3)
				s = suzgec * zarf * 2.6 * (0.85 + 0.15 * sin(TAU * 3.0 * t))
			"of":
				suzgec += (gurultu - suzgec) * 0.06
				s = suzgec * minf(t / 0.15, 1.0) * exp(-t * 2.2) * 4.0
			"duduk":
				var ac := 1.0 if fmod(t, 0.45) < 0.32 else 0.0
				s = sin(TAU * 2900.0 * t + 6.0 * sin(TAU * 28.0 * t)) * ac * 0.5
		veri.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var akis := AudioStreamWAV.new()
	akis.format = AudioStreamWAV.FORMAT_16_BITS
	akis.mix_rate = ORAN
	akis.stereo = false
	akis.data = veri
	return akis


# ================================================================ KAYIT

func _rekor_yukle() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://kayit.cfg") == OK:
		rekor = int(cf.get_value("oyun", "rekor", 0))


func _rekor_kaydet() -> void:
	var cf := ConfigFile.new()
	cf.set_value("oyun", "rekor", rekor)
	cf.save("user://kayit.cfg")


# ================================================================ ÖNİZLEME (bulutta ekran görüntüsü)

func _onizleme_cek(klasor: String) -> void:
	DirAccess.make_dir_recursive_absolute(klasor)
	await _bekle(1.2)
	await _kare_kaydet(klasor + "/1_bekleme.png")
	# Nişan alma
	var ekran := get_viewport().get_visible_rect().size
	parmak_basili = true
	parmak_bas = Vector2(ekran.x * 0.5, ekran.y * 0.85)
	parmak_simdi = parmak_bas + Vector2(ekran.x * 0.22, -ekran.y * 0.3)
	_nisan_guncelle()
	await _bekle(0.2)
	await _kare_kaydet(klasor + "/2_nisan.png")
	parmak_basili = false
	_nisan_gizle()
	# Şut: koşu, vuruş, uçuş
	bekleyen_kaydirma = parmak_simdi - parmak_bas
	bekleyen_guc = 1.0
	_kosuya_basla()
	await _bekle(KOSU_SURE + 0.2)
	await _kare_kaydet(klasor + "/3_vurus.png")
	await _bekle(0.45)
	await _kare_kaydet(klasor + "/4_ucus.png")
	await _bekle(0.9)
	await _kare_kaydet(klasor + "/5_sonuc.png")
	get_tree().quit()


func _bekle(sn: float) -> void:
	await get_tree().create_timer(sn).timeout


func _kare_kaydet(yol: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(yol)
	print("ONIZLEME kaydedildi: ", yol)
