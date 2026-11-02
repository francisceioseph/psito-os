#!/usr/bin/env python3
"""Gera a biblioteca de teste do player: tons sintéticos, sem direitos autorais.

  gen_test_library.py <pasta>               um arquivo de cada formato, com tags,
                                            capa e letra, e os pares de gapless
  gen_test_library.py <pasta> --tracks N    mais N faixas em artistas e álbuns

Precisa do ffmpeg. As capas são quadrados de cor gerados aqui.
"""
import argparse
import base64
import shutil
import struct
import subprocess
import sys
from pathlib import Path

FORMATS = {
    "flac": ["-c:a", "flac"],
    "mp3": ["-c:a", "libmp3lame", "-q:a", "4"],
    "ogg": ["-c:a", "libvorbis", "-q:a", "4"],
    "opus": ["-c:a", "libopus", "-b:a", "96k"],
    "m4a": ["-c:a", "aac", "-b:a", "128k"],
    "wav": ["-c:a", "pcm_s16le"],
}
TAGS = {
    "title": "Tom de teste",
    "artist": "Artista Sintético",
    "album": "Álbum de Testes",
    "date": "2026",
    "track": "3/12",
    "genre": "Teste",
}
LRC = "[ar:Artista Sintético]\n[00:01.00]Primeira linha\n[00:03.50]Segunda linha\n"
SRT = "1\n00:00:01,000 --> 00:00:03,000\nPrimeira linha\n\n2\n00:00:03,500 --> 00:00:05,000\nSegunda linha\n"


def ffmpeg(*args):
    subprocess.run(
        ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", *args], check=True
    )


def tag_args(tags):
    return [a for k, v in tags.items() for a in ("-metadata", f"{k}={v}")]


def cover(path):
    ffmpeg("-f", "lavfi", "-i", "color=c=teal:s=300x300", "-frames:v", "1", str(path))


def picture_block(jpg):
    """O METADATA_BLOCK_PICTURE do FLAC, que é como o Ogg leva a capa."""
    data = jpg.read_bytes()
    mime = b"image/jpeg"
    return base64.b64encode(
        struct.pack(">II", 3, len(mime))
        + mime
        + struct.pack(">IIIIII", 0, 300, 300, 24, 0, len(data))
        + data
    ).decode()


def tagged(fmt, tone, jpg, out, tags):
    """Um arquivo do formato, com as tags e a capa embutida, se ele aceita."""
    if fmt in ("flac", "mp3", "m4a"):
        ffmpeg(
            "-i", str(tone), "-i", str(jpg),
            "-map", "0:a", "-map", "1:v", *FORMATS[fmt],
            "-c:v", "copy", "-disposition:v", "attached_pic",
            *tag_args(tags), str(out),
        )  # fmt: skip
    elif fmt in ("ogg", "opus"):
        meta = out.with_suffix(".ffmeta")
        escaped = picture_block(jpg)
        lines = [f"{k.upper()}={v}" for k, v in tags.items()]
        meta.write_text(
            ";FFMETADATA1\n" + "\n".join(lines) + f"\nMETADATA_BLOCK_PICTURE={escaped}\n"
        )
        ffmpeg("-i", str(tone), "-i", str(meta), "-map_metadata", "1", "-vn",
               *FORMATS[fmt], str(out))  # fmt: skip
        meta.unlink()
    else:
        # O WAV guarda só as tags básicas, em INFO
        ffmpeg("-i", str(tone), *FORMATS[fmt], *tag_args(tags), str(out))


def formats(dest, tone, jpg):
    folder = dest / "formatos"
    folder.mkdir(parents=True, exist_ok=True)
    for fmt in FORMATS:
        tagged(fmt, tone, jpg, folder / f"tom.{fmt}", TAGS)
    (folder / "tom.lrc").write_text(LRC, encoding="utf-8")
    (folder / "tom.srt").write_text(SRT, encoding="utf-8")
    shutil.copy(jpg, folder / "cover.jpg")


def gapless(dest):
    """Um seno contínuo cortado em dois: um buraco na emenda se mede na saída."""
    folder = dest / "gapless"
    folder.mkdir(parents=True, exist_ok=True)
    whole = folder / "inteiro.wav"
    ffmpeg("-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=6",
           "-ac", "2", "-c:a", "pcm_s16le", str(whole))  # fmt: skip
    for fmt, codec in FORMATS.items():
        for part, cut in (("a", ["-t", "3"]), ("b", ["-ss", "3"])):
            ffmpeg("-i", str(whole), *cut, *codec, str(folder / f"{part}.{fmt}"))
    whole.unlink()


def bulk(dest, tone, jpg, tracks):
    """Muitas faixas: um arquivo só, copiado com tags diferentes."""
    folder = dest / "muitas"
    seed = folder / "semente.flac"
    folder.mkdir(parents=True, exist_ok=True)
    tagged("flac", tone, jpg, seed, TAGS)
    per_album, albums_per_artist = 12, 5
    for i in range(tracks):
        album = i // per_album
        artist = album // albums_per_artist
        out = folder / f"artista-{artist:04}" / f"album-{album:05}" / f"{i % per_album + 1:02}.flac"
        out.parent.mkdir(parents=True, exist_ok=True)
        tags = {
            "title": f"Faixa {i:06}",
            "artist": f"Artista {artist:04}",
            "album": f"Álbum {album:05}",
            "date": str(1970 + album % 50),
            "track": f"{i % per_album + 1}/{per_album}",
            "genre": f"Gênero {artist % 20}",
        }
        ffmpeg("-i", str(seed), "-map", "0", "-c", "copy", *tag_args(tags), str(out))
    seed.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dest", type=Path)
    parser.add_argument("--tracks", type=int, default=0)
    args = parser.parse_args()
    if not shutil.which("ffmpeg"):
        sys.exit("falta o ffmpeg")
    args.dest.mkdir(parents=True, exist_ok=True)
    tone = args.dest / ".tom.wav"
    jpg = args.dest / ".capa.jpg"
    ffmpeg("-f", "lavfi", "-i", "sine=frequency=440:duration=5", "-ac", "2", str(tone))
    cover(jpg)
    formats(args.dest, tone, jpg)
    gapless(args.dest)
    if args.tracks:
        bulk(args.dest, tone, jpg, args.tracks)
    tone.unlink()
    jpg.unlink()


if __name__ == "__main__":
    main()
