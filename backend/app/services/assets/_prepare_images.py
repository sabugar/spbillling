"""One-shot script: convert source JPEGs to PNGs with light backgrounds turned
transparent. Run this whenever the source logo/signature changes."""

import os

from PIL import Image

ASSETS_DIR = os.path.dirname(os.path.abspath(__file__))


def remove_light_bg(in_path: str, out_path: str, threshold: int = 130) -> None:
    """Make any pixel whose darkest channel ≥ threshold fully transparent.
    Uses min(r,g,b) so that strongly-colored ink (e.g., blue signature where
    only B is high) is preserved while light/desaturated backgrounds drop out.
    Also softens edges so anti-aliased pixels fade rather than ring."""
    img = Image.open(in_path).convert("RGBA")
    pixels = list(img.getdata())
    new_pixels = []
    soft_band = 30  # 30 levels of fade above threshold
    for r, g, b, a in pixels:
        m = min(r, g, b)
        if m >= threshold + soft_band:
            new_pixels.append((r, g, b, 0))
        elif m >= threshold:
            # Linear fade to transparent in the soft band
            new_alpha = int(a * (1 - (m - threshold) / soft_band))
            new_pixels.append((r, g, b, max(0, new_alpha)))
        else:
            new_pixels.append((r, g, b, a))
    img.putdata(new_pixels)
    img.save(out_path, "PNG")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    pairs = [
        # Logo: tan background, blacks must survive — drop more aggressively
        (os.path.join(ASSETS_DIR, "reliance_gas_logo.jpeg"),
         os.path.join(ASSETS_DIR, "reliance_gas_logo.png"),
         110),
        # Signature: white/light-gray background, blue ink — drop everything
        # lighter than the lightest part of the actual ink stroke.
        (os.path.join(ASSETS_DIR, "signature.jpeg"),
         os.path.join(ASSETS_DIR, "signature.png"),
         110),
    ]
    for src, dst, thr in pairs:
        if os.path.exists(src):
            remove_light_bg(src, dst, thr)
        else:
            print(f"Missing: {src}")
