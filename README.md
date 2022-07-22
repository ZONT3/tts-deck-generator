# TTS Deck Generator

Python tools for generating decks and uploading into game save

## Usage

```sh
python -m pip install -r requirements.txt
python run_dek_gen.py --help
```

### Sheet generation

1. Prepare dir with images. Filenames will be used as card nicknames in game.
   ***Tip**: use `[1]`, `[2]` ... `[n]` in start or end of filename for repeating names.
   This will be cropped on generation*
2. Run script: `python run_dek_gen.py -d input_dir` *use `-o` for specifying output dir*
3. You now have multiple sheets in output dir: clean (without overlay) and overlayed for GW game.

### Save injection

See steps 1-3 from above. Use option `-s PATH/TO/SAVE` for modifying a save.
Use option `-g GUID` to specify injection deck in game save. Can be comma-separated list, or just one.
Both options are replacing contents of deck in game (maybe appending will be implemented later) 
If you want to inject a single clean (without overlays) deck, you can use these options: `python -s PATH/TO/SAVE -p clean -g GUID`

## Usage examples

[Example images and attributes archive](https://disk.yandex.ru/d/cdFLHx24FUB7kA)

- Put images into `io/input-06/`
- Put attributes table into `io/sheet-06.xlsx`

### Sheet generation

```sh
python run_deck_gen.py -d io/input-06 -o io/output-06
```

This will generate sheets with (grid deck) and without (clean deck) overlays.

### Deck injection

- Have a save in TTS game with any two custom decks in ts. Copy its GUIDs.
For instance, we will take left and right decks from GW Scripted save: `c2a0c2`, `a785c2`.
Save number will be 7. For macOS its location is: `~/Library/Tabletop Simulator/Saves/TS_Save_7.json`.
Example path for Windows: `C:\Users\User\Documents\My Games\Tabletop Simulator\Saves\TS_Save_7.json`

- Have a generated sheets (example above)

```sh
python run_deck_gen.py -s ~/Library/Tabletop\ Simulator/Saves/TS_Save_7.json -D io/output-06 -g c2a0c2,a785c2
```

This will inject sheets ito a deck. If you don't wont to override original decks contents, you can use `-a` option:

```sh
python run_deck_gen.py -s ~/Library/Tabletop\ Simulator/Saves/TS_Save_7.json -D io/output-06 -g c2a0c2,a785c2 -a
```

**Note**

Decks will use your sheets as **local files**. 
You can use in-game feature **upload all to Steam Cloud**, 

***or***

Upload all .png files from output dir to any cloud **manually** and run following command:

```sh
python run_deck_gen.py -s ~/Library/Tabletop\ Simulator/Saves/TS_Save_7.json -o io/output-06 -u
```

You will be prompted to past a link to every sheet .png file.

### Attributes editing

You can generate `key: value` pairs in each mapped card description.

- Have a generated sheets (first example)
- Create .xlsx file by running following command:

```sh
python run_deck_gen.py -D io/output-06 -x io/table-06
```

You can now insert columns into Excel table and save it, or just use provided `sheet-06.xlsx` from downloaded achive and rename it.

B column in table is name of card in game (**not** binded to a filenames of images, can be changed to anything), 
A column is number of file in input dir in alphabet order (case insensetive, **binded** to that order).
C and any leftover columns is keys in descriptions, row values are values.
If value is equal `true`, then it will be just key in description, without any value.
Empty value in table will not include key name in card description.

After setting up attributes in Excel table, you can import it into output dir:

```sh
python run_deck_gen.py -D io/output-06 -X io/table-06.xlsx
```

And update decks in game save:

```sh
python run_deck_gen.py -s ~/Library/Tabletop\ Simulator/Saves/TS_Save_7.json -D io/output-06 -g c2a0c2,a785c2
```

Or do both actions in one command:

```sh
python run_deck_gen.py -s ~/Library/Tabletop\ Simulator/Saves/TS_Save_7.json -D io/output-06 -g c2a0c2,a785c2 -X io/table-06.xlsx
```

**Note 1**: You can override the whole deck in order to update attributes. If it's not ok, you can append new cards to it using `-a` option,
but you will have to delete old cards manually.

**Note 2**: Deck sheets will become **local files** again. Keep it in mind, if you are updating deck multiple times and use **upload all** in-game feature.
If you are using `-u` method (example above), it will be easier because you will not have to upload same files multiple times, and script offers you to re-use previous URLs.

### Discord scrapping

You can collect images from specified Discord channel, using script `run_discord_scrapping.py`

```sh
python run_discord_scrapping.py "YOUR_BOT_TOKEN" GUILD_ID CHANNEL_ID "22/07/15 00:00:00"`
```

This run will collect images from guild (server) with id `GUILD_ID`, channel `CHANNEL_ID`,
from messages with JPG/PNG attachements starting from Jul 15 2022.

Bot token can be generated [here](https://discord.com/developers/applications).
Also, your bot should be invited to your guild (server) and must have reading permissions in specified channel.

## TODO

- [x] Fix current bugs
  - [x] Broken deck insertion to save (when >69 pictures used)
  - [x] Broken 'Hidden' pic position behaviour in some cases ([a8d050e](https://github.com/ZONT3/tts-deck-generator/commit/a8d050e43e874a795ef8bf3255446ea9a4525e46), NEED TESTS)
  - [x] Unhandled 10x1 sheet creation (game supports minimum of 2 lines) ([a8d050e](https://github.com/ZONT3/tts-deck-generator/commit/a8d050e43e874a795ef8bf3255446ea9a4525e46), NEED TESTS)
- [x] Properties editing UI. *Implemented through Excel table import/export*
- [x] Local paths -> Link replacement CLI. *`-u` option*

**Cancelled features**

*Because of good existing alternatives*

- [ ] ~~Imgur integration option (instead of local file paths)~~ *Use **Upload All** in-game feature, or upload manually to steam cloud from game (or to any other hosting), and use `-u` option*

**Delayed features**

*Not sure, if they will ever be implemented*

- [ ] UI for cropping images
- [ ] UI for imageboard scrapping (goal is fast and in-place creation of properties and nicknames re-usage)

# Guess Who Scripted

Tabletop Simulator Gamemode.
[Link to Steam Workshop]()

## TODO

- [x] Guess Grid generation
  - [x] Pages implementation
  - [x] Pages switching controls
- [x] Picking phase
  - [ ] *Voting and host/promoted confirmation (**Delayed**)*
- [x] Group switches (for rejecting/flipping)
  - [x] Properties lists
- [ ] Pages enable/disable
- [ ] First workshop release

---

**Gamemode features**

- [ ] Win/lose conditions
- [ ] Auto-lose timer on wrong rejection (flipping) 
  - [ ] "All-in" guess option (player loses if he is wrong, or wins if isn't)
- [ ] Pre-game settings UI
  - [ ] Timer and auto-lose setup for wrong rejection
  - [ ] Enabling/disabling "All-in"
  - [ ] Enabling/disabling warning of wrong rejection in past minute (timer should be disabled)
  - [ ] In-game turns enable/disable

---

- [ ] Deck filtering
  - [ ] Filter by group
- [ ] Search field in picking phase (now implemented through deck 'search' in-game feature)
