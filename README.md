# TTS Deck Generator

Python tools for generating decks and uploading into game save

## Usage

`python run_dek_gen.py --help`

### Sheet generation

1. Prepare dir with images. Filenames will be later exported as card nicknames in game.
   ***Tip**: use `[1]`, `[2]` ... `[n]` in start or end of filename for repeating names.
   This will be cropped on generation*
2. Run script: `python run_dek_gen.py -d input_dir` *use `-o` for specifying output dir*
3. You now have multiple sheets in output dir: clean (without overlay) and overlayed for GW game.

### Save injection

See steps 1-3 from above. Use option `-s PATH/TO/SAVE` for modifying a save.
Use option `-g GUID` for injection `grid_sheet` into deck in save, specified by GUID.
Use option `-G GUID` for injection `clean_sheet` into another deck in save.
Both options are replacing contents of deck in game (maybe appending will be implemented later) 

## TODO

- [x] Fix current bugs
  - [x] Broken deck insertion to save (when >69 pictures used)
  - [x] Broken 'Hidden' pic position behaviour in some cases ([a8d050e](https://github.com/ZONT3/tts-deck-generator/commit/a8d050e43e874a795ef8bf3255446ea9a4525e46), NEED TESTS)
  - [x] Unhandled 10x1 sheet creation (game supports minimum of 2 lines) ([a8d050e](https://github.com/ZONT3/tts-deck-generator/commit/a8d050e43e874a795ef8bf3255446ea9a4525e46), NEED TESTS)
- [ ] Properties editing UI (CLI for now)
- [x] Local paths -> Link replacement UI (CLI for now)
- [ ] imgur integration option (instead of local file paths)
- [ ] UI for cropping images
- [ ] UI for imageboard scrapping (goal is fast and in-place creation of properties and nicknames re-usage)

# Guess Who Scripted

Tabletop Simulator Game (will be uploaded to workshop as soon as milestones reached)

## TODO

- [x] Guess Grid generation
  - [x] Pages implementation
  - [x] Pages switching controls
- [x] Picking phase
  - [ ] Voting and host/promoted confirmation
- [ ] Built-in turns usage
- [ ] First workshop release
---
- [ ] "All-in" guess option
  - [ ] Win/lose conditions
  - [ ] Auto-lose timer on wrong rejection (flipping) 
- [ ] Group switches (for rejecting/flipping)
  - [ ] Properties lists
- [ ] Pre-game settings UI
  - [ ] Timer and auto-lose setup for wrong rejection
  - [ ] Enabling/disabling "All-in"
  - [ ] Enabling/disabling warning of wrong rejection in past minute (timer should be disabled)
  - [ ] In-game turns enable/disable
- [ ] Second Workshop release
---
- [ ] Deck filtering
  - [ ] Filter by group
- [ ] Search field in picking phase
- [ ] Integration with python part of project
- [ ] Final workshop release
