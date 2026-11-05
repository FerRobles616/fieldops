"""Generate FieldOps Play Store assets and Android/web launcher icons.

Run from the repository root:
    python docs/play-store/generate_assets.py

Requires Pillow and a Flutter SDK in PATH.
"""

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "docs" / "play-store" / "assets"
FONT_BOLD = Path("/usr/share/fonts/rsms-inter-fonts/InterDisplay-Bold.ttf")
FONT_SEMIBOLD = Path("/usr/share/fonts/rsms-inter-fonts/Inter-SemiBold.ttf")
FONT_REGULAR = Path("/usr/share/fonts/rsms-inter-fonts/Inter-Regular.ttf")
if not FONT_BOLD.exists():
    FONT_BOLD = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
if not FONT_SEMIBOLD.exists():
    FONT_SEMIBOLD = FONT_BOLD
if not FONT_REGULAR.exists():
    FONT_REGULAR = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")

flutter_binary = shutil.which("flutter")
if flutter_binary is None:
    raise SystemExit("flutter not found in PATH")
MATERIAL_ICONS = (
    Path(flutter_binary).resolve().parent.parent
    / "bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
)
if not MATERIAL_ICONS.exists():
    raise SystemExit(f"Material Icons font not found at {MATERIAL_ICONS}")

TEAL = (15, 118, 110)
DARK_TEAL = (7, 53, 49)
ENGINEERING_GLYPH = "\uf70f"


def gradient(size: int) -> Image.Image:
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    for y in range(size):
        for x in range(size):
            ratio = (x + y) / (2 * (size - 1))
            pixels[x, y] = tuple(
                round(start * (1 - ratio) + end * ratio)
                for start, end in zip(TEAL, DARK_TEAL, strict=True)
            )
    return image


def rounded_icon(size: int = 1024) -> Image.Image:
    image = gradient(size).convert("RGBA")
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Subtle depth circles.
    draw.ellipse((-160, -240, 540, 460), fill=(255, 255, 255, 12))
    draw.ellipse((620, 620, 1200, 1200), fill=(255, 255, 255, 10))

    # Match the in-app AppLogo: Material engineering icon on primary teal.
    icon_font = ImageFont.truetype(str(MATERIAL_ICONS), 620)
    bbox = draw.textbbox((0, 0), ENGINEERING_GLYPH, font=icon_font)
    glyph_width = bbox[2] - bbox[0]
    glyph_height = bbox[3] - bbox[1]
    draw.text(
        (
            (size - glyph_width) / 2 - bbox[0],
            (size - glyph_height) / 2 - bbox[1] - 8,
        ),
        ENGINEERING_GLYPH,
        font=icon_font,
        fill=(255, 255, 255, 255),
    )

    image.alpha_composite(overlay)
    return image.convert("RGB")


def feature_graphic(icon: Image.Image) -> Image.Image:
    width, height = 1024, 500
    base = Image.new("RGB", (width, height))
    pixels = base.load()
    for y in range(height):
        for x in range(width):
            ratio = (x + y) / (width + height - 2)
            pixels[x, y] = tuple(
                round(start * (1 - ratio) + end * ratio)
                for start, end in zip(TEAL, DARK_TEAL, strict=True)
            )

    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.ellipse((-220, -280, 440, 380), fill=(255, 255, 255, 12))
    draw.ellipse((760, 300, 1180, 720), fill=(255, 255, 255, 10))

    title_font = ImageFont.truetype(str(FONT_BOLD), 82)
    subtitle_font = ImageFont.truetype(str(FONT_SEMIBOLD), 34)
    body_font = ImageFont.truetype(str(FONT_REGULAR), 25)
    pill_font = ImageFont.truetype(str(FONT_SEMIBOLD), 18)

    draw.text((64, 118), "FieldOps", font=title_font, fill=(255, 255, 255, 255))
    draw.text(
        (66, 224),
        "Offline-first work orders",
        font=subtitle_font,
        fill=(207, 236, 230, 255),
    )
    draw.text(
        (66, 278),
        "Sync when the signal returns.",
        font=body_font,
        fill=(168, 213, 205, 255),
    )

    pill_text = "FIELD SERVICE  ·  OFFLINE READY"
    pill_box = draw.textbbox((0, 0), pill_text, font=pill_font)
    pill_width = pill_box[2] - pill_box[0] + 44
    draw.rounded_rectangle(
        (64, 352, 64 + pill_width, 398),
        radius=23,
        fill=(10, 82, 76, 255),
        outline=(126, 196, 186, 255),
        width=2,
    )
    draw.text(
        (86, 365),
        pill_text,
        font=pill_font,
        fill=(207, 236, 230, 255),
    )

    # Icon card.
    draw.rounded_rectangle(
        (704, 68, 956, 432),
        radius=44,
        fill=(255, 255, 255, 255),
    )
    base = Image.alpha_composite(base.convert("RGBA"), overlay).convert("RGB")
    icon_card = icon.resize((212, 212), Image.LANCZOS).convert("RGBA")
    icon_mask = Image.new("L", (212, 212), 0)
    ImageDraw.Draw(icon_mask).rounded_rectangle(
        (0, 0, 212, 212),
        radius=48,
        fill=255,
    )
    base.paste(icon_card, (724, 100), icon_mask)
    icon_draw = ImageDraw.Draw(base)
    icon_draw.text(
        (724, 340),
        "FieldOps",
        font=ImageFont.truetype(str(FONT_BOLD), 34),
        fill=DARK_TEAL,
    )
    icon_draw.text(
        (724, 386),
        "work orders",
        font=ImageFont.truetype(str(FONT_REGULAR), 20),
        fill=(91, 111, 107),
    )

    return base


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    icon = rounded_icon(1024)

    icon.resize((512, 512), Image.LANCZOS).save(ASSETS / "icon-512.png", optimize=True)
    feature_graphic(icon).save(ASSETS / "feature-graphic-1024x500.png", optimize=True)

    android_res = ROOT / "app" / "android" / "app" / "src" / "main" / "res"
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_sizes.items():
        destination = android_res / folder / "ic_launcher.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        icon.resize((size, size), Image.LANCZOS).save(destination, optimize=True)

    web_icons = ROOT / "app" / "web" / "icons"
    for size in (192, 512):
        icon.resize((size, size), Image.LANCZOS).save(
            web_icons / f"Icon-{size}.png", optimize=True
        )
        icon.resize((size, size), Image.LANCZOS).save(
            web_icons / f"Icon-maskable-{size}.png", optimize=True
        )
    icon.resize((32, 32), Image.LANCZOS).save(ROOT / "app" / "web" / "favicon.png")

    print(f"wrote {ASSETS / 'icon-512.png'}")
    print(f"wrote {ASSETS / 'feature-graphic-1024x500.png'}")
    print("updated Android mipmaps and web icons")


if __name__ == "__main__":
    main()
