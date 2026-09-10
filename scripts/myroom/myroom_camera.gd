extends RefCounted
class_name MyRoomCamera
## Camera feed helper with procedural fallback when no device camera.

signal status_changed(ok: bool, message: String)

var feed: CameraFeed = null
var texture: Texture2D = null
var using_fallback: bool = true
var _fallback_img: ImageTexture = null
var _t: float = 0.0
var _fallback_accum: float = 0.0

func start() -> void:
	stop()
	if OS.get_name() == "Android":
		OS.request_permissions()
	CameraServer.set_monitoring_feeds(true)
	var count := CameraServer.get_feed_count()
	var chosen: CameraFeed = null
	for i in range(count):
		var f: CameraFeed = CameraServer.get_feed(i)
		if f == null:
			continue
		# Prefer front camera for Portrait; any active feed otherwise.
		if f.get_position() == CameraFeed.FEED_FRONT:
			chosen = f
			break
		if chosen == null:
			chosen = f
	if chosen != null:
		chosen.set_active(true)
		feed = chosen
		var cam_tex := CameraTexture.new()
		cam_tex.camera_feed_id = chosen.get_id()
		texture = cam_tex
		using_fallback = false
		status_changed.emit(true, "摄像头已开启")
		return
	_build_fallback()
	using_fallback = true
	status_changed.emit(false, "无摄像头，使用模拟背景（编辑器/桌面常见）")

func stop() -> void:
	if feed != null:
		feed.set_active(false)
		feed = null
	texture = null

func tick_fallback(delta: float) -> void:
	if not using_fallback or _fallback_img == null:
		return
	_t += delta
	_fallback_accum += delta
	if _fallback_accum < 0.12:
		return
	_fallback_accum = 0.0
	_rebuild_fallback_frame()

func _build_fallback() -> void:
	_fallback_img = ImageTexture.new()
	_rebuild_fallback_frame()
	texture = _fallback_img

func _rebuild_fallback_frame() -> void:
	var w := 180
	var h := 320
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in range(h):
		var v := float(y) / float(h)
		for x in range(w):
			var u := float(x) / float(w)
			var wave := 0.5 + 0.5 * sin(_t * 1.2 + u * 6.0 + v * 4.0)
			var r := int(40 + 50 * wave + 30 * u)
			var g := int(55 + 40 * (1.0 - wave) + 20 * v)
			var b := int(70 + 60 * wave)
			var c := Color8(clampi(r, 0, 255), clampi(g, 0, 255), clampi(b, 0, 255))
			if v > 0.62:
				c = c.lerp(Color(0.2, 0.22, 0.25), 0.35)
			img.set_pixel(x, y, c)
	_fallback_img.set_image(img)
