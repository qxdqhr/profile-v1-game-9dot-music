extends Control
## Agent chart lab: paste Bilibili URL → generate playable Normal chart (M4 stub).

@onready var _url: LineEdit = $Center/Panel/Margin/VBox/Url
@onready var _bpm: SpinBox = $Center/Panel/Margin/VBox/Bpm
@onready var _dur: SpinBox = $Center/Panel/Margin/VBox/Dur
@onready var _hint: Label = $Center/Panel/Margin/VBox/Hint

func _ready() -> void:
	NineDotTheme.apply_to(self)
	_bpm.min_value = 60
	_bpm.max_value = 220
	_bpm.value = 120
	_dur.min_value = 8
	_dur.max_value = 60
	_dur.value = 16
	_url.placeholder_text = "https://www.bilibili.com/video/BVxxxx"
	$Center/Panel/Margin/VBox/GenBtn.theme_type_variation = &"PrimaryButton"
	$Center/Panel/Margin/VBox/GenBtn.pressed.connect(_on_generate)
	$Center/Panel/Margin/VBox/PlayBtn.pressed.connect(_on_play)
	$Center/Panel/Margin/VBox/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	for b in [$Center/Panel/Margin/VBox/GenBtn, $Center/Panel/Margin/VBox/PlayBtn, $Center/Panel/Margin/VBox/BackBtn]:
		NineDotUiJuice.wire_button_press_juice(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.text = "MVP：不拉取真实 B 站流；用内置音视频 + 启发式谱面，打通「链接 → 可玩」管线。"
	await get_tree().process_frame
	NineDotUiJuice.enter_panel($Center/Panel)

func _on_generate() -> void:
	var url := _url.text.strip_edges()
	if url.is_empty() or not NineDotAgent.is_bilibili_url(url):
		_hint.text = "请输入有效的 B 站链接或 BV 号"
		return
	var meta := NineDotAgent.generate(url, float(_bpm.value), int(_dur.value) * 1000)
	PlaySession.select_chart(String(meta.get("id", "")), String(meta.get("_metaPath", "")))
	PlaySession.select_diff("normal")
	_hint.text = "已生成：%s（已写入本地缓存，可开始游玩）" % String(meta.get("title", ""))

func _on_play() -> void:
	if String(PlaySession.meta_path).is_empty() or not String(PlaySession.meta_path).contains("nine_dot_agent"):
		_hint.text = "请先生成谱面"
		return
	PlaySession.select_diff("normal")
	get_tree().change_scene_to_file("res://scenes/play.tscn")
