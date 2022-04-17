import math
from typing import List, Union, Any, Tuple

from PIL import Image as Image
from PIL.Image import Image as PILImage
from tqdm import tqdm

import image_processing as ip

MAX_SHEET_WIDTH = 10
MAX_SHEET_HEIGHT = 7
DEFAULT_BACK_IMAGE = 'https://imgur.com/zRv5iaf.png'
DEFAULT_HIDE_IMAGE = 'https://imgur.com/oxP7UZY.png'
DEFAULT_STAMP_IMAGE = 'https://imgur.com/j9789mk.png'
MARGIN = 0


class Deck:
    sheets_sizes: List[Tuple[int, int, int]]
    sheets: List[PILImage]
    back_img: Union[PILImage, List[PILImage]]
    has_hide_img: bool
    back_sheets: Union[List[PILImage], Any]

    def __init__(self,
                 sheets: List[PILImage],
                 back_img: Union[PILImage],
                 back_sheets: Union[List[PILImage], Any],
                 has_hide_img: bool,
                 sheets_sizes: List[Tuple[int, int, int]]):
        self.sheets = sheets
        self.back_img = back_img
        self.back_sheets = back_sheets
        self.has_hide_img = has_hide_img
        self.sheets_sizes = sheets_sizes

    def sheets_info(self):
        res = []
        for w, h, c in self.sheets_sizes:
            res.append(f'({w}x{h}): {c}')
        return ', '.join(res)

    @classmethod
    def create(cls, images: List[PILImage], back_img=None, back_images=None, insert_hide=True, hide_img=None,
               sheet_width=MAX_SHEET_WIDTH, sheet_height=MAX_SHEET_HEIGHT, maxw=720, enable_tqdm=True):

        if insert_hide and hide_img is None:
            hide_img = ip.download_img(DEFAULT_HIDE_IMAGE)
        if back_img is None:
            back_img = ip.download_img(DEFAULT_BACK_IMAGE)

        if back_images is not None:
            if len(images) != len(back_images):
                raise ValueError(f'Back images are represented as sheet, but found size mismatch with faces sheet '
                                 f'({len(images)} vs. {len(back_images)})')
            back_images, _ = cls.generate_sheets(back_images, sheet_width, sheet_height, back_img, maxw,
                                                'backs' if enable_tqdm else None)

        sheets, info = cls.generate_sheets(images, sheet_width, sheet_height, hide_img, maxw,
                                           'faces' if enable_tqdm else None)

        return Deck(sheets, back_img, back_images, insert_hide, info)

    @classmethod
    def generate_sheets(cls, images, sheet_width, sheet_height, hide_img=None, maxw=720, tqdm_desc=None):
        sheet_width = min(sheet_width, MAX_SHEET_WIDTH)
        sheet_height = min(sheet_height, MAX_SHEET_HEIGHT)

        ratio = None
        max_size: Union[Tuple[int, int], Any] = None
        max_res = 0

        if tqdm_desc is not None:
            print(f'Preparing {tqdm_desc}...')

        for im in images:
            curr_ratio = im.size[0] / im.size[1]
            if ratio is None:
                ratio = curr_ratio
            elif abs(ratio - curr_ratio) > 0.01:
                raise ValueError('Found not equal ratio!')

            if im.size[0] > maxw:
                max_size = (maxw, maxw * im.size[1] // im.size[0])
                break
            if max_res < im.size[0] * im.size[1]:
                max_size = im.size
                max_res = max_size[0] * max_size[1]

        if hide_img is not None:
            if hide_img == 'EMPTY':
                hide_img = Image.new('RGBA', max_size, (255, 255, 255, 0))

            cards_per_sheet = sheet_width * sheet_height
            i = cards_per_sheet - 1
            while i < len(images):
                images.insert(i, hide_img)
                i += cards_per_sheet

        def insert(sheet, im, x, y):
            if im.size != max_size:
                im = im.resize(max_size, Image.ANTIALIAS)

            px, py = x * (max_size[0] + MARGIN), y * (max_size[1] + MARGIN)
            sheet.paste(im, (px, py))

        x, y = 0, 0
        sheets = list()
        info = list()

        images_gen = images if tqdm_desc is None else tqdm(images, unit='pic', desc=f'Generating {tqdm_desc}')
        for i, im in enumerate(images_gen):
            if x >= sheet_width:
                x = 0
                y += 1
            if y >= sheet_height or len(sheets) == 0:
                if len(sheets) > 0:
                    info.append((
                        sheet_width, sheet_height,
                        sheet_height * sheet_width))

                sheets.append(cls._create_sheet(len(images) - i, sheet_width, sheet_height, max_size))
                x, y = 0, 0

            insert(sheets[-1], im, x, y)
            x += 1

        if hide_img is not None:
            insert(sheets[-1], hide_img, sheet_width - 1, y if x < sheet_width else (y + 1))

        info.append((sheet_width if y > 0 else x, y + 1, y * sheet_width + x))
        return sheets, info

    @staticmethod
    def _create_sheet(leftover, width, max_height, card_size, background_color=(255, 255, 255, 255)):
        height = int(math.ceil(leftover / width))
        height = min(height, max_height)
        return Image.new(
            'RGBA', (
                card_size[0] * width + MARGIN * (width - 1),
                card_size[1] * height + MARGIN * (height - 1)),
            background_color)
