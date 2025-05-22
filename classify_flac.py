import os
import subprocess
import argparse
from collections import defaultdict

def get_flac_info(file_path):
    """Extract bit depth, sample rate, and check for lossy artifacts."""
    try:
        cmd = [
            'ffprobe', '-v', 'error', '-select_streams', 'a:0',
            '-show_entries', 'stream=bits_per_raw_sample,sample_rate',
            '-of', 'default=noprint_wrappers=1:nokey=1', file_path
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        bits, sample_rate = result.stdout.strip().split('\n')[:2]
        bits = int(bits) if bits.isdigit() else 16  # Default to 16-bit if missing
        
        # Simplified lossy check (replace with Spek/LosslessAudioChecker for accuracy)
        is_lossy = False
        if int(sample_rate) >= 44100 and bits == 16:
            is_lossy = "Maybe (verify with Spek)"
        
        return {
            "file": file_path,
            "bit_depth": bits,
            "sample_rate": sample_rate,
            "is_lossy": is_lossy,
        }
    except Exception as e:
        return {"file": file_path, "error": str(e)}

def scan_directory(path):
    """Scan for FLAC files and group by album directory."""
    albums = defaultdict(list)
    for root, _, files in os.walk(path):
        flac_files = [f for f in files if f.lower().endswith('.flac')]
        if flac_files:
            album_path = os.path.relpath(root, start=path)
            for file in flac_files:
                full_path = os.path.join(root, file)
                albums[album_path].append(get_flac_info(full_path))
    return albums

def consolidate_album(album_tracks):
    """Check if all tracks in an album share the same metadata."""
    if not album_tracks:
        return None
    
    first_track = album_tracks[0]
    for track in album_tracks[1:]:
        if (track["bit_depth"] != first_track["bit_depth"] or
            track["sample_rate"] != first_track["sample_rate"] or
            track["is_lossy"] != first_track["is_lossy"]):
            return None  # Inconsistencies found
    
    return {  # Consolidated album info
        "bit_depth": first_track["bit_depth"],
        "sample_rate": first_track["sample_rate"],
        "is_lossy": first_track["is_lossy"],
        "tracks": len(album_tracks),
    }

def print_results(albums, output_format):
    if output_format == "csv":
        print("Album,Status,Bit Depth (bits),Sample Rate (Hz),Lossy-Sourced,Tracks")
        for album, tracks in albums.items():
            consolidated = consolidate_album(tracks)
            if consolidated:
                print(f'"{album}",Consolidated,{consolidated["bit_depth"]},{consolidated["sample_rate"]},{consolidated["is_lossy"]},{consolidated["tracks"]}')
            else:
                for track in tracks:
                    print(f'"{album}/{os.path.basename(track["file"])}",Individual,{track["bit_depth"]},{track["sample_rate"]},{track["is_lossy"]},1')
    else:  # List format
        for album, tracks in albums.items():
            consolidated = consolidate_album(tracks)
            if consolidated:
                print(f"\n[ALBUM] {album} (All {consolidated['tracks']} tracks):")
                print(f"  - Bit Depth: {consolidated['bit_depth']}-bit")
                print(f"  - Sample Rate: {consolidated['sample_rate']} Hz")
                print(f"  - Lossy-Sourced: {consolidated['is_lossy']}")
            else:
                print(f"\n[ALBUM] {album} (Inconsistent tracks):")
                for track in tracks:
                    print(f"  - {os.path.basename(track['file'])}: {track['bit_depth']}-bit, {track['sample_rate']} Hz, Lossy? {track['is_lossy']}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Classify FLAC files by album, consolidating identical metadata.")
    parser.add_argument("directory", help="Directory to scan recursively")
    parser.add_argument("--format", choices=["list", "csv"], default="list", help="Output format (list or CSV)")
    args = parser.parse_args()

    albums = scan_directory(args.directory)
    print_results(albums, args.format)