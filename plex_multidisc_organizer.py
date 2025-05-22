import os
import re
import shutil
from pathlib import Path
from mutagen import File
from mutagen.easyid3 import EasyID3
from mutagen.flac import FLAC
from mutagen.mp4 import MP4

def is_music_file(filename):
    music_extensions = {'.mp3', '.flac', '.m4a', '.wav', '.aac', '.ogg', '.wma'}
    return Path(filename).suffix.lower() in music_extensions

def clean_album_name(album_name):
    patterns = [
        r'\s*\(?\s*(CD|Disc)\s*\d+\s*\)?',
        r'\s*\[?\s*(CD|Disc)\s*\d+\s*\]?',
        r'\s*-\s*(CD|Disc)\s*\d+',
        r'\s*(CD|Disc)\s*\d+'
    ]
    for pattern in patterns:
        album_name = re.sub(pattern, '', album_name, flags=re.IGNORECASE)
    return album_name.strip()

def clean_album_metadata(file_path):
    try:
        audio = File(file_path, easy=True)
        if audio is None:
            print(f"Unsupported format: {file_path}")
            return None

        album_tag = audio.get('album', [None])[0]
        if album_tag:
            cleaned_album = clean_album_name(album_tag)
            if cleaned_album != album_tag:
                print(f"Updating album tag: '{album_tag}' -> '{cleaned_album}'")
                audio['album'] = cleaned_album
                audio.save()
            return cleaned_album
    except Exception as e:
        print(f"Failed to clean album tag for {file_path}: {e}")
    return None

def plex_compliant_filename(track_number, title, disc_number=None):
    invalid_chars = r'[<>:"/\\|?*\x00-\x1f]'
    title = re.sub(invalid_chars, '', title)
    track_num = f"{int(track_number):02d}" if track_number.isdigit() else track_number

    if disc_number and disc_number.isdigit():
        return f"{disc_number}{track_num} - {title}"
    else:
        return f"{track_num} - {title}"

def process_disc_folder(disc_path, dest_album_path, disc_number):
    for file in disc_path.iterdir():
        if file.is_file() and is_music_file(file.name):
            cleaned_album_name = clean_album_metadata(file)
            if not cleaned_album_name:
                continue

            # Try to parse track number and title
            track_match = re.match(r'(\d+)\s*[-.]?\s*(.+?)(?:\..+)?$', file.stem)
            if not track_match:
                print(f"Skipping unrecognized filename: {file.name}")
                continue

            track_number = track_match.group(1)
            title = track_match.group(2).strip()
            new_filename = plex_compliant_filename(track_number, title, disc_number) + file.suffix
            dest_file_path = dest_album_path / new_filename

            shutil.move(str(file), str(dest_file_path))
            print(f"Moved: {file.name} -> {new_filename}")

    try:
        if not any(disc_path.iterdir()):
            disc_path.rmdir()
            print(f"Removed empty folder: {disc_path}")
    except Exception as e:
        print(f"Could not remove {disc_path}: {e}")

def process_album_directory(original_album_path, processed_root):
    relative_path = original_album_path.relative_to(original_album_path.parent)
    dest_album_path = processed_root / relative_path

    if dest_album_path.exists():
        print(f"Removing previous copy at: {dest_album_path}")
        shutil.rmtree(dest_album_path, onerror=on_rm_error)

    print(f"Copying album to: {dest_album_path}")
    shutil.copytree(original_album_path, dest_album_path)

    for item in dest_album_path.iterdir():
        if item.is_dir() and re.search(r'(?i)(cd|disc)\s*(\d+)', item.name):
            disc_number = re.search(r'(?i)(cd|disc)\s*(\d+)', item.name).group(2)
            print(f"Processing disc folder: {item.name}")
            process_disc_folder(item, dest_album_path, disc_number)

def main():
    target_dir = input("Enter the directory path containing albums: ").strip()
    target_path = Path(target_dir)

    if not target_path.is_dir():
        print(f"Error: {target_dir} is not a valid directory")
        return

    processed_root = target_path / "processed"
    processed_root.mkdir(exist_ok=True)

    for album_dir in target_path.iterdir():
        if not album_dir.is_dir() or album_dir.name.lower() == "processed":
            continue

        has_disc_folders = any(
            d.is_dir() and re.search(r'(?i)(cd|disc)\s*\d+', d.name) for d in album_dir.iterdir()
        )

        if has_disc_folders:
            print(f"\nProcessing album: {album_dir.name}")
            process_album_directory(album_dir, processed_root)
        else:
            print(f"\nSkipping album without disc folders: {album_dir.name}")

    print("\nAll processing complete.")

if __name__ == "__main__":
    main()
