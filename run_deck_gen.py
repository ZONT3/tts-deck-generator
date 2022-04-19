import os.path
from argparse import ArgumentParser

from tqdm import tqdm

from deck import Deck, DEFAULT_STAMP_IMAGE
import image_processing as ip


def generate_deck(pics_dir, no_rejected, output_dir):
    stamp_img = ip.download_img(DEFAULT_STAMP_IMAGE)
    pics = []
    pics_fixed = []
    pics_face = []
    pics_back = None if no_rejected else []
    for f in tqdm(os.listdir(pics_dir), unit='pic', desc='Preparing pictures'):
        if f.lower().split('.')[-1] in ['jpg', 'jpeg', 'png']:
            f = os.path.join(pics_dir, f)

            pics.append(f)
            pics_face.append(ip.round_frame(f))

            fixed = ip.fix_ratio(f)
            pics_fixed.append(fixed)
            if pics_back is not None:
                pics_back.append(ip.stamp(fixed, stamp_img))
    print('DECK: grid')
    grid_deck = Deck.create(pics_face, back_images=pics_back)
    print('DECK: clean')
    clean_deck = Deck.create(pics_fixed)
    print('Saving...')
    os.makedirs(output_dir, exist_ok=True)
    for prefix, deck in (('grid', grid_deck), ('clean', clean_deck)):
        deck.save(deck, output_dir, prefix)
        print(f'{prefix}: {deck.sheets_info()}')

    return grid_deck, clean_deck


if __name__ == '__main__':
    p = ArgumentParser()
    p.add_argument('-d', '--pics-dir', type=str, default=None, help='Directory to grab pictures from')
    p.add_argument('-R', '--no-rejected', action='store_true', help='Do not generate "Rejected" as back')
    p.add_argument('-o', '--output', type=str, default='output', help='Output dir')
    args = p.parse_args()

    if args.pics_dir:
        if not os.path.isdir(args.pics_dir):
            raise AssertionError('pics-dir does not represent a dir')

        generate_deck(args.pics_dir, args.no_rejected, args.output)
