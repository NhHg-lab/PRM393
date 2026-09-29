"""Remove connected light backgrounds from runner GIFs.

The source GIFs use a dithered cream/white palette rather than transparency.
Only light pixels connected to the outer canvas are removed, preserving light
details enclosed by the runner artwork. Outputs are animated lossless WebP so
Flutter retains full alpha without a GIF halo.
"""

from pathlib import Path
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "images" / "runners"


def remove_tiny_components(foreground: np.ndarray) -> np.ndarray:
    """Keep runner-shaped regions while dropping disconnected GIF speckles."""
    height, width = foreground.shape
    visited = np.zeros_like(foreground, dtype=bool)
    kept = np.zeros_like(foreground, dtype=bool)

    for y in range(height):
        for x in range(width):
            if not foreground[y, x] or visited[y, x]:
                continue
            queue = deque([(x, y)])
            visited[y, x] = True
            component: list[tuple[int, int]] = []
            while queue:
                current_x, current_y = queue.popleft()
                component.append((current_x, current_y))
                for next_y in range(max(0, current_y - 1), min(height, current_y + 2)):
                    for next_x in range(max(0, current_x - 1), min(width, current_x + 2)):
                        if (
                            foreground[next_y, next_x]
                            and not visited[next_y, next_x]
                        ):
                            visited[next_y, next_x] = True
                            queue.append((next_x, next_y))
            if len(component) >= 12:
                for component_x, component_y in component:
                    kept[component_y, component_x] = True

    return kept


def background_mask(frame: Image.Image) -> Image.Image:
    rgb = np.asarray(frame.convert("RGB"), dtype=np.int16)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]

    # The generated GIF background alternates between pale cream and white.
    # Runner edges have noticeably different red/green channels, so this mask
    # includes the background and its anti-aliased fringe without selecting the
    # coloured character artwork.
    candidate = (
        (red >= 175)
        & (green >= 175)
        & (blue >= 145)
        & (np.abs(red - green) <= 18)
    )
    # `fromarray` can expose a read-only buffer; floodfill needs writable pixels.
    candidate_mask = Image.fromarray(
        np.where(candidate, 255, 0).astype(np.uint8),
        "L",
    ).copy()

    # GIF dithering can leave background pixels touching only diagonally.
    # A one-pixel expansion joins those islands for the connectivity test. The
    # final result is intersected with the original candidate mask, so coloured
    # runner pixels are never removed by the expansion itself.
    mask = candidate_mask.filter(ImageFilter.MaxFilter(3))

    # Flood from every eligible edge segment. Normally the first corner reaches
    # the whole backdrop; extra seeds make the operation robust to edge contact.
    pixels = mask.load()
    width, height = mask.size
    seeds = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
    for x in range(0, width, 8):
        seeds.extend(((x, 0), (x, height - 1)))
    for y in range(0, height, 8):
        seeds.extend(((0, y), (width - 1, y)))
    for seed in seeds:
        if pixels[seed] == 255:
            ImageDraw.floodfill(mask, seed, 128, thresh=0)

    connected = np.asarray(mask) == 128
    removable = candidate & connected
    foreground = remove_tiny_components(~removable)
    removable = ~foreground
    return Image.fromarray(
        np.where(removable, 255, 0).astype(np.uint8),
        "L",
    )


def process(source: Path, destination: Path) -> None:
    with Image.open(source) as animation:
        loop = animation.info.get("loop", 0)
        frames: list[Image.Image] = []
        durations: list[int] = []

        for source_frame in ImageSequence.Iterator(animation):
            frame = source_frame.convert("RGBA")
            remove = background_mask(frame)
            alpha = Image.new("L", frame.size, 255)
            alpha.paste(0, mask=remove)
            frame.putalpha(alpha)
            frames.append(frame)
            durations.append(source_frame.info.get("duration", 33))

        frames[0].save(
            destination,
            format="WEBP",
            save_all=True,
            append_images=frames[1:],
            duration=durations,
            loop=loop,
            lossless=True,
            method=4,
            minimize_size=True,
            exact=True,
        )

    print(
        f"{source.name} -> {destination.name}: "
        f"{len(frames)} frames, {destination.stat().st_size} bytes"
    )


def main() -> None:
    sources = sorted(ASSET_DIR.glob("runner*.gif"))
    if not sources:
        sys.exit("No runner GIFs found")
    for source in sources:
        process(source, source.with_suffix(".webp"))


if __name__ == "__main__":
    main()
