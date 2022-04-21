import datetime
import os.path
import re
import shutil
from argparse import ArgumentParser

from tqdm import tqdm

import tts_deckgen.image_processing as ip
import tts_deckgen.save_processing as sp
from tts_deckgen.deck import Deck, DEFAULT_STAMP_IMAGE, DeckSheet, load_cards_info
from tts_deckgen.save_processing import SaveProcessor


def generate_deck(pics_dir, output_dir, no_rejected=False, tqdm_inst=None):
    if tqdm_inst is None:
        tqdm_inst = tqdm

    stamp_img = ip.download_img(DEFAULT_STAMP_IMAGE)
    info = []
    pics_fixed = []
    pics_face = []
    pics_back = None if no_rejected else []

    listdir = os.listdir(pics_dir)
    for f in tqdm_inst(listdir, total=len(listdir), unit='pic', desc='Preparing pictures'):
        if f.lower().split('.')[-1] in ['jpg', 'jpeg', 'png']:
            name = '.'.join(f.split('.')[0:-1])
            name = re.sub(r'\s*\[\d+]$', '', name)
            name = re.sub(r'^\[\d+]\s*', '', name)
            name = re.sub(r'^\(\d+\)\s*', '', name)
            name = re.sub(r'^\(\d+\)\s*', '', name)

            info.append({'Nickname': name})
            f = os.path.join(pics_dir, f)

            pics_face.append(ip.round_frame(f))
            fixed = ip.fix_ratio(f)
            pics_fixed.append(fixed)
            if pics_back is not None:
                pics_back.append(ip.stamp(fixed, stamp_img))

    print('DECK: grid')
    grid_deck = Deck.create(pics_face, back_images=pics_back, info=info, tqdm_inst=tqdm_inst)
    print('DECK: clean')
    clean_deck = Deck.create(pics_fixed, tqdm_inst=tqdm_inst, info=info)

    print('Saving...')
    os.makedirs(output_dir, exist_ok=True)
    for prefix, deck in (('grid', grid_deck), ('clean', clean_deck)):
        deck.save(output_dir, prefix)
        print(f'{prefix}: {deck.sheets_info()}')

    return grid_deck, clean_deck


def insert_urls(game_save, output, show=True):
    if show:
        from PIL import Image

    with open(game_save, 'r') as sav:
        sav = sav.read()
    buf = sav

    print('Enter URLs for prompted local files replacements.')
    print('URLs must be urlencoded already!')
    print('Type "abort" or "a" to abort')
    for f in os.listdir(output):
        if f.lower().split('.')[-1] not in ['png', 'jpg', 'jpeg']:
            print(f'Found not an image file ({f}), skipping...')
            continue
        fn = os.path.join(output, f)

        if show:
            img = Image.open(fn)
            img.show()

        print(f'Replacement for {f}')
        replacement = input('> ')

        if replacement in ['a', 'abort']:
            return

        fn = sp.to_file_path(fn).replace('\\', '\\\\')
        out = buf.replace(fn, replacement)
        if hash(out) != hash(buf):
            print('Success')
        else:
            print('Not found any occurrences of', fn)
        buf = out

    if hash(buf) != hash(sav):
        with open(game_save, 'w') as fout:
            fout.write(buf)
        print('Wrote modified file')


def load(deck_dir, prefix):
    return DeckSheet.load(deck_dir, prefix), load_cards_info(deck_dir, prefix)


def main():
    p = ArgumentParser()
    p.add_argument('-d', '--pics-dir', type=str, default=None, help='Directory to grab pictures from')
    p.add_argument('-D', '--deck-dir', type=str, default=None, help='Directory to load deck from. '
                                                                    'Must be output dir of run '
                                                                    'with -d option')
    p.add_argument('-u', '--insert-url', action='store_true', help='Enter interactive mode for changing files local '
                                                                   'dirs to URLs. Output dir will be used to iterate'
                                                                   'over files.'
                                                                   '--game-save must be set')
    p.add_argument('--fix', action='store_true', help='Restores save (-s option) to untouched state')

    p.add_argument('-o', '--output', type=str, default='output', help='Output dir')
    p.add_argument('-R', '--no-rejected', action='store_true', help='Do not generate "Rejected" as back')

    p.add_argument('-p', '--prefix', type=str, default='grid', help='Deck prefix for -D option. Can be "grid" or '
                                                                    '"clean", or any custom')

    p.add_argument('-s', '--game-save', type=str, default=None, help='Modify save file. Must be also set --guid option')
    p.add_argument('-g', '--guid', type=str, default=None, help='Target deck GUID in save')
    p.add_argument('-G', '--guid-clean', type=str, default=None, help='Target second (clean) deck')

    p.add_argument('-i', '--show-img', action='store_true', help='Show images for --insert-url interaction. '
                                                                 'Uses PIL.Image.Image.show()')

    args = p.parse_args()

    if args.game_save:
        if not os.path.isfile(args.game_save):
            raise AssertionError('--game-save does not represent a file')

    if args.fix:
        if not args.game_save:
            raise AssertionError('--game-save not set')

        bak = args.game_save + '.ttsdg.bak'
        if os.path.isfile(bak):
            print(f'Found untouched save, last modified: {datetime.datetime.fromtimestamp(os.path.getmtime(bak))}')

        else:
            bak = args.game_save + '.bak'
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
        return

    if args.deck_dir:
        if not os.path.isdir(args.deck_dir):
            raise AssertionError('--deck-dir does not represent a dir')
        if not args.game_save:
            raise AssertionError('--game-save not set')
        if not args.guid:
            raise AssertionError('--guid not set')

        deck = load(args.deck_dir, args.prefix)
        p = SaveProcessor(args.game_save)
        p.set_object(args.guid)
        p.write_decks(deck)

    elif args.pics_dir:
        if not os.path.isdir(args.pics_dir):
            raise AssertionError('--pics-dir does not represent a dir')

        grid, clean = generate_deck(args.pics_dir, args.output, args.no_rejected)

        if args.game_save:
            p = SaveProcessor(args.game_save)

            if args.guid:
                p.set_object(args.guid_clean)
                p.write_decks(grid)

            if args.guid_clean:
                p.set_object(args.guid_clean)
                p.write_decks(clean)

    if args.insert_url and args.game_save:
        insert_urls(args.game_save, args.output, args.show_img)


if __name__ == '__main__':
    main()
