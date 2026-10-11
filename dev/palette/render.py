#!/usr/bin/env python3
"""Render AIconman's themes to images, to look at rather than read.

    python3 dev/palette/render.py dev/palette/out/themes.json dev/palette/out

Reads the JSON that derive.py writes, and writes two images into the folder:

- themes.png: the four themes side by side, each with a sidebar, a chat with a
  model name, reasoning, a link, an error and a warning, the context meter, an input
  with its focus ring, the main button, a button with its hover border, and
  labeled swatches;
- brand.png: the brand, the name in two tones set in the title font, on all four
  backgrounds, at the size of the sidebar title and at a large size;
- depth.png: a raised card, a raised button, a pressed button and an inset input in
  each theme, drawn at twice the size, as a high-density screen shows 1 px shadows.

Needs Pillow, the DejaVu fonts, and the title font named in the JSON.
"""
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

FONT_DIRS = ["/usr/share/fonts/TTF", "/usr/share/fonts/truetype/dejavu",
             os.path.expanduser("~/.fonts"), os.path.expanduser("~/.local/share/fonts")]
TITLE = None


def font(name, size):
    for d in FONT_DIRS:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    raise SystemExit(f"font {name} not found in {FONT_DIRS}")


def R(s): return font("DejaVuSans.ttf", s)
def B(s): return font("DejaVuSans-Bold.ttf", s)
def M(s): return font("DejaVuSansMono.ttf", s)


def brand(img, xy, size, t):
    """The name in two tones: "AI" in brand_ai, "conman" in brand_rest, in the title font."""
    f = font(TITLE["file"], size)
    d = ImageDraw.Draw(img)
    d.text(xy, "AI", font=f, fill=t["brand_ai"])
    d.text((xy[0] + d.textlength("AI", font=f), xy[1]), "conman", font=f, fill=t["brand_rest"])


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shape(size, box, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m


def shifted(m, dx, dy):
    return ImageChops.offset(m, dx, dy)


def gradient(size, box, c1, c2, angle, a, b):
    """A linear gradient over box, c1 until fraction a along the angle, c2 from fraction b."""
    import math
    x0, y0, x1, y1 = box
    w, h = x1 - x0 + 1, y1 - y0 + 1
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    span = abs(w * ca) + abs(h * sa)
    g = Image.new("RGB", (w, h))
    p1, p2 = rgb(c1), rgb(c2)
    px = []
    for y in range(h):
        for x in range(w):
            f = ((x - w / 2) * ca + (y - h / 2) * sa) / span + 0.5
            f = 0 if f <= a else 1 if f >= b else (f - a) / (b - a)
            px.append(tuple(round(u + (v - u) * f) for u, v in zip(p1, p2)))
    g.putdata(px)
    layer = Image.new("RGB", size)
    layer.paste(g, (x0, y0))
    return layer


def paint(img, color, mask):
    img.paste(Image.new("RGB", img.size, color), (0, 0), mask)


def element(img, box, t, depth, s, kind):
    """Draw a raised, pressed or inset element; flat themes get a strong border instead."""
    r, o, bl = 8 * s, depth["offset_px"] * s, depth["blur_px"] * s
    m = shape(img.size, box, r)
    if t["flat"]:
        fill = t["surface2"] if kind == "pressed" else t["surface"]
        ImageDraw.Draw(img).rounded_rectangle(box, radius=r, fill=fill, outline=t["border_strong"], width=s)
        return
    if kind == "raised":
        paint(img, t["shadow_light"], shifted(m, -o, -o).filter(ImageFilter.GaussianBlur(bl)))
        paint(img, t["shadow_dark"], shifted(m, o, o).filter(ImageFilter.GaussianBlur(bl)))
        img.paste(gradient(img.size, box, t["fill_hi"], t["fill_lo"], 145, .15, .80), (0, 0), m)
        return
    if kind == "pressed":
        paint(img, t["shadow_light"], shifted(m, o, o).filter(ImageFilter.GaussianBlur(bl * .75)))
        paint(img, t["shadow_dark"], shifted(m, -o, -o).filter(ImageFilter.GaussianBlur(bl * .75)))
        img.paste(gradient(img.size, box, t["fill_lo"], t["fill_hi"], 150, .10, .80), (0, 0), m)
    else:
        img.paste(Image.new("RGB", img.size, t["surface"]), (0, 0), m)
    i = max(1, o // 2)
    for color, d in ((t["shadow_dark"], i), (t["shadow_light"], -i)):
        inner = ImageChops.subtract(m, shifted(m, d, d)).filter(ImageFilter.GaussianBlur(max(1, bl // 2)))
        paint(img, color, ImageChops.multiply(inner, m))


def depth_png(T, depth, out):
    s = 2
    cw, ch = 300 * s, 230 * s
    img = Image.new("RGB", (cw * 2 + 30 * s, ch * 2 + 30 * s), "#808080")
    for i, (name, t) in enumerate(T.items()):
        ox, oy = 10 * s + (i % 2) * (cw + 10 * s), 10 * s + (i // 2) * (ch + 10 * s)
        ImageDraw.Draw(img).rectangle([ox, oy, ox + cw, oy + ch], fill=t["bg"])
        ImageDraw.Draw(img).text((ox + 14 * s, oy + 8 * s), name, font=R(13 * s), fill=t["muted"])
        card = (ox + 14 * s, oy + 32 * s, ox + cw - 14 * s, oy + 108 * s)
        element(img, card, t, depth, s, "raised")
        d = ImageDraw.Draw(img)
        d.text((card[0] + 14 * s, card[1] + 12 * s), "Raised card", font=B(14 * s), fill=t["text"])
        d.text((card[0] + 14 * s, card[1] + 38 * s), "A conversation, a connection, a setting.", font=R(12 * s), fill=t["muted"])
        for k, (label, kind) in enumerate((("Save", "raised"), ("Saved", "pressed"))):
            bx = ox + 14 * s + k * 130 * s
            box = (bx, oy + 126 * s, bx + 110 * s, oy + 162 * s)
            element(img, box, t, depth, s, kind)
            ImageDraw.Draw(img).text((bx + 30 * s, oy + 134 * s), label, font=B(14 * s), fill=t["text"])
        box = (ox + 14 * s, oy + 180 * s, ox + cw - 14 * s, oy + 214 * s)
        element(img, box, t, depth, s, "inset")
        ImageDraw.Draw(img).text((box[0] + 12 * s, box[1] + 9 * s), "Message...", font=R(13 * s), fill=t["muted"])
    img.save(out)


def themes_png(T, out):
    W, H = 820, 560
    img = Image.new("RGB", (W * 2 + 30, H * 2 + 30), "#808080")
    for i, (name, t) in enumerate(T.items()):
        ox, oy = 10 + (i % 2) * (W + 10), 10 + (i // 2) * (H + 10)
        d = ImageDraw.Draw(img)
        d.rectangle([ox, oy, ox + W, oy + H], fill=t["bg"])
        d.rectangle([ox, oy, ox + 200, oy + H], fill=t["surface"])
        d.line([ox + 200, oy, ox + 200, oy + H], fill=t["border"], width=1)
        brand(img, (ox + 16, oy + 10), 24, t)
        d = ImageDraw.Draw(img)
        d.text((ox + 16, oy + 42), name, font=R(13), fill=t["muted"])
        d.rectangle([ox + 8, oy + 72, ox + 192, oy + 100], fill=t["surface2"])
        d.rectangle([ox + 8, oy + 72, ox + 11, oy + 100], fill=t["accent"])
        d.text((ox + 20, oy + 78), "Trip plan", font=R(14), fill=t["text"])
        d.text((ox + 20, oy + 112), "Recipe", font=R(14), fill=t["text"])
        d.text((ox + 20, oy + 140), "Yesterday", font=R(12), fill=t["muted"])
        d.text((ox + 20, oy + 160), "Notes", font=R(14), fill=t["text"])
        x0 = ox + 220
        d.text((x0, oy + 16), "qwen3-4b (pi)  v", font=R(14), fill=t["text"])
        d.text((x0 + 380, oy + 16), "~1,240 / 4,096", font=M(14), fill=t["meter"])
        d.line([ox + 200, oy + 44, ox + W, oy + 44], fill=t["border"], width=1)
        d.rounded_rectangle([x0 + 200, oy + 60, ox + W - 20, oy + 100], radius=10, fill=t["surface2"])
        d.text((x0 + 214, oy + 71), "How long is the trip?", font=R(15), fill=t["text"])
        d.text((x0, oy + 116), "qwen3-4b", font=B(13), fill=t["model_label"])
        d.text((x0, oy + 136), "> Reasoning", font=R(13), fill=t["reasoning"])
        d.text((x0, oy + 160), "The trip takes 95 minutes, arriving at 15:55.", font=R(15), fill=t["text"])
        d.text((x0, oy + 184), "Times come from", font=R(15), fill=t["text"])
        lx = x0 + d.textlength("Times come from ", font=R(15))
        d.text((lx, oy + 184), "the schedule", font=R(15), fill=t["accent"])
        d.line([lx, oy + 203, lx + d.textlength("the schedule", font=R(15)), oy + 203], fill=t["accent"], width=1)
        d.text((x0, oy + 214), "Muted: generated in 12 s", font=R(13), fill=t["muted"])
        d.rounded_rectangle([x0, oy + 240, x0 + 250, oy + 266], radius=5, fill=t["error"])
        d.text((x0 + 10, oy + 244), "Server unreachable. Retry", font=R(15), fill=t["on_error"])
        d.text((x0, oy + 270), "Microphone needs HTTPS.", font=R(15), fill=t["warning"])
        d.rounded_rectangle([x0 + 300, oy + 252, x0 + 470, oy + 286], radius=7, fill=t["surface"], outline=t["hover_border"], width=2)
        d.text((x0 + 318, oy + 260), "Hovered button", font=R(14), fill=t["text"])
        d.rectangle([ox + 201, oy + 300, ox + W, oy + 372], fill=t["surface"])
        d.rounded_rectangle([x0 - 3, oy + 313, ox + W - 123, oy + 359], radius=9, outline=t["focus"], width=2)
        d.rounded_rectangle([x0, oy + 316, ox + W - 126, oy + 356], radius=7, fill=t["bg"], outline=t["border_strong"], width=1)
        d.text((x0 + 12, oy + 327), "Message...", font=R(15), fill=t["muted"])
        d.rounded_rectangle([ox + W - 110, oy + 316, ox + W - 20, oy + 356], radius=7, fill=t["action"])
        d.text((ox + W - 88, oy + 326), "Send", font=B(15), fill=t["on_action"])
        roles = ["text", "muted", "border_strong", "accent", "action",
                 "error", "warning", "reasoning", "model_label", "meter", "hover_border"]
        for j, r in enumerate(roles):
            sx, sy = ox + 16 + (j % 6) * 134, oy + 396 + (j // 6) * 78
            d.rectangle([sx, sy, sx + 30, sy + 30], fill=t[r], outline=t["border_strong"])
            d.text((sx + 36, sy + 0), r, font=R(12), fill=t["text"])
            d.text((sx + 36, sy + 16), t[r].lower(), font=M(11), fill=t["muted"])
    img.save(out)


def brand_png(T, out):
    cw, ch = 520, 110
    img = Image.new("RGB", (cw * 2 + 170, ch * len(T) + 20), "#808080")
    for i, (name, t) in enumerate(T.items()):
        y = 10 + i * ch
        ImageDraw.Draw(img).text((10, y + 40), name, fill="#ffffff", font=R(18))
        for j, size in enumerate((24, 56)):
            x = 160 + j * cw
            ImageDraw.Draw(img).rectangle([x, y, x + cw - 10, y + ch - 10], fill=t["bg"])
            brand(img, (x + 24, y + (40 if size == 24 else 14)), size, t)
    img.save(out)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    data = json.load(open(sys.argv[1]))
    TITLE = data["title_font"]
    os.makedirs(sys.argv[2], exist_ok=True)
    themes_png(data["themes"], os.path.join(sys.argv[2], "themes.png"))
    brand_png(data["themes"], os.path.join(sys.argv[2], "brand.png"))
    depth_png(data["themes"], data["depth"], os.path.join(sys.argv[2], "depth.png"))
    print("wrote themes.png, brand.png and depth.png into", sys.argv[2])
