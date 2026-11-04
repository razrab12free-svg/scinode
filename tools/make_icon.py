"""Рисует иконку приложения Scinode: сеть узлов на тёмном фоне."""
import os

from PIL import Image, ImageDraw

S = 3
SIZE = 1024
W = SIZE * S

PTS = [(512, 512), (330, 380), (700, 340), (690, 690), (350, 690)]
RAD = [100, 62, 56, 66, 52]
COLS = [
    (255, 255, 255),
    (34, 211, 238),
    (167, 139, 250),
    (52, 211, 153),
    (251, 191, 36),
]
EDGES = [(0, 1), (0, 2), (0, 3), (0, 4), (1, 2), (2, 3), (3, 4), (4, 1)]


def nodes_layer():
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for a, b in EDGES:
        main = a == 0
        d.line(
            [(PTS[a][0] * S, PTS[a][1] * S), (PTS[b][0] * S, PTS[b][1] * S)],
            fill=(255, 255, 255, 200 if main else 110),
            width=(16 if main else 10) * S,
        )
    for (x, y), r, c in zip(PTS, RAD, COLS):
        d.ellipse(
            [(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S],
            fill=c + (255,),
        )
    return layer


def background():
    grad = Image.linear_gradient("L").resize((W, W))
    top = Image.new("RGBA", (W, W), (46, 38, 120, 255))
    bottom = Image.new("RGBA", (W, W), (10, 12, 40, 255))
    img = Image.composite(bottom, top, grad)
    rounded = Image.new("L", (W, W), 0)
    ImageDraw.Draw(rounded).rounded_rectangle(
        [0, 0, W - 1, W - 1], radius=230 * S, fill=255
    )
    img.putalpha(rounded)
    return img


def main():
    os.makedirs("assets/icon", exist_ok=True)
    resample = Image.Resampling.LANCZOS
    fg = nodes_layer()
    fg.resize((SIZE, SIZE), resample).save("assets/icon/icon_fg.png")
    full = Image.alpha_composite(background(), fg)
    full.resize((SIZE, SIZE), resample).save("assets/icon/icon.png")
    print("Icon created")


if __name__ == "__main__":
    main()
