import os.path
from argparse import ArgumentParser

from tqdm import tqdm

from deck import Deck
import deck
import image_processing as ip


if __name__ == '__main__':
    p = ArgumentParser()
    p.add_argument('--pics-dir', type=str, default=None, help='Directory to grab pictures from')
    p.add_argument('--no-rejected', action='store_true', help='Do not generate "Rejected" as back')
    p.add_argument('--output', type=str, default='output', help='Output dir')

    args = p.parse_args()

    if args.pics_dir:
        if not os.path.isdir(args.pics_dir):
            raise AssertionError('pics-dir does not represent a dir')

        stamp_img = ip.download_img(deck.DEFAULT_STAMP_IMAGE)

        pics = []
        pics_fixed = []
        pics_face = []
        pics_back = None if args.no_rejected else []
        for f in tqdm(os.listdir(args.pics_dir), unit='pic', desc='Preparing pictures'):
            if f.lower().split('.')[-1] in ['jpg', 'jpeg', 'png']:
                f = os.path.join(args.pics_dir, f)

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
        os.makedirs(args.output, exist_ok=True)
        for prefix, deck in (('grid', grid_deck), ('clean', clean_deck)):
            for i, s in enumerate(deck.sheets):
                s.save(os.path.join(args.output, f'{prefix}_sheet_{i:02d}.png'))

            if deck.back_sheets is not None:
                for i, s in enumerate(deck.back_sheets):
                    s.save(os.path.join(args.output, f'{prefix}_back_{i:02d}.png'))
            else:
                deck.back_img.save(os.path.join(args.output, f'{prefix}_back.png'))

            print(f'{prefix}: {deck.sheets_info()}')
