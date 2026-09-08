extends RefCounted
class_name NineDotConfig
## PRD v1.2 constants for 9-Dot Game.

const DISPLAY_NAME := "9-Dot Game"
const VIEW_W := 360.0
const VIEW_H := 640.0

# Tap windows
const JUDGE_PERFECT_MS := 50
const JUDGE_GREAT_MS := 100
const JUDGE_GOOD_MS := 150

# Slide windows (wider)
const SLIDE_PERFECT_MS := 80
const SLIDE_GREAT_MS := 140
const SLIDE_GOOD_MS := 220

const APPROACH_MS := 700
const SLIDE_BAND_FRAC := 0.35
const SLIDE_COMPLETE_FRAC := 0.55
const SLIDE_OFF_BAND_GRACE_MS := 80

const NODE_HIT_RADIUS_FRAC := 0.50
const GRID_MARGIN := 28.0
const GRID_TOP := 210.0
const GRID_SIZE := 304.0

const HAPTIC_ARM_MS := 25
const HAPTIC_COMPLETE_MS := 40
const HAPTIC_MISS_MS := 18
const HAPTIC_ARM_AMP := 0.35
const HAPTIC_COMPLETE_AMP := 0.75
const HAPTIC_MISS_AMP := 0.25

const FEEDBACK_HOLD_MS := 420
const EMPTY_FEEDBACK_COOLDOWN_MS := 120

const COLOR_TAP := Color(0.95, 0.28, 0.55, 1.0)
const COLOR_TAP_FILL := Color(0.95, 0.28, 0.55, 0.45)
const COLOR_SLIDE := Color(1.0, 0.82, 0.22, 1.0)
const COLOR_SLIDE_SOFT := Color(1.0, 0.82, 0.22, 0.55)

enum Grade { PERFECT, GREAT, GOOD, MISS }
