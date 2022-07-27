import datetime
import os.path
import re
import shutil
from argparse import ArgumentParser
from typing import Optional

from PIL import Image, ImageColor
import json
from tqdm import tqdm

import tts_deckgen.image_processing as ip
import tts_deckgen.save_processing as sp
import tts_deckgen.deck as d
import tts_deckgen.properties_editor as pe
import tts_deckgen.properties_editor_legacy as pel
from tts_deckgen.save_processing import SaveProcessor


def generate_deck(pics_dir, output_dir, no_rejected=False, tqdm_inst=None, bg_color: Optional[str] = 'FFFFFF'):
    if tqdm_inst is None:
        tqdm_inst = tqdm

    if bg_color is not None:
        bg_color = ImageColor.getrgb(f'#{bg_color.lower()}ff')

    stamp_img = ip.download_img(d.DEFAULT_STAMP_IMAGE)
    info = []
    pics_fixed = []
    pics_face = []
    pics_back = None if no_rejected else []

    listdir = pe.norm_sort(os.listdir(pics_dir))
    for f in tqdm_inst(listdir, total=len(listdir), unit='pic', desc='Preparing pictures'):
        if ip.check_supported_ext(f):
            name = '.'.join(f.split('.')[0:-1])
            name = re.sub(r'\s*\[\d+]$', '', name)
            name = re.sub(r'^\[\d+]\s*', '', name)
            name = re.sub(r'\s*\(\d+\)$', '', name)
            name = re.sub(r'^\(\d+\)\s*', '', name)

            info.append({'Nickname': name})
            f = os.path.join(pics_dir, f)

            pics_face.append(ip.round_frame(f))
            fixed = ip.fix_ratio(f)
            pics_fixed.append(fixed)
            if pics_back is not None:
                pics_back.append(ip.stamp(fixed, stamp_img))

    print('DECK: grid')
    grid_deck = d.Deck.create(pics_face, back_images=pics_back, info=info, tqdm_inst=tqdm_inst, bg_color=bg_color)
    print('DECK: clean')
    clean_deck = d.Deck.create(pics_fixed, tqdm_inst=tqdm_inst, info=info, bg_color=bg_color)

    print('Saving...')
    os.makedirs(output_dir, exist_ok=True)
    for prefix, deck in (('grid', grid_deck), ('clean', clean_deck)):
        deck.save(output_dir, prefix, 'grid' == prefix)
        print(f'{prefix}: {deck.sheets_info()}')

    return grid_deck, clean_deck


def yes_no_interact():
    yn = input('([y]/n): ')
    while True:
        if yn.lower() in ('y', '', 'yes'):
            return True
        elif yn.lower() in ('n', 'no'):
            return False
        yn = input('! [y]/n: ')


def insert_urls(game_save, output, show=True):
    with open(game_save, 'r') as sav:
        sav = sav.read()
    buf = sav

    saved_replacement = os.path.join(output, '.url_replace.json')
    files = [f for f in os.listdir(output) if ip.check_supported_ext(f)]
    replacements = {}

    if os.path.isfile(saved_replacement):
        with open(saved_replacement) as f:
            found = json.load(f)
        if len(files) == len(found):
            for k, v in found.items():
                print(f'{k} -> {v}')
            print('Found these replacements. Would you like to use it?', end=' ')
            if yes_no_interact():
                replacements = found

    read = len(replacements) > 0
    if not read:
        print('Enter URLs for prompted local files replacements.')
        print('URLs must be urlencoded already!')
        print('Type "abort" or "a" to abort')
    for f in files:
        fn = os.path.join(output, f)

        if not read:
            if show:
                img = Image.open(fn)
                img.show()

            print(f'Replacement for {f}')
            replacement = input('> ')

            if replacement in ['a', 'abort']:
                return
            if 'https://imgur.com/' in replacement and replacement.lower().split('.')[-1] not in ['jpg', 'png', 'jpeg']:
                replacement += '.png'

        else:
            replacement = replacements[f]
            print(f'{f} -> \'{replacement}\'', end=': ')

        fn = sp.to_file_path(fn).replace('\\', '\\\\')
        out = buf.replace(fn, replacement)
        if hash(out) != hash(buf):
            if not read:
                replacements[f] = replacement
            print('Success')
        else:
            print('Not found any occurrences of', fn)
        buf = out

    if hash(buf) != hash(sav):
        with open(game_save, 'w') as fout:
            fout.write(buf)
        print('Wrote modified file')
        if not read:
            with open(saved_replacement, 'w') as f:
                json.dump(replacements, f)


def import_excel(args, cards, prefix):
    _, ch = pe.import_excel(args.import_excel, cards)
    if len(ch) > 0:
        for x in ch:
            old, new = x
            print(f'\'{old}\' -> \'{new}\'')
        print(f'Some names have been changed ({len(ch)}). If this number is too big, wrong data '
              'might be in the imported file.\nContinue?', end=' ')
        if not yes_no_interact():
            return
    d.save_cards_info(cards, args.deck_dir, prefix)


def export_excel(xlsx, cards):
    pe.export_excel(xlsx, cards)


def merge_cards(deck_dir, prefix, into, from_fp):
    with open(from_fp) as fp:
        src = json.load(fp)

    add = {}
    for c in src:
        if 'Nickname' not in c or 'Properties' not in c:
            continue
        for idx, cc in enumerate(into):
            if 'Nickname' in cc and cc['Nickname'] == c['Nickname']:
                break
        else:
            continue

        add[idx] = c['Properties']

    pel.write_changes(d.cards_info_json(deck_dir, prefix), into, add, {})


def parse_args():
    p = ArgumentParser()
    p.add_argument('-d', '--pics-dir', type=str, default=None, help='Directory to grab pictures from')
    p.add_argument('-D', '--deck-dir', type=str, default=None,
                   help='Directory to load deck from. Must be output dir of run with -d option')
    p.add_argument('-u', '--insert-url', action='store_true',
                   help='Enter interactive mode for changing files local dirs to URLs. '
                        'Output dir will be used to iterate over files. --game-save must be set')
    p.add_argument('-e', '--expansion', type=str, default=None, help='Expands deck and input dir with new images, '
                                                                     'properly handling properties. Must be dir with '
                                                                     'images and both valid -D and -d options used')
    p.add_argument('--properties-legacy', action='store_true',
                   help='Enter properties editor mode. Allows you to interactively edit card\'s properties. '
                        'Saved deck must be set. Game save and guid are optional. (-D, -s, -g options respectively).')
    p.add_argument('--fix', action='store_true', help='Restores save (-s option) to untouched state')

    p.add_argument('-m', '--merge', type=str, default=None,
                   help='Merges specified card info JSON file into deck dir specified with -D option')
    p.add_argument('-x', '--export-excel', type=str, default=None,
                   help='Exports specified (-D) deck cards properties to excel. '
                        'Output excel file can be modified and imported using -X option')
    p.add_argument('-X', '--import-excel', type=str, default=None,
                   help='Imports specified excel file into deck (-D). See -x option for more info.')

    p.add_argument('-o', '--output', type=str, default='output', help='Output dir')
    p.add_argument('-R', '--no-rejected', action='store_true', help='Do not generate "Rejected" as back')

    p.add_argument('-p', '--prefix', type=str, default='grid,clean',
                   help='Deck prefix for -D and/or -P option. Will be prefix for info JSON files. '
                        'Can be comma-separated list, '
                        'only has effect if list size is equal to guid (-g) list.')

    p.add_argument('-s', '--game-save', type=str, default=None, help='Modify save file. Must be also set --guid option')
    p.add_argument('-g', '--guid', type=str, default=None,
                   help='Target deck GUID in save. Can be comma-separated list.')
    p.add_argument('-a', '--append', action='store_true', help='Append to deck in save instead of overwrite')

    p.add_argument('-i', '--show-img', action='store_true', help='Show images for --insert-url or --expand '
                                                                 'interaction. '
                                                                 'Uses PIL.Image.Image.show()')
    p.add_argument('-c', '--copy-expand', action='store_true', help='Copy image in --expand mode, instead of moving')
    p.add_argument('--bg-color', type=str, default='FFFFFF', help='Background color (HEX 6 digits only, like AABBCC) '
                                                                  'for replacing transparency.')
    p.add_argument('--keep-transparency', action='store_true', help='Keep transparency. Overrides --bg-color option.')

    return p.parse_args()


def main():
    args = parse_args()

    if args.keep_transparency:
        args.bg_color = None

    if args.game_save:
        if not os.path.isfile(args.game_save):
            raise AssertionError('--game-save does not represent a file')

    if args.fix:
        if not args.game_save:
            raise AssertionError('--game-save not set')

        bak = args.game_save + '.ttsdg.bak'
        bak_fallback = args.game_save + '.bak'

        if os.path.isfile(bak):
            print(f'Found untouched save, last modified: {datetime.datetime.fromtimestamp(os.path.getmtime(bak))}')

        else:
            bak = bak_fallback
            if os.path.isfile(bak):
                print(f'Not found save in untouched state, but found backup, last modified: '
                      f'{datetime.datetime.fromtimestamp(os.path.getmtime(bak))}')
                ans = input('Would you like to use it? (y/other): ')
                if not ans.startswith('y'):
                    return

            else:
                print('Not found any backup')
                return

        os.remove(args.game_save)
        shutil.copy(bak, args.game_save)
        shutil.copy(bak, bak_fallback)
        os.remove(bak)
        return

    if args.expansion:
        if not os.path.isdir(args.deck_dir):
            raise AssertionError('--deck-dir does not represent a dir')
        if not os.path.isdir(args.expansion):
            raise AssertionError('--expansion does not represent a dir')
        if not os.path.isdir(args.pics_dir):
            raise AssertionError('--pics-dir does not represent a dir')

        prefixes = [p for p in args.prefix.split(',') if os.path.isfile(d.cards_info_json(args.deck_dir, p))]

        if len(prefixes) == 0:
            raise AssertionError('Blank prefixes')
        prefix = prefixes[0]

        pe.properties_editor(args.deck_dir, args.pics_dir, args.expansion, prefix, args.show_img, args.copy_expand)

        if len(prefixes) > 1:
            src = d.cards_info_json(args.deck_dir, prefix)
            for p in prefixes[1:]:
                shutil.copy(src, d.cards_info_json(args.deck_dir, p))
        return

    if args.deck_dir:
        if not os.path.isdir(args.deck_dir):
            raise AssertionError('--deck-dir does not represent a dir')
        if not args.guid and args.game_save:
            raise AssertionError('--guid not set')

        prefix_list = args.prefix.split(',')
        cards = d.load_cards_info(args.deck_dir, prefix_list[0])
        save = True

        if args.merge:
            if not os.path.isfile(args.merge):
                raise ValueError('--merge is not a file. Must be a cards info JSON.')
            merge_cards(args.deck_dir, prefix_list[0], cards, args.merge)

        elif args.export_excel:
            export_excel(args.export_excel, cards)
            return

        elif args.import_excel:
            import_excel(args, cards, prefix_list[0])

        elif args.properties:
            sheets = d.DeckSheet.load(args.deck_dir, prefix_list[0])
            save, add, rm = pel.edit_properties(sheets, cards)
            if save:
                for prefix in prefix_list:
                    pel.write_changes(d.cards_info_json(args.deck_dir, prefix), cards, add, rm)
                    break

        else:
            if not args.game_save:
                raise AssertionError('--game-save not set')

        if save and args.game_save:
            guids = args.guid.split(',')
            for i, guid in enumerate(guids):
                deck = d.DeckSheet.load(args.deck_dir, prefix_list[i if len(prefix_list) > i else 0])
                if len(guids) == len(prefix_list) and i > 0:
                    if os.path.isfile(d.cards_info_json(args.deck_dir, prefix_list[i])):
                        cards = d.load_cards_info(args.deck_dir, prefix_list[i])
                p = SaveProcessor(args.game_save)
                p.set_object(guid, append_content=args.append)
                p.write_decks((deck, cards))

    elif args.pics_dir:
        if not os.path.isdir(args.pics_dir):
            raise AssertionError('--pics-dir does not represent a dir')

        grid, clean = generate_deck(args.pics_dir, args.output, no_rejected=args.no_rejected, bg_color=args.bg_color)

        if args.game_save:
            p = SaveProcessor(args.game_save)

            if args.guid:
                decks = (grid, clean)
                guids = args.guid.split(',')
                for i, guid in enumerate(guids):
                    if i > 1:
                        break
                    p.set_object(guid, append_content=args.append)
                    p.write_decks(decks[i])

    if args.insert_url:
        if not args.game_save:
            raise AssertionError('--game-save not set')
        insert_urls(args.game_save, args.output, args.show_img)


if __name__ == '__main__':
    main()
