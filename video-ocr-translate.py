"""
video-ocr-translate.py — Translate burned-in foreign-language captions in a video to English

Detects the solid black caption bar at the bottom of each frame, sends it to
Gemini Vision for OCR + translation, and re-renders the bar with English text.
Only calls the API when the bar content actually changes (frame deduplication).

Usage:
    python video-ocr-translate.py <video> [--output out.mp4] [--bar 0.18] [--dry-run]

Output:
    <input_stem>_fixsub.mp4  (default) — same dimensions, audio preserved, English captions
"""

import sys
import os
import argparse
import base64
import shutil
import subprocess
import tempfile
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

FFMPEG       = Path(r"C:\Users\rjh\workstation\tools\ffmpeg\bin\ffmpeg.exe")
FONT_PATHS   = [
    Path(r"C:\Users\rjh\workstation\assets\fonts\NotoSans-Bold.ttf"),
    Path(r"C:\Windows\Fonts\arialbd.ttf"),
    Path(r"C:\Windows\Fonts\arial.ttf"),
]
GEMINI_MODEL = "gemini-2.0-flash-lite"
BAR_FRACTION = 0.18    # bottom fraction of frame treated as caption bar
DIFF_THRESH  = 8.0     # mean absolute difference threshold to trigger API call
TEXT_COLOR   = (220, 60, 20)   # RGB — red matching original style
FONT_SIZE    = 32
JPEG_QUALITY = 90


# ---------------------------------------------------------------------------
# Frame helpers
# ---------------------------------------------------------------------------

def bar_height(frame_h: int, fraction: float) -> int:
    return int(frame_h * fraction)


def crop_bar(frame: np.ndarray, bh: int) -> np.ndarray:
    """Return the bottom bh rows of frame."""
    return frame[-bh:, :, :]


def bar_changed(crop: np.ndarray, prev_crop: np.ndarray, threshold: float) -> bool:
    """True if the caption bar looks different from the previous one."""
    a = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY).astype(np.float32)
    b = cv2.cvtColor(prev_crop, cv2.COLOR_BGR2GRAY).astype(np.float32)
    return float(np.mean(np.abs(a - b))) > threshold


def encode_jpeg(img: np.ndarray, quality: int = JPEG_QUALITY) -> bytes:
    """Encode a BGR numpy frame as JPEG bytes."""
    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, quality])
    if not ok:
        raise RuntimeError("Failed to encode frame as JPEG")
    return buf.tobytes()


# ---------------------------------------------------------------------------
# Gemini Vision
# ---------------------------------------------------------------------------

TRANSLATE_PROMPT = (
    "Translate the Turkish text in this image to English. "
    "Respond with only the English translation, nothing else. "
    "If there is no text, respond with an empty string."
)


def call_gemini(client, crop_bytes: bytes, model: str = GEMINI_MODEL) -> str | None:
    """Send bar crop to Gemini Vision; return English translation."""
    import time
    from google.genai import types
    for attempt in range(3):
        try:
            resp = client.models.generate_content(
                model=model,
                contents=[
                    types.Part.from_bytes(data=crop_bytes, mime_type="image/jpeg"),
                    types.Part.from_text(text=TRANSLATE_PROMPT),
                ],
            )
            return resp.text.strip()
        except Exception as e:
            msg = str(e)
            if "429" in msg or "RESOURCE_EXHAUSTED" in msg:
                wait = 45 * (attempt + 1)
                print(f"  [warn] rate limited — waiting {wait}s...", file=sys.stderr)
                time.sleep(wait)
            else:
                print(f"  [warn] API error: {e}", file=sys.stderr)
                return None
    return None


# ---------------------------------------------------------------------------
# Text rendering
# ---------------------------------------------------------------------------

def load_font(font_path: Path | None, size: int) -> ImageFont.ImageFont:
    """Try user-supplied path, then fallbacks, then PIL default."""
    candidates = ([font_path] if font_path else []) + FONT_PATHS
    for p in candidates:
        if p and p.exists():
            try:
                return ImageFont.truetype(str(p), size)
            except Exception:
                continue
    print("  [warn] No TTF font found — using PIL built-in bitmap font", file=sys.stderr)
    return ImageFont.load_default()


def render_bar(frame: np.ndarray, bh: int, text: str, font: ImageFont.ImageFont) -> np.ndarray:
    """
    Fill the bottom bh rows black, then draw centered English text in red.
    Returns a modified copy of frame.
    """
    out = frame.copy()
    h, w = out.shape[:2]

    # Black out the bar
    out[-bh:, :] = 0

    if not text:
        return out

    # Convert to PIL for text rendering
    pil = Image.fromarray(cv2.cvtColor(out, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(pil)

    # Measure and center text
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (w - text_w) // 2
    bar_top = h - bh
    y = bar_top + (bh - text_h) // 2 - bbox[1]  # subtract ascender offset

    draw.text((x, y), text, font=font, fill=TEXT_COLOR)

    return cv2.cvtColor(np.array(pil), cv2.COLOR_RGB2BGR)


# ---------------------------------------------------------------------------
# Audio handling
# ---------------------------------------------------------------------------

def ffmpeg_bin() -> str:
    if FFMPEG.exists():
        return str(FFMPEG)
    return "ffmpeg"  # fall back to PATH


def extract_audio(input_path: Path, tmp_dir: Path) -> Path | None:
    """Extract audio stream to a temp file; returns path or None if no audio."""
    probe = subprocess.run(
        [ffmpeg_bin(), "-i", str(input_path), "-hide_banner"],
        capture_output=True, text=True
    )
    if "Audio:" not in probe.stderr:
        return None

    audio_path = tmp_dir / "audio.aac"
    result = subprocess.run(
        [ffmpeg_bin(), "-y", "-i", str(input_path),
         "-vn", "-acodec", "copy", str(audio_path)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    if result.returncode != 0 or not audio_path.exists():
        print("  [warn] Audio extraction failed — output will be muted", file=sys.stderr)
        return None
    return audio_path


def mux_audio(muted_video: Path, audio_path: Path | None, output_path: Path) -> None:
    """Combine muted video and audio track into final output."""
    if audio_path is None:
        shutil.copy2(muted_video, output_path)
        return

    result = subprocess.run(
        [ffmpeg_bin(), "-y",
         "-i", str(muted_video),
         "-i", str(audio_path),
         "-c:v", "copy", "-c:a", "copy",
         "-shortest", str(output_path)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    if result.returncode != 0:
        print("  [warn] Audio mux failed — output will be muted", file=sys.stderr)
        shutil.copy2(muted_video, output_path)


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def process_video(input_path: Path, output_path: Path, client, args) -> None:
    from rich.progress import Progress, BarColumn, TimeRemainingColumn, TextColumn
    from rich.console import Console

    console = Console()

    cap = cv2.VideoCapture(str(input_path))
    fps    = cap.get(cv2.CAP_PROP_FPS) or 30.0
    w      = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h      = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total  = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    console.print(f"  video     : {input_path.name}")
    console.print(f"  size      : {w}x{h}  fps: {fps:.2f}  frames: {total}")
    console.print(f"  bar height: {bar_height(h, args.bar)}px ({args.bar:.0%} of frame)")
    console.print(f"  output    : {output_path.name}")
    console.print()

    if args.dry_run:
        est = int(total / fps / 2)
        console.print(f"  [dry-run] estimated API calls: ~{est}")
        cap.release()
        return

    font = load_font(Path(args.font) if args.font else None, args.font_size)

    tmp_dir = Path(tempfile.mkdtemp(prefix="vtrans_"))
    try:
        console.print("Extracting audio...")
        audio_path = extract_audio(input_path, tmp_dir)
        console.print(f"  {'audio saved' if audio_path else 'no audio track found'}")
        console.print()

        tmp_video = tmp_dir / "muted.mp4"
        fourcc = cv2.VideoWriter.fourcc(*"mp4v")
        writer = cv2.VideoWriter(str(tmp_video), fourcc, fps, (w, h))

        prev_crop        = None
        last_translation = ""
        api_calls        = 0
        bh               = bar_height(h, args.bar)

        with Progress(
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TextColumn("{task.completed}/{task.total}"),
            TimeRemainingColumn(),
        ) as progress:
            task = progress.add_task("Processing frames", total=total)

            while True:
                ret, frame = cap.read()
                if not ret:
                    break

                crop = crop_bar(frame, bh)

                if prev_crop is None or bar_changed(crop, prev_crop, args.diff):
                    import time
                    crop_bytes = encode_jpeg(crop)
                    result = call_gemini(client, crop_bytes, model=args.model)
                    if result is not None:
                        last_translation = result
                    prev_crop = crop.copy()
                    api_calls += 1
                    time.sleep(2.5)  # stay under 30 req/min free tier limit

                out_frame = render_bar(frame, bh, last_translation, font)
                writer.write(out_frame)
                progress.advance(task)

        cap.release()
        writer.release()

        console.print()
        console.print("Muxing audio...")
        mux_audio(tmp_video, audio_path, output_path)

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

    console.print()
    console.print("[green]Done.[/green]")
    console.print(f"  API calls  : {api_calls}")
    console.print(f"  Output     : {output_path}")
    console.print()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Translate burned-in captions in a video using Gemini Vision"
    )
    parser.add_argument("video", help="Path to input video file")
    parser.add_argument("--output", "-o", default=None,
                        help="Output path (default: <input>_fixsub.mp4)")
    parser.add_argument("--bar", type=float, default=BAR_FRACTION,
                        help=f"Fraction of frame height for caption bar (default: {BAR_FRACTION})")
    parser.add_argument("--diff", type=float, default=DIFF_THRESH,
                        help=f"MAD threshold for frame change detection (default: {DIFF_THRESH})")
    parser.add_argument("--font-size", type=int, default=FONT_SIZE,
                        help=f"Font size for translated text (default: {FONT_SIZE})")
    parser.add_argument("--font", default=None,
                        help="Path to TTF font file (optional)")
    parser.add_argument("--model", default=GEMINI_MODEL,
                        help=f"Gemini model to use (default: {GEMINI_MODEL})")
    parser.add_argument("--dry-run", action="store_true",
                        help="Estimate API calls without processing")
    parser.add_argument("--api-key", default=None,
                        help="Gemini API key (overrides GEMINI_API_KEY env var)")
    args = parser.parse_args()

    input_path = Path(args.video).resolve()
    if not input_path.exists():
        print(f"Error: file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    if args.output:
        output_path = Path(args.output).resolve()
    else:
        output_path = input_path.with_stem(input_path.stem + "_fixsub").with_suffix(".mp4")

    api_key = args.api_key or os.environ.get("GEMINI_API_KEY")
    if not api_key and not args.dry_run:
        print(
            "Error: no API key found.\n"
            "Set the GEMINI_API_KEY environment variable or pass --api-key.",
            file=sys.stderr,
        )
        sys.exit(1)

    from google import genai
    client = genai.Client(api_key=api_key) if api_key else None

    process_video(input_path, output_path, client, args)


if __name__ == "__main__":
    main()
