"""
transcribe.py — Generate subtitles from a video using faster-whisper + CUDA

Usage:
    python transcribe.py <video_file> [--model large-v3] [--language ja] [--translate]

Outputs (next to the video):
    video.srt   — subtitle file (mpv auto-loads this)
    video.md    — timestamped notes for export

Models (best to fastest): large-v3, medium, small, base, tiny
"""

import sys
import os
import argparse
from pathlib import Path
from datetime import timedelta


def format_srt_time(seconds: float) -> str:
    td = timedelta(seconds=seconds)
    total_seconds = int(td.total_seconds())
    hours, remainder = divmod(total_seconds, 3600)
    minutes, secs = divmod(remainder, 60)
    millis = int((seconds - int(seconds)) * 1000)
    return f"{hours:02}:{minutes:02}:{secs:02},{millis:03}"


def format_md_time(seconds: float) -> str:
    td = timedelta(seconds=seconds)
    total_seconds = int(td.total_seconds())
    hours, remainder = divmod(total_seconds, 3600)
    minutes, secs = divmod(remainder, 60)
    if hours > 0:
        return f"{hours}:{minutes:02}:{secs:02}"
    return f"{minutes}:{secs:02}"


def transcribe(video_path: Path, model_name: str, language: str | None):
    from faster_whisper import WhisperModel

    task = "translate"

    print(f"  video   : {video_path.name}")
    print(f"  model   : {model_name}")
    print(f"  language: {language or 'auto-detect'}")
    print(f"  task    : translate → English")
    print()

    print("Loading model (first run downloads weights)...")
    try:
        model = WhisperModel(model_name, device="cuda", compute_type="float16")
        print("  device  : CUDA (RTX 3070 Ti)")
    except Exception:
        print("  CUDA unavailable — falling back to CPU (int8)")
        model = WhisperModel(model_name, device="cpu", compute_type="int8")
        print("  device  : CPU (int8)")

    print("Transcribing...")
    segments, info = model.transcribe(
        str(video_path),
        language=language,
        task=task,
        beam_size=5,
        vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 500},
    )

    print(f"  detected language: {info.language} ({info.language_probability:.0%})")
    print(f"  duration: {info.duration:.0f}s")
    print()

    srt_path = video_path.with_suffix(".srt")
    md_path = video_path.with_suffix(".md")

    segment_list = []
    for i, segment in enumerate(segments, 1):
        segment_list.append(segment)
        print(f"  [{format_md_time(segment.start)}]  {segment.text.strip()}")

    print(f"\nWriting {srt_path.name} ...")
    with open(srt_path, "w", encoding="utf-8") as f:
        for i, seg in enumerate(segment_list, 1):
            f.write(f"{i}\n")
            f.write(f"{format_srt_time(seg.start)} --> {format_srt_time(seg.end)}\n")
            f.write(f"{seg.text.strip()}\n\n")

    print(f"Writing {md_path.name} ...")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(f"# {video_path.stem}\n\n")
        f.write(f"*Transcribed with faster-whisper ({model_name})*\n\n")
        f.write("---\n\n")
        for seg in segment_list:
            f.write(f"**[{format_md_time(seg.start)}]** {seg.text.strip()}\n\n")

    print()
    print("Done.")
    print(f"  Subtitles : {srt_path}")
    print(f"  Notes     : {md_path}")
    print()
    print("mpv will auto-load the .srt when you open the video.")


def main():
    parser = argparse.ArgumentParser(description="Transcribe video to SRT + markdown notes")
    parser.add_argument("video", help="Path to video file")
    parser.add_argument("--model", default="large-v3",
                        choices=["tiny", "base", "small", "medium", "large-v2", "large-v3"],
                        help="Whisper model (default: large-v3)")
    parser.add_argument("--language", default=None,
                        help="Language code e.g. 'ja' (default: auto-detect)")
    args = parser.parse_args()

    video_path = Path(args.video).resolve()
    if not video_path.exists():
        print(f"Error: file not found: {video_path}", file=sys.stderr)
        sys.exit(1)

    transcribe(video_path, args.model, args.language)


if __name__ == "__main__":
    main()
