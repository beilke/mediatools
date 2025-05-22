import os
import shutil

# Specify the source directory containing the files
source_dir = r"Y:\-- MP3 HQ\VA\The Definitive Horror Music Collection (2009) [320]"

# Define the destination directory
destination_dir = r"Y:\-- MP3 HQ\Renamed Files"

# Ensure the destination directory exists
if not os.path.exists(destination_dir):
    os.makedirs(destination_dir)

# List of CDs and their tracks
track_list = [
    ('CD 1', [
        ('01', 'Drag Me to Hell - End Titles (Original Version)', 'Christopher Young'),
        ('02', 'Twilight - Edward at Her Bed (Bella\'s Lullaby)', 'Carter Burwell'),
        ('03', 'Let the Right One In - Eli\'s Theme', 'Johan Söderqvist'),
        ('04', 'Cloverfield - Roar!', 'Michael Giacchino'),
        ('05', 'Sunshine - Adagio in D Minor', 'John Murphy'),
        ('06', 'Zodiac - Graysmith\'s Theme', 'David Shire'),
        ('07', 'Dexter - Main Title', 'Rolfe Kent'),
        ('08', 'Pan\'s Labyrinth - The Labyrinth', 'Javier Navarrete'),
        ('09', 'King Kong - King Kong Suite', 'James Newton Howard'),
        ('10', 'War of the Worlds - Suite', 'John Williams'),
        ('11', 'Saw - Hello Zep', 'Charlie Clouser'),
        ('12', '28 Days Later - In the House - In a Heartbeat', 'John Murphy'),
        ('13', 'The Ring - This is Going to Hurt', 'Hans Zimmer'),
        ('14', 'The Mummy Returns - Main Theme', 'Alan Silvestri'),
        ('15', 'Hannibal - Vide Cor Meum', 'Patrick Cassidy')
    ]),
    ('CD 2', [
        ('01', 'The Mummy - The Sand Volcano Z Love Theme', ''),
        ('02', 'Sleepy Hollow - End Titles', 'Danny Elfman'),
        ('03', 'The Haunting - The Carousel Z End Titles', ''),
        ('04', 'The Sixth Sense - Malcolm is Dead', 'James Newton Howard'),
        ('05', 'Buffy the Vampire Slayer - Theme', 'Nerf Herder'),
        ('06', 'Village of the Damned - March of the Children', 'John Carpenter'),
        ('07', 'Bram Stoker\'s Dracula - The Storm', 'Wojciech Kilar'),
        ('08', 'Army of Darkness (Evil Dead II - Prologue Z Building the Deathc', ''),
        ('09', 'The Witches of Eastwick - Dance of the Witches', 'John Williams'),
        ('10', 'Predator - Main Theme', 'Alan Silvestri'),
        ('11', 'Hellraiser - Suite', 'Christopher Young'),
        ('12', 'HellboundZ Hellraiser II - Suite', ''),
        ('13', 'They Live - Main Theme', 'John Carpenter'),
        ('14', 'Aliens - Prelude Z Ripley\'s Rescue', ''),
        ('15', 'Ghostbusters - Main Theme', 'Ray Parker Jr.')
    ]),
    ('CD 3', [
        ('01', 'A Nightmare on Elm Street - Main Theme', 'Charles Bernstein'),
        ('02', 'Christine - Bad to the Bone', 'George Thorogood & The Destroyers'),
        ('03', 'Poltergeist - Main Theme', 'Jerry Goldsmith'),
        ('04', 'The Thing - Main Theme', 'Ennio Morricone'),
        ('05', 'Halloween II - Main Theme', 'John Carpenter & Alan Howarth'),
        ('06', 'The Fog - Main Theme', 'John Carpenter'),
        ('07', 'Dressed to Kill - The Gallery', 'Pino Donaggio'),
        ('08', 'The Shining - Music for Strings, Percussion', ''),
        ('09', 'Dracula - Main Titles Z Storm', ''),
        ('10', 'Phantasm - Main Theme', 'Fred Myrow & Malcolm Seagrave'),
        ('11', 'Alien - End Title', 'Jerry Goldsmith'),
        ('12', 'Halloween - Main Theme', 'John Carpenter'),
        ('13', 'The Fury - Main Theme', 'John Williams'),
        ('14', 'Suspiria - Main Theme', 'Goblin'),
        ('15', 'Exorcist IIZ The Heretic - Regan\'s Theme', '')
    ]),
    ('CD 4', [
        ('01', 'The Omen - Ave Satani', 'Jerry Goldsmith'),
        ('02', 'Young Frankenstein - Transylvanian Lullaby', 'John Morris'),
        ('03', 'The Exorcist - Tubular Bells', 'Mike Oldfield'),
        ('04', 'Duel - The Cafe Z Truck Attack', ''),
        ('05', 'Taste the Blood of Dracula - The Young Lovers Z Ride to the', ''),
        ('06', 'Rosemary\'s Baby - Lullaby', 'Krzysztof Komeda'),
        ('07', 'Twisted Nerve - Suite', 'Bernard Herrmann'),
        ('08', 'The Devil Rides Out - The Power of Evil', 'James Bernard'),
        ('09', 'Dracula, Prince of Darkness - Suite', 'James Bernard'),
        ('10', 'The Haunting - The History of Hill House', 'Humphrey Searle'),
        ('11', 'Dracula - Main Title Z Finale', ''),
        ('12', 'Horrors of the Black Museum - Main Theme', 'Gerard Schurmann'),
        ('13', 'The Thing from Another World - Main Theme', 'Dimitri Tiomkin'),
        ('14', 'Bride of Frankenstein - Creation of the Female Monster', 'Franz Waxman'),
        ('15', 'Nosferatu - Overture', 'Hans Erdmann')
    ])
]

# Iterate over each CD and its tracks
for cd, tracks in track_list:
    # Remove the 'CD ' prefix from the cd string (e.g., "CD 1" -> "1")
    cd_number = cd.replace("CD ", "")
    
    for track in tracks:
        track_number, track_title, composer = track
        # Correct special characters in track titles (e.g., replace underscores with spaces)
        track_title = track_title.replace('_', ' ')
        # Construct the source and destination filenames
        source_filename = os.path.join(source_dir, f"{cd}\\{track_number}. {track_title}.mp3")
        destination_filename = os.path.join(destination_dir, f"{cd_number}{track_number} - {track_title} - {composer}.mp3" if composer else f"{cd_number} {track_number} - {track_title}.mp3")

        # Ensure the destination directory exists for each track
        if not os.path.exists(os.path.dirname(destination_filename)):
            os.makedirs(os.path.dirname(destination_filename))

        # Copy the file if it exists
        if os.path.exists(source_filename):
            shutil.copy(source_filename, destination_filename)
            print(f"Copied: {source_filename} to {destination_filename}")
        else:
            print(f"File not found: {source_filename}")
