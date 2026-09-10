extends RefCounted
class_name PlayHudLayout
## Play HUD metric arrangement presets (maimai-inspired).

const LAYOUT_STACK_CENTER := "stack_center"
const LAYOUT_STACK_LEFT := "stack_left"
const LAYOUT_STACK_RIGHT := "stack_right"
const LAYOUT_SPLIT_MAIMAI := "split_maimai"

const OPTIONS: Array[String] = [
	LAYOUT_STACK_CENTER,
	LAYOUT_STACK_LEFT,
	LAYOUT_STACK_RIGHT,
	LAYOUT_SPLIT_MAIMAI,
]

const LABELS: Array[String] = [
	"居中柱",
	"左侧柱",
	"右侧柱",
	"分离（mai）",
]

static func is_valid(layout: String) -> bool:
	return layout in OPTIONS

static func index_of(layout: String) -> int:
	var i := OPTIONS.find(layout)
	return i if i >= 0 else 0

## Positions title / metrics / progress for the current viewport size.
static func apply(
	layout: String,
	view: Vector2,
	title_frame: Control,
	judge: Label,
	combo: Label,
	score: Label,
	acc: Label,
	progress: Control,
	pause_row: Control,
) -> void:
	var w := view.x
	var h := view.y
	var margin := 12.0
	var title_h := NineDotConfig.TITLE_FRAME_HEIGHT
	var title_top := NineDotConfig.TITLE_FRAME_TOP
	var prog_h := NineDotConfig.PROGRESS_BAR_HEIGHT

	# Title: left, leave room for pause
	if title_frame:
		title_frame.offset_left = margin
		title_frame.offset_top = title_top
		title_frame.offset_right = w - 56.0
		title_frame.offset_bottom = title_top + title_h

	if pause_row:
		pause_row.offset_left = w - 52.0
		pause_row.offset_top = title_top
		pause_row.offset_right = w - 8.0
		pause_row.offset_bottom = title_top + 44.0

	if progress:
		progress.offset_left = 0.0
		progress.offset_right = w
		progress.offset_top = h - prog_h
		progress.offset_bottom = h

	var stack_top := title_top + title_h + 8.0
	var col_w := minf(280.0, w - margin * 2.0)
	var align := HORIZONTAL_ALIGNMENT_CENTER
	var left := (w - col_w) * 0.5
	match layout:
		LAYOUT_STACK_LEFT:
			align = HORIZONTAL_ALIGNMENT_LEFT
			left = margin
		LAYOUT_STACK_RIGHT:
			align = HORIZONTAL_ALIGNMENT_RIGHT
			left = w - margin - col_w
		LAYOUT_SPLIT_MAIMAI:
			_apply_split(w, margin, stack_top, title_top, title_h, judge, combo, score, acc)
			return
		_:
			align = HORIZONTAL_ALIGNMENT_CENTER
			left = (w - col_w) * 0.5

	_place_stack(left, stack_top, col_w, align, judge, combo, score, acc)

static func _place_stack(
	left: float,
	top: float,
	col_w: float,
	align: HorizontalAlignment,
	judge: Label,
	combo: Label,
	score: Label,
	acc: Label,
) -> void:
	var y := top
	var h_judge := NineDotConfig.HUD_JUDGE_HEIGHT
	var h_combo := NineDotConfig.HUD_COMBO_HEIGHT
	var h_score := NineDotConfig.HUD_SCORE_HEIGHT
	var h_acc := NineDotConfig.HUD_ACC_HEIGHT
	_place_label(judge, left, y, col_w, h_judge, align)
	y += h_judge
	_place_label(combo, left, y, col_w, h_combo, align)
	y += h_combo
	_place_label(score, left, y, col_w, h_score, align)
	y += h_score
	_place_label(acc, left, y, col_w, h_acc, align)

static func _apply_split(
	w: float,
	margin: float,
	stack_top: float,
	title_top: float,
	title_h: float,
	judge: Label,
	combo: Label,
	score: Label,
	acc: Label,
) -> void:
	var col_w := minf(240.0, w - margin * 2.0)
	var left := (w - col_w) * 0.5
	_place_label(judge, left, stack_top, col_w, NineDotConfig.HUD_JUDGE_HEIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	_place_label(
		combo,
		left,
		stack_top + NineDotConfig.HUD_JUDGE_HEIGHT,
		col_w,
		NineDotConfig.HUD_COMBO_HEIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
	)
	# Score / Acc flank under title row
	var side_top := title_top + title_h + 2.0
	var side_w := (w - margin * 2.0 - 8.0) * 0.5
	_place_label(score, margin, side_top, side_w, NineDotConfig.HUD_SCORE_HEIGHT, HORIZONTAL_ALIGNMENT_LEFT)
	_place_label(
		acc,
		w - margin - side_w,
		side_top,
		side_w,
		NineDotConfig.HUD_ACC_HEIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT,
	)

static func _place_label(
	label: Label,
	left: float,
	top: float,
	width: float,
	height: float,
	align: HorizontalAlignment,
) -> void:
	if label == null:
		return
	label.offset_left = left
	label.offset_top = top
	label.offset_right = left + width
	label.offset_bottom = top + height
	label.horizontal_alignment = align

static func metrics_bottom(layout: String) -> float:
	## Y below which Fit-band video may start.
	var top := NineDotConfig.TITLE_FRAME_TOP + NineDotConfig.TITLE_FRAME_HEIGHT + 8.0
	match layout:
		LAYOUT_SPLIT_MAIMAI:
			return top + NineDotConfig.HUD_JUDGE_HEIGHT + NineDotConfig.HUD_COMBO_HEIGHT + 4.0
		_:
			return (
				top
				+ NineDotConfig.HUD_JUDGE_HEIGHT
				+ NineDotConfig.HUD_COMBO_HEIGHT
				+ NineDotConfig.HUD_SCORE_HEIGHT
				+ NineDotConfig.HUD_ACC_HEIGHT
				+ 4.0
			)
