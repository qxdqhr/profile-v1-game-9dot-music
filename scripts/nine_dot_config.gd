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
## Bottom-aligned playfield — leave room for song progress bar.
const GRID_BOTTOM_MARGIN := 32.0
const GRID_SIZE := 304.0

## Play HUD chrome (title frame + judge stack + DIVA-style progress).
const TITLE_FRAME_TOP := 8.0
const TITLE_FRAME_HEIGHT := 36.0
const HUD_JUDGE_HEIGHT := 36.0
const HUD_COMBO_HEIGHT := 28.0
const HUD_SCORE_HEIGHT := 24.0
const HUD_ACC_HEIGHT := 22.0
const PROGRESS_BAR_HEIGHT := 6.0
## Legacy aliases (band / feedback).
const FEEDBACK_TOP := 52.0
const FEEDBACK_HEIGHT := 36.0

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
