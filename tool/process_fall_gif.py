"""Convert green-screen fall GIFs to transparent animated WebP assets."""

from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
ASSET_PACK_DIR = ROOT / "assets_pack"
DEFAULT_SOURCE = ASSET_PACK_DIR / "runner" / "te" / "runner3.gif"
RUNNER_DIR = ROOT / "assets" / "images" / "runners"
DEFAULT_FALL_DESTINATION = RUNNER_DIR / "runner3_fall.webp"
DEFAULT_RECOVER_DESTINATION = RUNNER_DIR / "runner3_recover.webp"
RECOVERY_START_FRAME = 80
FALL_PLAYBACK_SPEED = 2.0
# Animated WebP uses 0 for infinite looping and 1 for a single playback.
PLAY_ONCE_LOOP_COUNT = 1


def remove_green(frame: Image.Image) -> Image.Image:
    pixels = np.asarray(frame.convert("RGBA"), dtype=np.int16).copy()
    red = pixels[..., 0]
    green = pixels[..., 1]
    blue = pixels[..., 2]
    dominance = green - np.maximum(red, blue)

    # Fully remove the green screen and softly feather the anti-aliased edge.
    alpha = np.clip((85 - dominance) * (255 / 60), 0, 255).astype(np.uint8)
    alpha[dominance >= 85] = 0
    alpha[dominance <= 25] = 255

    # Suppress residual green spill on semi-transparent edge pixels without
    # changing opaque colours such as the runner's yellow shirt.
    edge = (alpha > 0) & (alpha < 255)
    pixels[..., 1][edge] = np.minimum(
        pixels[..., 1][edge],
        np.maximum(pixels[..., 0][edge], pixels[..., 2][edge]) + 18,
    )
    pixels[..., 3] = alpha
    return Image.fromarray(pixels.astype(np.uint8), "RGBA")


def save_animation(
    frames: list[Image.Image],
    durations: list[int],
    destination: Path,
) -> None:
    frames[0].save(
        destination,
        format="WEBP",
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=PLAY_ONCE_LOOP_COUNT,
        lossless=True,
        method=4,
        minimize_size=True,
        exact=True,
    )
    with Image.open(destination) as encoded:
        encoded_loop = encoded.info.get("loop")
        if encoded_loop != PLAY_ONCE_LOOP_COUNT:
            raise RuntimeError(
                f"Unexpected loop count for {destination}: {encoded_loop}"
            )

    print(
        f"{destination.name}: {len(frames)} frames, {sum(durations)} ms, "
        f"loop={encoded_loop}, {destination.stat().st_size} bytes"
    )


def speed_up(durations: list[int], multiplier: float) -> list[int]:
    """Shorten frame delays while preserving every animation frame."""
    return [max(1, round(duration / multiplier)) for duration in durations]


def convert(source: Path, fall_destination: Path, recover_destination: Path) -> None:
    with Image.open(source) as animation:
        frames: list[Image.Image] = []
        durations: list[int] = []
        for source_frame in ImageSequence.Iterator(animation):
            frames.append(remove_green(source_frame))
            durations.append(source_frame.info.get("duration", 33))

        save_animation(
            frames[:RECOVERY_START_FRAME],
            speed_up(
                durations[:RECOVERY_START_FRAME],
                FALL_PLAYBACK_SPEED,
            ),
            fall_destination,
        )
        save_animation(
            frames[RECOVERY_START_FRAME:],
            durations[RECOVERY_START_FRAME:],
            recover_destination,
        )


def main() -> None:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SOURCE
    fall_destination = (
        Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_FALL_DESTINATION
    )
    recover_destination = (
        Path(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_RECOVER_DESTINATION
    )
    if not source.is_file():
        sys.exit(f"Source not found: {source}")
    fall_destination.parent.mkdir(parents=True, exist_ok=True)
    recover_destination.parent.mkdir(parents=True, exist_ok=True)
    convert(source, fall_destination, recover_destination)


if __name__ == "__main__":
    main()
