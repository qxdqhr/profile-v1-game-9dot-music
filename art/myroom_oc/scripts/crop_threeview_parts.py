"""Crop Mint Ribbon parts from official front / side / back concept sheets.

Produces solid Hunyuan-2mv condition images. Color-key fragments are filled
so each part has a matching three-view silhouette, not confetti.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ART = Path(__file__).resolve().parent.parent
CONCEPT = ART / "concept"
OUT = ART / "parts"

VIEWS = {
    "front": CONCEPT / "oc_q_concept_front.png",
    "left": CONCEPT / "oc_q_concept_side.png",
    "back": CONCEPT / "oc_q_concept_back.png",
}

# Vertical bands on the 864x1152 turnaround (same Y for all three views).
PARTS = {
    "hair": {"y": 8, "h": 560},
    "head": {"y": 40, "h": 520},
    "face": {"y": 200, "h": 340},
    "clothes": {"y": 500, "h": 280},
    "hands": {"y": 655, "h": 120},
    "skirt": {"y": 755, "h": 140},
    "legs": {"y": 840, "h": 160},
    "shoes": {"y": 950, "h": 190},
}

PAD = 36
SQUARE = 512
BG = (184, 184, 184, 255)
PEACH = (245, 219, 204, 255)
CHAR = (52, 56, 64, 255)


def is_bg(r: int, g: int, b: int) -> bool:
    return abs(r - g) < 22 and abs(g - b) < 22 and 150 < r < 240


def is_mint(r: int, g: int, b: int) -> bool:
    return g > r + 4 and g > 78 and g + 14 >= b and not is_bg(r, g, b)


def is_cream(r: int, g: int, b: int) -> bool:
    return r > 200 and g > 185 and b > 155 and abs(r - g) < 36 and (r - b) < 60 and (r - g) < 30


def is_skin(r: int, g: int, b: int) -> bool:
    if is_bg(r, g, b) or is_cream(r, g, b) or is_mint(r, g, b):
        return False
    return r > 200 and 145 < g < 225 and 125 < b < 210 and (r - g) > 12 and (r - b) > 20


def is_amber(r: int, g: int, b: int) -> bool:
    return r > 90 and r > g + 12 and b < 130 and g > 35 and r > b


def is_blush(r: int, g: int, b: int) -> bool:
    return r > 190 and 80 < g < 200 and 80 < b < 200 and r > g + 12


def is_coral(r: int, g: int, b: int) -> bool:
    return r > 150 and r > g + 32 and r > b + 16


def is_charcoal(r: int, g: int, b: int) -> bool:
    return 18 < r < 100 and 18 < g < 100 and 18 < b < 110 and abs(r - g) < 22


def is_outline(r: int, g: int, b: int) -> bool:
    return r < 70 and g < 70 and b < 80


def load(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def content_x_range(im: Image.Image, y0: int, y1: int) -> tuple[int, int]:
    w, _h = im.size
    px = im.load()
    xmin, xmax = w, 0
    for y in range(y0, y1):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 16 or is_bg(r, g, b):
                continue
            xmin = min(xmin, x)
            xmax = max(xmax, x)
    if xmax <= xmin:
        return 0, w - 1
    return max(0, xmin - PAD), min(w - 1, xmax + PAD)


def key_gray_to_alpha(im: Image.Image) -> Image.Image:
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if is_bg(r, g, b):
                px[x, y] = (0, 0, 0, 0)
    return im


def mask_from(im: Image.Image, pred) -> Image.Image:
    px = im.load()
    w, h = im.size
    m = Image.new("L", (w, h), 0)
    mp = m.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            if pred(r, g, b):
                mp[x, y] = 255
    return m


def dilate(mask: Image.Image, k: int = 5) -> Image.Image:
    k = k if k % 2 else k + 1
    return mask.filter(ImageFilter.MaxFilter(k))


def erode(mask: Image.Image, k: int = 5) -> Image.Image:
    k = k if k % 2 else k + 1
    return mask.filter(ImageFilter.MinFilter(k))


def close_mask(mask: Image.Image, k: int = 5) -> Image.Image:
    return erode(dilate(mask, k), k)


def fill_holes(mask: Image.Image) -> Image.Image:
    """Close interior holes in an L mask (255 = keep)."""
    w, h = mask.size
    inv = Image.eval(mask, lambda p: 255 - p)
    filled = inv.copy()
    for xy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if filled.getpixel(xy) > 200:
            ImageDraw.floodfill(filled, xy, 64, thresh=30)
    out = mask.copy()
    op, fp = out.load(), filled.load()
    for y in range(h):
        for x in range(w):
            if fp[x, y] > 200:
                op[x, y] = 255
    return out


def apply_mask(im: Image.Image, mask: Image.Image, fill=None) -> Image.Image:
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    if fill is None:
        out.paste(im, (0, 0), mask)
        return out
    solid = Image.new("RGBA", im.size, fill)
    out.paste(solid, (0, 0), mask)
    return out


def bbox(mask: Image.Image) -> tuple[int, int, int, int] | None:
    box = mask.getbbox()
    return box


def _fit_ellipse(
    w: int, h: int, cx: float, cy: float, rx: float, ry: float
) -> tuple[float, float, float, float]:
    """Keep the Q-skull fully inside the crop so Hunyuan sees a closed sphere."""
    cx = min(max(cx, 16.0), w - 16.0)
    cy = min(max(cy, 16.0), h - 16.0)
    rx = min(max(rx, 12.0), cx - 8.0, w - 8.0 - cx)
    ry = min(max(ry, 12.0), cy - 8.0, h - 8.0 - cy)
    return rx, ry, cx, cy


def _cross(o: tuple[int, int], a: tuple[int, int], b: tuple[int, int]) -> float:
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def _monotone_chain(points: list[tuple[int, int]]) -> list[tuple[int, int]]:
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts
    lower: list[tuple[int, int]] = []
    for p in pts:
        while len(lower) >= 2 and _cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper: list[tuple[int, int]] = []
    for p in reversed(pts):
        while len(upper) >= 2 and _cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def drop_small(mask: Image.Image, min_area: int = 150) -> Image.Image:
    """Drop stray hairs / 1px mint lines that pull a convex hull off-model."""
    w, h = mask.size
    px = mask.load()
    seen = bytearray(w * h)
    out = Image.new("L", (w, h), 0)
    op = out.load()
    for y0 in range(h):
        row = y0 * w
        for x0 in range(w):
            i = row + x0
            if seen[i] or px[x0, y0] < 80:
                continue
            stack = [(x0, y0)]
            seen[i] = 1
            comp: list[tuple[int, int]] = []
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        continue
                    j = ny * w + nx
                    if seen[j] or px[nx, ny] < 80:
                        continue
                    seen[j] = 1
                    stack.append((nx, ny))
            if len(comp) >= min_area:
                for x, y in comp:
                    op[x, y] = 255
    return out


def hull_mask(mask: Image.Image) -> Image.Image:
    """Closed silhouette. Exterior U-openings (bangs) are not holes fill_holes can see."""
    w, h = mask.size
    px = mask.load()
    pts: list[tuple[int, int]] = []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if px[x, y] > 80:
                pts.append((x, y))
    hull = _monotone_chain(pts)
    out = Image.new("L", (w, h), 0)
    if len(hull) >= 3:
        ImageDraw.Draw(out).polygon(hull, fill=255)
    return out


# Same pixel radius for front/left/back so 2mv does not see three different spheres.
_SKULL_RX: float | None = None


def peach_head(crop: Image.Image, view: str) -> Image.Image:
    """Q-skull on a canonical canvas. Crop size used to differ per view and flattened the head."""
    global _SKULL_RX
    s = 480
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    cx = cy = s * 0.5
    rx = _SKULL_RX if _SKULL_RX else s * 0.36
    if view == "front":
        _SKULL_RX = rx
        ry = rx * 1.02
        draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=PEACH)
        ear_rx, ear_ry = rx * 0.18, ry * 0.22
        draw.ellipse(
            [cx - rx - ear_rx * 0.4, cy - ear_ry * 0.05, cx - rx + ear_rx * 1.15, cy + ear_ry * 1.45],
            fill=PEACH,
        )
        draw.ellipse(
            [cx + rx - ear_rx * 1.15, cy - ear_ry * 0.05, cx + rx + ear_rx * 0.4, cy + ear_ry * 1.45],
            fill=PEACH,
        )
    elif view == "left":
        ry = rx * 1.02
        draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=PEACH)
        nx = cx - rx
        draw.ellipse([nx - rx * 0.16, cy - ry * 0.02, nx + rx * 0.28, cy + ry * 0.32], fill=PEACH)
        draw.ellipse([cx - rx * 0.35, cy + ry * 0.42, cx + rx * 0.22, cy + ry * 0.98], fill=PEACH)
        draw.ellipse([cx + rx * 0.18, cy - ry * 0.12, cx + rx * 0.62, cy + ry * 0.38], fill=PEACH)
    else:
        ry = rx * 0.98
        draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=PEACH)
        ear_rx, ear_ry = rx * 0.16, ry * 0.22
        ey = cy + ry * 0.12
        draw.ellipse([cx - rx - ear_rx * 0.15, ey - ear_ry, cx - rx + ear_rx * 1.35, ey + ear_ry], fill=PEACH)
        draw.ellipse([cx + rx - ear_rx * 1.35, ey - ear_ry, cx + rx + ear_rx * 0.15, ey + ear_ry], fill=PEACH)
    return out


def make_hair(crop: Image.Image, view: str | None = None) -> Image.Image:
    """Mint skull-cap under bangs + original hair. No face pixels, no hard crops."""
    mint = mask_from(crop, is_mint)
    outline = mask_from(crop, is_outline)
    near = dilate(mint, 7)
    outline = Image.composite(outline, Image.new("L", crop.size, 0), near)
    face = dilate(
        mask_from(
            crop,
            lambda r, g, b: is_skin(r, g, b) or is_amber(r, g, b) or is_blush(r, g, b),
        ),
        5,
    )
    hair_px = ImageChops_subtract(close_mask(ImageChops_add(mint, outline), 5), face)
    hair_px = drop_small(hair_px, min_area=150)
    fat = dilate(hair_px, 9)
    box = bbox(fat)
    cap_m = fat.copy()
    if box:
        x0, y0, x1, y1 = box
        bw, bh = max(1, x1 - x0), max(1, y1 - y0)
        if view == "left":
            cx = x0 + bw * 0.40
            cy = y0 + bh * 0.50
            rx, ry = bw * 0.33, bh * 0.42
        else:
            cx = (x0 + x1) / 2
            cy = y0 + bh * 0.52
            rx, ry = bw * 0.30, bh * 0.44
        ImageDraw.Draw(cap_m).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    cap = apply_mask(crop, cap_m, fill=(126, 196, 186, 255))
    return Image.alpha_composite(cap, apply_mask(crop, hair_px))


def ImageChops_add(a: Image.Image, b: Image.Image) -> Image.Image:
    out = a.copy()
    op, bp = out.load(), b.load()
    w, h = a.size
    for y in range(h):
        for x in range(w):
            if bp[x, y] > op[x, y]:
                op[x, y] = bp[x, y]
    return out


def ImageChops_subtract(a: Image.Image, b: Image.Image) -> Image.Image:
    out = a.copy()
    op, bp = out.load(), b.load()
    w, h = a.size
    for y in range(h):
        for x in range(w):
            if bp[x, y] > 80:
                op[x, y] = 0
    return out


def make_face(crop: Image.Image, view: str) -> Image.Image:
    """Drawn Q-face. Crop pixels were crumbs that Hunyuan carved into pits."""
    base = peach_head(crop, view)
    if view == "back":
        return base
    draw = ImageDraw.Draw(base)
    s = base.size[0]
    cx = cy = s * 0.5
    rx = s * 0.36
    amber = (214, 154, 64, 255)
    highlight = (255, 236, 210, 255)
    blush = (242, 170, 160, 255)
    lip = (220, 120, 120, 255)
    if view == "front":
        for ex in (cx - rx * 0.42, cx + rx * 0.42):
            ey = cy + rx * 0.04
            ew, eh = rx * 0.32, rx * 0.40
            draw.ellipse([ex - ew, ey - eh, ex + ew, ey + eh], fill=amber)
            draw.ellipse(
                [ex - ew * 0.42, ey - eh * 0.62, ex + ew * 0.12, ey - eh * 0.08],
                fill=highlight,
            )
        for bx in (cx - rx * 0.58, cx + rx * 0.58):
            draw.ellipse(
                [bx - rx * 0.16, cy + rx * 0.36, bx + rx * 0.16, cy + rx * 0.56],
                fill=blush,
            )
        draw.ellipse(
            [cx - rx * 0.09, cy + rx * 0.50, cx + rx * 0.09, cy + rx * 0.60],
            fill=lip,
        )
    else:
        ex = cx - rx * 0.32
        ey = cy - rx * 0.02
        draw.ellipse([ex - rx * 0.16, ey - rx * 0.26, ex + rx * 0.22, ey + rx * 0.20], fill=amber)
        draw.ellipse(
            [ex - rx * 0.06, ey - rx * 0.22, ex + rx * 0.10, ey - rx * 0.02],
            fill=highlight,
        )
        draw.ellipse(
            [cx - rx * 0.48, cy + rx * 0.30, cx - rx * 0.10, cy + rx * 0.48],
            fill=blush,
        )
        draw.ellipse(
            [cx - rx * 0.88, cy + rx * 0.18, cx - rx * 0.64, cy + rx * 0.30],
            fill=lip,
        )
    return base


def make_clothes(crop: Image.Image) -> Image.Image:
    body = mask_from(crop, lambda r, g, b: is_cream(r, g, b) or is_coral(r, g, b))
    outline = mask_from(crop, is_outline)
    near = dilate(body, 5)
    outline = Image.composite(outline, Image.new("L", crop.size, 0), near)
    keep = close_mask(ImageChops_add(body, outline), 5)
    drop = dilate(mask_from(crop, lambda r, g, b: is_skin(r, g, b) or is_mint(r, g, b) or is_charcoal(r, g, b)), 5)
    keep = ImageChops_subtract(keep, drop)
    keep = fill_holes(keep)
    return apply_mask(crop, keep)


def make_hands(crop: Image.Image, view: str) -> Image.Image:
    """Q dumpling: a sphere plus thumb. Flat ellipses became cookie-cutter plaques."""
    s = 400
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    cx, cy = s * 0.5, s * 0.5
    r = s * 0.28
    hi = (255, 236, 224, 255)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=PEACH)
    draw.ellipse([cx - r * 0.45, cy - r * 0.55, cx + r * 0.15, cy - r * 0.05], fill=hi)
    if view == "front":
        draw.ellipse([cx + r * 0.35, cy - r * 0.08, cx + r * 1.12, cy + r * 0.55], fill=PEACH)
    elif view == "left":
        draw.ellipse([cx - r * 1.12, cy - r * 0.08, cx - r * 0.35, cy + r * 0.55], fill=PEACH)
    return out


def make_skirt(crop: Image.Image, view: str) -> Image.Image:
    """Puffy Q skirt on a canonical canvas. A thin side trapezoid becomes a plaque."""
    s = 480
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    cx, cy = s * 0.5, s * 0.52
    hh = s * 0.30
    top, bot = cy - hh / 2, cy + hh / 2
    if view in ("front", "back"):
        wt, wb = s * 0.44, s * 0.74
        draw.polygon(
            [(cx - wt / 2, top), (cx + wt / 2, top), (cx + wb / 2, bot), (cx - wb / 2, bot)],
            fill=CHAR,
        )
    else:
        dd = hh * 0.92
        draw.rounded_rectangle(
            [cx - dd / 2, top, cx + dd / 2, bot],
            radius=int(hh * 0.28),
            fill=CHAR,
        )
    return out


def make_legs(crop: Image.Image, view: str) -> Image.Image:
    """Capsules on a canonical canvas so front/side share the same cylinder thickness."""
    s = 480
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    sock = (126, 196, 186, 255)
    top, bot = s * 0.16, s * 0.84
    rad = s * 0.12

    def capsule(cx: float) -> None:
        draw.ellipse([cx - rad, top, cx + rad, top + 2 * rad], fill=PEACH)
        draw.rectangle([cx - rad, top + rad, cx + rad, bot - rad], fill=PEACH)
        sy = top + (bot - top) * 0.60
        draw.rectangle([cx - rad, sy, cx + rad, bot - rad], fill=sock)
        draw.ellipse([cx - rad, bot - 2 * rad, cx + rad, bot], fill=sock)

    if view == "left":
        capsule(s * 0.5)
    else:
        gap = s * 0.10
        capsule(s * 0.5 - rad - gap / 2)
        capsule(s * 0.5 + rad + gap / 2)
    return out


def make_shoes(crop: Image.Image) -> Image.Image:
    char = mask_from(crop, is_charcoal)
    coral = mask_from(crop, is_coral)
    mint = mask_from(crop, is_mint)
    char_box = bbox(char)
    sole = Image.new("L", crop.size, 0)
    if char_box:
        _x0, y0, _x1, y1 = char_box
        cut = y0 + int((y1 - y0) * 0.55)
        sp, mp = sole.load(), mint.load()
        w, h = crop.size
        for y in range(cut, h):
            for x in range(w):
                if mp[x, y] > 80:
                    sp[x, y] = 255
        near = dilate(char, 7)
        sole = Image.composite(sole, Image.new("L", crop.size, 0), near)
    keep = ImageChops_add(ImageChops_add(char, coral), sole)
    keep = fill_holes(close_mask(keep, 5))
    return apply_mask(crop, keep)


MAKERS = {
    "hair": make_hair,
    "head": lambda c, v: peach_head(c, v),
    "face": make_face,
    "clothes": lambda c, _v: make_clothes(c),
    "hands": make_hands,
    "skirt": make_skirt,
    "legs": make_legs,
    "shoes": lambda c, _v: make_shoes(c),
}


def pad_square_consistent(images: dict[str, Image.Image], size: int = SQUARE) -> dict[str, Image.Image]:
    """Same world-scale for front/left/back so Hunyuan-2mv can fuse volume."""
    cropped: dict[str, Image.Image] = {}
    span = 1
    for name, im in images.items():
        im = im.convert("RGBA")
        box = im.getbbox()
        c = im.crop(box) if box else im
        cropped[name] = c
        span = max(span, max(c.size))
    scale = (size * 0.86) / span
    out: dict[str, Image.Image] = {}
    for name, c in cropped.items():
        nw, nh = max(1, int(c.size[0] * scale)), max(1, int(c.size[1] * scale))
        c = c.resize((nw, nh), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.paste(c, ((size - nw) // 2, (size - nh) // 2), c)
        bg = Image.new("RGBA", (size, size), BG)
        bg.alpha_composite(canvas)
        out[name] = bg.convert("RGB")
    return out


def contact_sheet(images: dict[str, Image.Image], path: Path) -> None:
    w = SQUARE * 3 + 16
    h = SQUARE + 40
    sheet = Image.new("RGB", (w, h), (32, 32, 32))
    draw = ImageDraw.Draw(sheet)
    x = 8
    for name in ("front", "left", "back"):
        sheet.paste(images[name], (x, 28))
        draw.text((x + 8, 6), name, fill=(240, 240, 240))
        x += SQUARE + 4
    sheet.save(path)


def main() -> None:
    global _SKULL_RX
    _SKULL_RX = None
    views = {k: load(p) for k, p in VIEWS.items()}
    for name, spec in PARTS.items():
        dest = OUT / name
        dest.mkdir(parents=True, exist_ok=True)
        raws: dict[str, Image.Image] = {}
        y0, band_h = spec["y"], spec["h"]
        y1 = y0 + band_h
        maker = MAKERS[name]
        for view, im in views.items():
            x0, x1 = content_x_range(im, y0, y1)
            crop = im.crop((x0, y0, x1 + 1, y1)).copy()
            crop = key_gray_to_alpha(crop)
            part = maker(crop, view)
            part.save(dest / f"{view}_raw.png")
            raws[view] = part
        squares = pad_square_consistent(raws)
        for view, sq in squares.items():
            sq.save(dest / f"{view}.png")
        contact_sheet(squares, dest / "threeview.png")
        print("wrote", name, dest, flush=True)
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
