import os
import re
import shutil
from difflib import SequenceMatcher
from typing import List, Dict, Tuple, Optional

def read_tracklist(tracklist_path: str) -> List[Tuple[str, str]]:
    """Read the tracklist file and return a list of (artist, title) tuples."""
    tracks = []
    with open(tracklist_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            
            # Handle different formats - split on '–' or '-' surrounded by spaces
            parts = re.split(r'\s*[–-]\s*', line, maxsplit=1)
            if len(parts) != 2:
                continue
                
            artist, title = parts
            # Clean up quotes around title if present
            title = re.sub(r'^["\']|["\']$', '', title.strip())
            tracks.append((artist.strip(), title.strip()))
    
    return tracks

def find_music_files(root_dir: str) -> List[str]:
    """Recursively find all music files in the directory tree."""
    music_files = []
    extensions = ('.m4a', '.mp3', '.flac')
    
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.lower().endswith(extensions):
                music_files.append(os.path.join(dirpath, filename))
    
    return music_files

def normalize_string(s: str) -> str:
    """Normalize a string for comparison by removing special characters and lowercase."""
    s = s.lower()
    s = re.sub(r'[^\w\s]', '', s)  # Remove punctuation
    s = re.sub(r'\s+', ' ', s).strip()  # Normalize whitespace
    return s

def similar(a: str, b: str) -> float:
    """Return a similarity ratio between two strings."""
    return SequenceMatcher(None, normalize_string(a), normalize_string(b)).ratio()

def find_best_match(track: Tuple[str, str], music_files: List[str], min_similarity: float = 0.7) -> Optional[str]:
    """Find the best matching music file for the given track."""
    artist, title = track
    best_match = None
    best_score = 0
    
    # Create combined search pattern (artist + title)
    track_pattern = f"{artist} {title}"
    
    for filepath in music_files:
        filename = os.path.splitext(os.path.basename(filepath))[0]
        
        # Calculate similarity with both the filename and the track pattern
        filename_similarity = similar(filename, track_pattern)
        title_similarity = similar(filename, title)
        
        # Use the higher of the two similarity scores
        current_score = max(filename_similarity, title_similarity)
        
        if current_score > best_score and current_score >= min_similarity:
            best_score = current_score
            best_match = filepath
    
    return best_match if best_score >= min_similarity else None

def ask_user_permission(source_path: str, dest_folder: str) -> bool:
    """Ask user whether to copy the file or skip."""
    filename = os.path.basename(source_path)
    dest_path = os.path.join(dest_folder, filename)
    
    print(f"\nFound: {source_path}")
    print(f"Would be copied to: {dest_path}")
    
    while True:
        response = input("Copy this file? [y/n] ").strip().lower()
        if response in ('y', 'yes'):
            return True
        elif response in ('n', 'no'):
            return False
        print("Please answer 'y' or 'n'")

def copy_file_with_overwrite_check(source_path: str, dest_folder: str) -> bool:
    """Copy file to destination with overwrite check."""
    filename = os.path.basename(source_path)
    dest_path = os.path.join(dest_folder, filename)
    
    if os.path.exists(dest_path):
        print(f"Warning: {filename} already exists in destination!")
        while True:
            response = input("Overwrite? [y/n] ").strip().lower()
            if response in ('y', 'yes'):
                break
            elif response in ('n', 'no'):
                return False
            print("Please answer 'y' or 'n'")
    
    try:
        shutil.copy2(source_path, dest_path)
        print(f"Successfully copied to {dest_path}")
        return True
    except Exception as e:
        print(f"Error copying file: {e}")
        return False

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Find music files matching a tracklist.')
    parser.add_argument('directory', help='Directory to search for music files')
    parser.add_argument('--tracklist', default='tracklist.txt', help='Path to tracklist file')
    parser.add_argument('--output', help='Output file to write results to')
    parser.add_argument('--min-similarity', type=float, default=0.7, 
                       help='Minimum similarity threshold (0.0-1.0)')
    parser.add_argument('--auto-copy', action='store_true',
                       help='Automatically copy files without asking (use with caution)')
    
    args = parser.parse_args()
    
    # Get the folder containing the tracklist file
    tracklist_folder = os.path.dirname(os.path.abspath(args.tracklist))
    
    print(f"Reading tracklist from {args.tracklist}...")
    tracks = read_tracklist(args.tracklist)
    print(f"Found {len(tracks)} tracks in the tracklist.")
    
    print(f"Searching for music files in {args.directory}...")
    music_files = find_music_files(args.directory)
    print(f"Found {len(music_files)} music files to search through.")
    
    print("\nMatching tracks to files:")
    results = []
    copied_files = 0
    
    for artist, title in tracks:
        track = (artist, title)
        match = find_best_match(track, music_files, args.min_similarity)
        
        if match:
            status = f"FOUND: {match}"
            results.append(f"{artist} - {title}: {match}")
            
            if args.auto_copy or ask_user_permission(match, tracklist_folder):
                if copy_file_with_overwrite_check(match, tracklist_folder):
                    copied_files += 1
        else:
            status = "NOT FOUND"
            results.append(f"{artist} - {title}: NOT FOUND")
        
        print(f"{artist} - {title}: {status}")
    
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write("\n".join(results))
        print(f"\nResults written to {args.output}")
    
    print(f"\nOperation complete. Copied {copied_files} files to {tracklist_folder}")

if __name__ == '__main__':
    main()