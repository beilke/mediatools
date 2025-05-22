#!/usr/bin/env python3
"""
Organize FLAC speaker test songs with standardized naming (Artist - Title).

Usage:
    python organize_speaker_test_songs.py "source_directory" "destination_directory"
"""

import os
import shutil
import re
from fuzzywuzzy import fuzz
from datetime import datetime
import mutagen.flac

# Bang & Olufsen recommended songs by category
GROUPINGS = {
    "To Test Overall Balance": [
        ("Billie Eilish", "Bad Guy"),
        ("Lorde", "Royals"),
        ("The White Stripes", "Seven Nation Army"),
        ("Childish Gambino", "Redbone")
    ],
    "To Test Bass Response": [
        ("Stevie Wonder", "Superstition"),
        ("Mark Ronson ft. Bruno Mars", "Uptown Funk"),
        ("Michael Jackson", "Billie Jean"),
        ("Kendrick Lamar", "HUMBLE.")
    ],
    "To Test Vocal Clarity": [
        ("Adele", "Someone Like You"),
        ("Jeff Buckley", "Hallelujah"),
        ("Fleetwood Mac", "Landslide"),
        ("Sam Smith", "Stay With Me")
    ],
    "To Test Dynamic Range": [
        ("Queen", "Bohemian Rhapsody"),
        ("Dave Brubeck Quartet", "Take Five"),
        ("Led Zeppelin", "Stairway to Heaven"),
        ("Leonard Cohen", "Bird on a Wire")
    ],
    "To Test Stereo Imaging": [
        ("Pink Floyd", "Money"),
        ("Eagles", "Hotel California"),
        ("Guns N' Roses", "Sweet Child O' Mine"),
        ("Yosi Horikawa", "Bubbles")
    ]
}

def clean_filename(name):
    """Remove invalid characters from filenames."""
    return re.sub(r'[<>:"/\\|?*]', '', name)

def get_audio_quality(file_path):
    """Get quality metrics from FLAC file."""
    try:
        audio = mutagen.flac.FLAC(file_path)
        return {
            'bit_depth': audio.info.bits_per_sample,
            'sample_rate': audio.info.sample_rate,
            'channels': audio.info.channels,
            'file_size': os.path.getsize(file_path),
            'duration': audio.info.length
        }
    except:
        return None

def find_best_flac_matches(source_dir):
    """Find best quality FLAC matches for recommended songs."""
    song_matches = {}
    
    # First pass: find all potential matches
    potential_matches = {}
    for root, _, files in os.walk(source_dir):
        for file in files:
            if file.lower().endswith('.flac'):
                file_path = os.path.join(root, file)
                filename_no_ext = os.path.splitext(file)[0]
                
                for group, songs in GROUPINGS.items():
                    for artist, title in songs:
                        full_name = f"{artist} - {title}"
                        similarity = max(
                            fuzz.token_set_ratio(filename_no_ext.lower(), full_name.lower()),
                            fuzz.token_set_ratio(filename_no_ext.lower(), title.lower())
                        )
                        if similarity > 70:
                            if full_name not in potential_matches:
                                potential_matches[full_name] = []
                            potential_matches[full_name].append({
                                'file_path': file_path,
                                'similarity': similarity,
                                'group': group,
                                'artist': artist,
                                'title': title
                            })
    
    # Second pass: select best version of each match
    for full_name, matches in potential_matches.items():
        # Only consider matches with >80% similarity
        good_matches = [m for m in matches if m['similarity'] > 80]
        if not good_matches:
            continue
        
        # Get quality info for all matches
        for match in good_matches:
            match['quality'] = get_audio_quality(match['file_path']) or {}
        
        # Sort by quality metrics
        good_matches.sort(key=lambda x: (
            x['quality'].get('bit_depth', 0),
            x['quality'].get('sample_rate', 0),
            x['quality'].get('file_size', 0)
        ), reverse=True)
        
        best_match = good_matches[0]
        group = best_match['group']
        
        if group not in song_matches:
            song_matches[group] = []
        
        song_matches[group].append({
            'artist': best_match['artist'],
            'title': best_match['title'],
            'original_path': best_match['file_path'],
            'original_name': os.path.basename(best_match['file_path']),
            'similarity': best_match['similarity'],
            'quality': best_match['quality']
        })
    
    return song_matches

def organize_flac_songs(matches, destination_dir):
    """Organize matched FLAC files with standardized naming."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = os.path.join(destination_dir, f"FLAC_SpeakerTest_{timestamp}")
    os.makedirs(output_dir, exist_ok=True)
    
    reference_file = os.path.join(output_dir, "00_Quality_Reference.txt")
    
    with open(reference_file, 'w', encoding='utf-8') as f:
        f.write("FLAC Speaker Test - Best Quality Selection\n")
        f.write(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        
        for group, matched_files in matches.items():
            group_folder = os.path.join(output_dir, group.replace(" ", "_"))
            os.makedirs(group_folder, exist_ok=True)
            
            f.write(f"\n=== {group} ===\n")
            f.write("Recommended Songs:\n")
            for artist, title in GROUPINGS[group]:
                f.write(f"- {artist} - {title}\n")
            
            f.write("\nSelected Best Versions:\n")
            for match in matched_files:
                # Create standardized filename
                clean_artist = clean_filename(match['artist'])
                clean_title = clean_filename(match['title'])
                new_filename = f"{clean_artist} - {clean_title}.flac"
                dest_path = os.path.join(group_folder, new_filename)
                
                # Copy file with new name
                shutil.copy2(match['original_path'], dest_path)
                
                # Write to reference file
                f.write(f"\n* {match['artist']} - {match['title']}\n")
                f.write(f"  Original: {match['original_name']}\n")
                f.write(f"  New Name: {new_filename}\n")
                f.write(f"  Similarity: {match['similarity']}%\n")
                f.write(f"  Quality: {match['quality'].get('bit_depth', '?')}bit/"
                      f"{match['quality'].get('sample_rate', '?')/1000:.1f}kHz/"
                      f"{match['quality'].get('channels', '?')}ch\n")
                f.write(f"  Duration: {match['quality'].get('duration', 0):.2f}s\n")
                f.write(f"  Source: {match['original_path']}\n")
                f.write(f"  Copied To: {dest_path}\n")
    
    return output_dir

def main():
    import sys
    
    if len(sys.argv) != 3:
        print('Usage: python organize_speaker_test_songs.py "source_directory" "destination_directory"')
        print('Note: Paths with spaces or special characters must be quoted')
        sys.exit(1)
    
    source_dir = os.path.abspath(sys.argv[1])
    destination_dir = os.path.abspath(sys.argv[2])
    
    if not os.path.isdir(source_dir):
        print(f"Error: Source directory does not exist: {source_dir}")
        sys.exit(1)
    
    print("Searching for best FLAC matches...")
    matches = find_best_flac_matches(source_dir)
    
    if not matches:
        print("No suitable FLAC matches found!")
        return
    
    print("\nOrganizing files with standardized naming...")
    output_dir = organize_flac_songs(matches, destination_dir)
    
    print("\nOrganization complete!")
    print(f"Results saved to: {output_dir}")
    print("Quality reference file created: 00_Quality_Reference.txt")

if __name__ == "__main__":
    main()