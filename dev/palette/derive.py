#!/usr/bin/env python3
"""Derive LMconman's four color themes from Z's colors, and measure them.

    python3 dev/palette/derive.py dev/palette/out/themes.json

Each theme has three backgrounds -- the page, the panels, and the user's own
messages -- and a set of roles. A role starts from one of Z's colors. If that color
meets the role's contrast target against all three backgrounds, it is kept as
given. Otherwise only its HLS lightness moves, hue and saturation kept, until it
does. Contrast is the WCAG 2 ratio.

Targets: text 4.5 in the standard themes and 7 in the high-contrast ones; borders
and indicators 3 and 4.5. The text on the main button must meet the text target.

The neutrals come from the theme of Z's website and from mixes of them. The dark
theme's message background is the lightest mix at which Z's coral still passes as
given (0.44 of the way from the page color to grayblue).

Writes the themes as JSON and prints every role with its worst contrast over the
three backgrounds, marking the values that are Z's as given. The brand is the name
in three tones, set in the title font: "LM" in the brand blue and "con" in
summer-green, both fitted to the text target like any other text, and "man" in the
theme's text color.
"""
import colorsys
import json
import sys


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hexs(c):
    return "#" + "".join(f"{round(max(0, min(1, x)) * 255):02x}" for x in c)


def lum(h):
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in rgb(h)]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def cr(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def mix(a, b, t):
    return hexs(tuple(x + (y - x) * t for x, y in zip(rgb(a), rgb(b))))


def walk(h, ok, lighten):
    """Return h if ok(h); otherwise step its HLS lightness, hue and saturation fixed, until ok.

    The lightness is carried as a float and only the candidate is rounded to hex.
    Re-reading each rounded candidate as the next start lets the hue drift.
    """
    if ok(h):
        return h
    hh, l, s = colorsys.rgb_to_hls(*rgb(h))
    while 0 <= l <= 1:
        l += 0.002 if lighten else -0.002
        c = hexs(colorsys.hls_to_rgb(hh, max(0, min(1, l)), s))
        if ok(c):
            return c
    raise SystemExit(f"cannot fit {h}")


def fit(h, grounds, target, lighten):
    """Keep h if it passes against every ground; otherwise move its lightness until it does."""
    return walk(h, lambda c: min(cr(c, g) for g in grounds) >= target, lighten)


# Z's colors: the five added to the website theme, the website theme's neutrals and
# yellow, and the values Z gave for the brand, the model name and the errors.
Z = dict(
    orange="#F57900", coral="#ff7e7e", lilac="#c98fff", pink="#ff139d", turquoise="#40e0d0",
    yellow="#ffd166", darkblue="#252a34", grayblue="#485266", lightblue="#6c7b99",
    lighterblue="#90a4cc", lesswhite="#eaeaea", lesserwhite="#aeaeae", white="#ffffff",
    darkcoral="#904747", brandblue="#145da6", summergreen="#89d652",
    red_dark="#e00000", red_light="#a80000",
)

TITLE_FONT = {"name": "Source Serif Pro Bold Italic", "file": "SourceSerifPro-BoldIt.ttf"}

# Neumorphic depth, after the recipe of Z's website theme: a raised element has a
# light shadow up-left and a dark shadow down-right, 1 px out with a 1 px blur, on a
# 145-degree gradient fill; a pressed one reverses the gradient and draws the
# shadows inside. Soft shadows are low contrast by nature, so the high-contrast
# themes are drawn flat, with their strong border instead.
DEPTH = {"offset_px": 1, "blur_px": 1}


def theme(dark, hc):
    t = {}
    if dark and not hc:
        t["bg"] = Z["darkblue"]
        t["surface"] = mix(t["bg"], Z["grayblue"], .22)
        t["surface2"] = mix(t["bg"], Z["grayblue"], .44)
        t["border"] = Z["grayblue"]
        t["text"] = Z["lesswhite"]
        muted = Z["lesserwhite"]
    elif not dark and not hc:
        t["bg"] = mix(Z["white"], Z["lighterblue"], .10)
        t["surface"] = Z["white"]
        t["surface2"] = mix(Z["white"], Z["lighterblue"], .22)
        t["border"] = mix(Z["white"], Z["lightblue"], .35)
        t["text"] = Z["darkblue"]
        muted = Z["grayblue"]
    elif dark and hc:
        t["bg"] = mix(Z["darkblue"], "#000000", .75)
        t["surface"] = mix(t["bg"], Z["grayblue"], .18)
        t["surface2"] = mix(t["bg"], Z["grayblue"], .35)
        t["text"] = "#ffffff"
        muted = Z["lesswhite"]
    else:
        t["bg"] = "#ffffff"
        t["surface"] = "#ffffff"
        t["surface2"] = mix(Z["white"], Z["lighterblue"], .14)
        t["text"] = mix(Z["darkblue"], "#000000", .6)
        muted = Z["grayblue"]

    grounds = [t["bg"], t["surface"], t["surface2"]]
    text_t, ui_t = (7.0, 4.5) if hc else (4.5, 3.0)
    lighten = dark

    t["muted"] = fit(muted, grounds, text_t, lighten)
    t["border_strong"] = fit(Z["lightblue"], grounds, ui_t, lighten)
    if hc:
        t["border"] = t["border_strong"]
    t["accent"] = fit(Z["turquoise"], grounds, text_t, lighten)
    t["warning"] = fit(Z["yellow"], grounds, text_t, lighten)
    t["reasoning"] = fit(Z["lilac"], grounds, text_t, lighten)
    t["model_label"] = fit(Z["coral"] if dark else Z["darkcoral"], grounds, text_t, lighten)
    # An error is a red band with white text: the band darkens until white on it
    # meets the text target.
    t["error"] = walk(Z["red_dark"] if dark else Z["red_light"],
                      lambda c: cr("#ffffff", c) >= text_t, False)
    t["on_error"] = "#ffffff"
    t["meter"] = fit(Z["brandblue"], grounds, text_t, lighten)
    t["hover_border"] = fit(Z["pink"], grounds, ui_t, lighten)

    # The main button: its fill must stand out from the page as an indicator, and
    # the best of black and white on it must meet the text target.
    t["action"] = fit(Z["orange"], grounds, ui_t, lighten)
    best_on = lambda a: max(("#ffffff", "#000000"), key=lambda c: cr(c, a))
    t["action"] = walk(t["action"], lambda a: cr(best_on(a), a) >= text_t, lighten)
    t["on_action"] = best_on(t["action"])

    # Depth: the website's dark-theme shadows are black and lightblue at 40% over the
    # page, and its fill runs from grayblue at 15% to #1b1e26 at 40% over the page.
    # The light theme mirrors them; the high-contrast themes are flat.
    t["flat"] = hc
    if dark and not hc:
        t["shadow_dark"] = "#000000"
        t["shadow_light"] = mix(t["bg"], Z["lightblue"], .40)
        t["fill_hi"] = mix(t["bg"], Z["grayblue"], .15)
        t["fill_lo"] = mix(t["bg"], "#1b1e26", .40)
    elif not dark and not hc:
        t["shadow_dark"] = mix(t["bg"], Z["lightblue"], .50)
        t["shadow_light"] = "#ffffff"
        t["fill_hi"] = mix(t["bg"], "#ffffff", .70)
        t["fill_lo"] = mix(t["bg"], Z["lightblue"], .12)
    else:
        t["shadow_dark"] = t["shadow_light"] = t["border_strong"]
        t["fill_hi"] = t["fill_lo"] = t["surface"]

    t["focus"] = t["accent"]
    # A disabled control: the message background, muted text, and the plain border
    # (the strong one in high contrast). Muted text already meets the text target on
    # the message background, so a disabled control stays readable.
    t["disabled_fill"] = t["surface2"]
    t["disabled_text"] = t["muted"]
    t["disabled_border"] = t["border_strong"] if hc else t["border"]
    t["brand_lm"] = fit(Z["brandblue"], grounds, text_t, lighten)
    t["brand_con"] = fit(Z["summergreen"], grounds, text_t, lighten)
    t["brand_man"] = t["text"]
    return t


THEMES = {
    "dark": theme(True, False),
    "light": theme(False, False),
    "dark-hc": theme(True, True),
    "light-hc": theme(False, True),
}

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    with open(sys.argv[1], "w") as f:
        json.dump({"themes": THEMES, "title_font": TITLE_FONT, "depth": DEPTH}, f, indent=1)
    given = {h.lower(): n for n, h in Z.items()}
    for name, t in THEMES.items():
        grounds = [t["bg"], t["surface"], t["surface2"]]
        print(f"\n== {name}")
        for k, v in t.items():
            if k == "flat":
                print(f"  {k:13s} {v}")
                continue
            if k in ("bg", "surface", "surface2", "shadow_dark", "shadow_light", "fill_hi", "fill_lo"):
                note = ""
            elif k == "on_action":
                note = f"{cr(v, t['action']):5.2f} on action"
            elif k == "on_error":
                note = f"{cr(v, t['error']):5.2f} on the band"
            elif k == "disabled_text":
                note = f"{cr(v, t['disabled_fill']):5.2f} on disabled"
            elif k == "error":
                note = f"band vs page {min(cr(v, g) for g in grounds):5.2f}"
            else:
                note = f"worst {min(cr(v, g) for g in grounds):5.2f}"
            mark = f"= Z {given[v.lower()]}" if v.lower() in given else ""
            print(f"  {k:13s} {v}  {note:24s} {mark}")
    print(f"\ntitle font: {TITLE_FONT['name']}")
