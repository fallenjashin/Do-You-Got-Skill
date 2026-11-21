"""Builds the Steam store capsule images from the neon sign + the game's own look.

    python3 tools/marketing/make_capsules.py <outdir>

Sizes (Steamworks "Store Graphical Assets", checked Nov 2026): header 920x430, small 462x174,
main 1232x706, vertical 748x896, library capsule 600x900. Steam's rules: the image holds the logo
and artwork only (no review quotes, "new!", prices, etc.). The logo is centred, because Steam puts a
"demo" banner in the top-left corner of the header and small capsules.
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SIGN = os.path.join(HERE, "..", "..", "marketing", "neon_sign_transparent_1920x1080.png")
OUT = sys.argv[1] if len(sys.argv) > 1 else "capsules"
os.makedirs(OUT, exist_ok=True)

# the game's palette (scripts/game.gd)
SPIKE, GOAL, SHOT, TEXT, INK = (255, 77, 109), (46, 213, 115), (255, 179, 71), (232, 236, 255), (26, 31, 51)
CYAN, PURPLE = (80, 220, 255), (179, 136, 255)

sign_full = Image.open(SIGN).convert("RGBA")
# the visible sign starts at x=94 in the 1920x1080 file; these boxes are measured from that
OX = sign_full.split()[3].getbbox()[0]
SIGN_FRAME = sign_full.crop((OX + 190, 185, OX + 1540, 840))   # neon frame + hanging wires + text
SIGN_TEXT = sign_full.crop((OX + 470, 340, OX + 1300, 760))    # just "Do You Got Skill", for the small capsule


def drop_shadow(img, floor=25, gain=3):
    """The sign file has a faint dark halo around the lettering. Cut it, keep the neon glow."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            v = max(r, g, b) * a / 255
            px[x, y] = (r, g, b, int(max(0, min(255, (v - floor) * gain))))
    return img


SIGN_TEXT = drop_shadow(SIGN_TEXT)


def background(w, h, seed=7):
    """Deep space: vertical gradient, soft magenta/cyan glows, stars."""
    rnd = random.Random(seed)
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = (int(10 + 14 * t), int(9 + 6 * t), int(26 + 22 * t))
        for x in range(w):
            px[x, y] = c
    glow = Image.new("RGB", (w, h), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-w * 0.2, h * 0.05, w * 0.55, h * 0.95), fill=(70, 20, 90))
    gd.ellipse((w * 0.45, h * 0.15, w * 1.2, h * 1.1), fill=(10, 50, 85))
    glow = glow.filter(ImageFilter.GaussianBlur(max(w, h) * 0.18))
    img = ImageChops.add(img, glow.point(lambda v: int(v * 0.8)))
    d = ImageDraw.Draw(img)
    for _ in range(int(w * h / 2600)):
        x, y = rnd.randrange(w), rnd.randrange(h)
        b = rnd.choice([90, 120, 160, 210])
        r = rnd.choice([0, 0, 0, 1])
        d.ellipse((x - r, y - r, x + r, y + r), fill=(b, b, min(255, b + 30)))
    return img


def neon(layer, draw_fn, color, width, glow=1.0):
    """Draw with draw_fn onto a transparent layer in a glowing neon style."""
    base = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(base), color, width)
    halo = base.filter(ImageFilter.GaussianBlur(width * 2.2))
    halo2 = base.filter(ImageFilter.GaussianBlur(width * 5))
    for h, k in ((halo2, 0.55 * glow), (halo, 0.9 * glow)):
        a = h.split()[3].point(lambda v: min(255, int(v * k)))
        h.putalpha(a)
        layer.alpha_composite(h)
    layer.alpha_composite(base)


def art(w, h, scale, floor_y, x0, x1, ball_x, goal_x, arc_h):
    """The game in one picture: ball, recoil burst, dashed arc, spikes, floor, green goal."""
    S = 3                                                  # supersample, then shrink for clean edges
    W, H = w * S, h * S
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    u = scale * S                                          # one "game pixel"
    fy = floor_y * S
    # floor and spikes
    neon(layer, lambda d, c, wd: d.line((x0 * S, fy, x1 * S, fy), fill=c, width=int(wd)), CYAN, 2.2 * u)
    spikes_from, spikes_to = (ball_x + 70 * scale) * S, (goal_x - 60 * scale) * S
    step = 13 * u
    sx = spikes_from
    sp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sp)
    while sx + step < spikes_to:
        sd.polygon([(sx, fy), (sx + step / 2, fy - 16 * u), (sx + step, fy)], fill=SPIKE + (255,))
        sx += step
    layer.alpha_composite(sp.filter(ImageFilter.GaussianBlur(5 * u)))
    layer.alpha_composite(sp)
    # dashed arc from ball to goal
    bx, by = ball_x * S, fy - 12 * u
    gx, gy = goal_x * S, fy - 14 * u
    pts = []
    for i in range(0, 101):
        t = i / 100
        pts.append((bx + (gx - bx) * t, by + (gy - by) * t - 4 * arc_h * S * t * (1 - t)))
    ad = ImageDraw.Draw(layer)
    for i in range(0, 100, 4):
        ad.line([pts[i], pts[i + 2]], fill=(255, 179, 71, 190), width=int(2.4 * u))
    # goal
    gc = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    neon(gc, lambda d, c, wd: d.ellipse((gx - 14 * u, gy - 14 * u, gx + 14 * u, gy + 14 * u), fill=c + (255,)), GOAL, 4 * u, 1.3)
    layer.alpha_composite(gc)
    # recoil burst (orange) behind the ball
    rnd = random.Random(3)
    for _ in range(26):
        a = math.pi + rnd.uniform(-0.8, 0.8) - 0.35
        r = rnd.uniform(22, 70) * u
        px_, py_ = bx + math.cos(a) * r, by + math.sin(a) * r * 0.9
        rr = rnd.uniform(1.2, 3.2) * u
        ad.ellipse((px_ - rr, py_ - rr, px_ + rr, py_ + rr), fill=(255, 179, 71, rnd.randint(110, 230)))
    # the ball with the game's eyes (looking toward the goal) and two orange ammo dots
    bl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    neon(bl, lambda d, c, wd: d.ellipse((bx - 11 * u, by - 11 * u, bx + 11 * u, by + 11 * u), fill=c + (255,)), (150, 170, 255), 5 * u, 0.9)
    layer.alpha_composite(bl)
    ad.ellipse((bx - 11 * u, by - 11 * u, bx + 11 * u, by + 11 * u), fill=TEXT + (255,))
    for sgn in (-1, 1):
        ex, ey = bx + sgn * 3.6 * u + 1.9 * u, by - 1.7 * u
        ad.ellipse((ex - 1.9 * u, ey - 1.9 * u, ex + 1.9 * u, ey + 1.9 * u), fill=INK + (255,))
    for sgn in (-1, 1):
        ox, oy = bx + sgn * 5 * u, by - 20 * u
        ad.ellipse((ox - 2.6 * u, oy - 2.6 * u, ox + 2.6 * u, oy + 2.6 * u), fill=SHOT + (255,))
    return layer.resize((w, h), Image.LANCZOS)


def fit(img, max_w, max_h):
    r = min(max_w / img.width, max_h / img.height)
    return img.resize((int(img.width * r), int(img.height * r)), Image.LANCZOS)


def compose(name, w, h, logo, logo_box, art_args=None, seed=7):
    canvas = background(w, h, seed).convert("RGBA")
    if art_args:
        canvas.alpha_composite(art(w, h, **art_args))
    lg = fit(logo, *logo_box[2:])
    cx, cy = logo_box[0], logo_box[1]
    canvas.alpha_composite(lg, (int(cx - lg.width / 2), int(cy - lg.height / 2)))
    path = os.path.join(OUT, name)
    canvas.convert("RGB").save(path, optimize=True)
    print(path, canvas.size)


# header 920x430: logo is the star, the game scene runs along the bottom
compose("header_capsule_920x430.png", 920, 430, SIGN_FRAME, (460, 172, 700, 300),
        dict(scale=1.05, floor_y=398, x0=24, x1=896, ball_x=96, goal_x=824, arc_h=55))
# small capsule 462x174: just the lettering, as large as it goes, with the ball and goal as accents
compose("small_capsule_462x174.png", 462, 174, SIGN_TEXT, (243, 87, 440, 164))
# main capsule 1232x706
compose("main_capsule_1232x706.png", 1232, 706, SIGN_FRAME, (616, 290, 960, 500),
        dict(scale=1.55, floor_y=650, x0=30, x1=1202, ball_x=130, goal_x=1100, arc_h=75))
# vertical capsule 748x896 and library capsule 600x900: logo on top, game scene below
compose("vertical_capsule_748x896.png", 748, 896, SIGN_FRAME, (374, 330, 700, 450),
        dict(scale=1.45, floor_y=800, x0=24, x1=724, ball_x=100, goal_x=648, arc_h=220))
compose("library_capsule_600x900.png", 600, 900, SIGN_FRAME, (300, 330, 560, 450),
        dict(scale=1.2, floor_y=810, x0=20, x1=580, ball_x=82, goal_x=520, arc_h=200))
# logo on its own (transparent), for the library "logo" slot and the press kit
lg = SIGN_FRAME.copy()
lg.save(os.path.join(OUT, "logo_transparent.png"))
print(os.path.join(OUT, "logo_transparent.png"), lg.size)
