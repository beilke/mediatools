import os
import shutil
from mutagen import File
from mutagen.easyid3 import EasyID3
from pathlib import Path
import re

SUPPORTED_FORMATS = ['.mp3', '.flac', '.m4a', '.ogg', '.wav']

def sanitize_name(name):
    """Remove invalid characters for filenames."""
    return re.sub(r'[\\/*?:"<>|]', '_', name.strip())

def get_metadata(filepath):
    """Extract metadata using mutagen."""
    try:
        audio = EasyID3(filepath)
    except Exception:
        audio = File(filepath)
        if not audio or not audio.tags:
            return None

    artist = audio.get('artist', [None])[0]
    album = audio.get('album', [None])[0]
    title = audio.get('title', [None])[0]
    track = audio.get('tracknumber', [None])[0]

    if track:
        track = track.split('/')[0].zfill(2)

    return {
        'artist': sanitize_name(artist) if artist else "Unknown Artist",
        'album': sanitize_name(album) if album else "Unknown Album",
        'title': sanitize_name(title) if title else Path(filepath).stem,
        'track': track if track else "00"
    }

def organize_music(source_dir, dest_dir):
    for root, _, files in os.walk(source_dir):
        for file in files:
            ext = Path(file).suffix.lower()
            if ext not in SUPPORTED_FORMATS:
                continue

            src_file = os.path.join(root, file)
            metadata = get_metadata(src_file)

            if not metadata:
                print(f"Skipping: {src_file} (No metadata)")
                continue

            artist = metadata['artist']
            album = metadata['album']
            track = metadata['track']
            title = metadata['title']

            dest_path = os.path.join(dest_dir, artist, album)
            os.makedirs(dest_path, exist_ok=True)

            new_filename = f"{track} - {title}{ext}"
            dest_file = os.path.join(dest_path, new_filename)

            print(f"Copying: {src_file} -> {dest_file}")
            shutil.copy2(src_file, dest_file)

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Organize music into Plex structure.")
    parser.add_argument("source", help="Source directory with music files")
    parser.add_argument("destination", help="Destination directory to copy structured music")

    args = parser.parse_args()
    organize_music(args.source, args.destination)
