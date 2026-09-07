extends RefCounted
class_name NineDotConfig
## PRD v1.0 constants for 9-Dot Game.

const DISPLAY_NAME := "9-Dot Game"
const VIEW_W := 360.0
const VIEW_H := 640.0

const JUDGE_PERFECT_MS := 50
const JUDGE_GREAT_MS := 100
const JUDGE_GOOD_MS := 150

const APPROACH_MS := 500
const SLIDE_BAND_FRAC := 0.35
const SLIDE_COMPLETE_FRAC := 0.70

const NODE_HIT_RADIUS_FRAC := 0.38
const GRID_MARGIN := 28.0
const GRID_TOP := 210.0
const GRID_SIZE := 304.0

enum Grade { PERFECT, GREAT, GOOD, MISS }
