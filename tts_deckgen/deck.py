import json
import math
import os
import re
from typing import List, Union, Tuple, Optional

from PIL import Image as Image
from PIL.Image import Image as PILImage
from tqdm import tqdm

from . import image_processing as ip

MAX_SHEET_WIDTH = 10
MAX_SHEET_HEIGHT = 7
DEFAULT_BACK_IMAGE = 'https://imgur.com/zRv5iaf.png'
DEFAULT_HIDE_IMAGE = 'https://imgur.com/oxP7UZY.png'
DEFAULT_STAMP_IMAGE = 'https://imgur.com/j9789mk.png'
MARGIN = 0


class SheetGenerator:
    checkpoint: Optional[Tuple[int, Tuple[int, int], Tuple[int, int]]]

    def __init__(self, w, h, card_size, total_images, bg_color: Optional[Tuple[int, int, int]]):
        self.w = w
        self.h = h
        self.card_size = card_size
        self.total_images = total_images
        self.bg_color = bg_color

        self.sheets = []
        self.sizes = []
        self.x, self.y = 0, 0

        self.checkpoint = None
        self._init_checkpoint()

    def generate(self, images_gen, has_hide):
        for i, im in enumerate(images_gen):
            self._insert(im)
            self._forward(i, has_hide)

        self.sizes.append((self.w, self.y + 1, self.y * self.w + self.x))

    def append_hide_img(self, hide_img):
        self._insert(hide_img, self.w - 1, self.y)

    def get(self):
        return self.sheets, self.sizes

    def _forward(self, cur_i, has_hide):
        self.x += 1

        if self.x >= self.w:
            self.x = 0
            self.y += 1

        if self.y >= self.h or len(self.sheets) == 0:
            if len(self.sheets) > 0:
                self.sizes.append((self.w, self.h, self.w * self.h - (has_hide and 1 or 0)))

            if self.checkpoint is not None and cur_i >= self.checkpoint[0]:
                new_size = self.checkpoint[1 if cur_i == self.checkpoint[0] else 2]
                self.w = new_size[0]
                self.h = new_size[1]

            self.sheets.append(_create_sheet(self.total_images - cur_i, self.w, self.h, self.card_size))
            self.x, self.y = 0, 0

    def _insert(self, im, x=None, y=None):
        if x is None:
            x = self.x
        if y is None:
            y = self.y

        if im.size != self.card_size:
            im = im.resize(self.card_size, Image.ANTIALIAS)

        if self.bg_color is not None:
            bg = Image.new('RGBA', im.size, self.bg_color)
            im = Image.alpha_composite(bg, im)

        px, py = x * (self.card_size[0] + MARGIN), y * (self.card_size[1] + MARGIN)
        self.sheets[-1].paste(im, (px, py))

    # Solving size issues
    # Я провел один тест - случай разрешился (переполнение строки - самый непредсказуемый).
    # Мне влом писать больше тестов.
    # Если будут ошибки здесь - пуллреквесты в студию
    def _init_checkpoint(self):
        sheet_size = self.w * self.h
        full_sheets = self.total_images // sheet_size
        last_sheet_size = self.total_images % sheet_size

        if full_sheets == 0 and last_sheet_size <= 2:
            raise ValueError('Too few images. Must be at least 3')

        if last_sheet_size > 0:
            lines_fed = math.ceil(last_sheet_size / self.w)
            last_line_full = last_sheet_size % self.w == 0

            if lines_fed >= 2 and last_line_full:
                new_size = self._try_solve_full_line_issue(last_sheet_size)
                self.checkpoint = (full_sheets * sheet_size, new_size, new_size)

            elif lines_fed < 1:
                if last_sheet_size > 2:
                    new_size = (last_sheet_size - 1, 2)
                    self.checkpoint = (full_sheets * sheet_size, new_size, new_size)
                elif last_sheet_size <= 2 and full_sheets > 0:
                    if max(self.w, self.h) > 2:
                        if self.w > self.h >= 2:
                            new_size_1 = (self.w - 1, self.h)
                            add = self.h
                        else:
                            new_size_1 = (self.w, self.h - 1)
                            add = self.w

                        last_sheet_size += add
                        lines_fed = math.ceil(last_sheet_size / self.w)
                        last_line_full = last_sheet_size % self.w == 0

                        if lines_fed >= 2 and not last_line_full:
                            new_size_2 = (self.w, lines_fed)
                        elif lines_fed < 2:
                            new_size_2 = (last_sheet_size - 1, 2)
                        else:
                            new_size_2 = self._try_solve_full_line_issue(last_sheet_size)

                        self.checkpoint = ((full_sheets - 1) * sheet_size, new_size_1, new_size_2)

                    else:
                        raise ValueError('Cannot solve sheet shape issues with current size. Try to increase its '
                                         'dimensions.')

        if self.checkpoint is not None and self.checkpoint[0] == 0:
            self.w = self.checkpoint[1][0]
            self.h = self.checkpoint[1][1]

        self.sheets.append(_create_sheet(self.total_images, self.w, self.h, self.card_size))

    def _try_solve_full_line_issue(self, last_sheet_size):
        w = self.w - 1
        while last_sheet_size % w == 0:
            w -= 1
            if w < 2 or w * self.h <= last_sheet_size:
                raise ValueError('Cannot solve sheet shape issues with current size. Try to change one.')
        new_size = (w, math.ceil(last_sheet_size / w))
        return new_size


class DeckSheet:
    face_path: str
    back_path: str
    size: Tuple[int, int, int]
    back_is_hidden: bool
    unique_back: bool

    def __init__(self, face_path: str,
                 back_path: str,
                 size: Tuple[int, int, int],
                 back_is_hidden: bool,
                 unique_back: bool):
        self.face_path = face_path
        self.back_path = back_path
        self.size = size
        self.back_is_hidden = back_is_hidden
        self.unique_back = unique_back

    @classmethod
    def load(cls, directory, prefix):
        with open(os.path.join(directory, f'{prefix}_deck_info.json')) as fp:
            info_list = json.load(fp)
        return list(map(lambda info: DeckSheet(info['face_path'], info['back_path'], tuple(info['size']),
                                               info['back_is_hidden'], info['unique_back']), info_list))


class Deck:
    saved_sheets: Optional[List[DeckSheet]]
    sheets_sizes: List[Tuple[int, int, int]]
    sheets: List[PILImage]
    back_img: Union[PILImage, List[PILImage]]
    has_hide_img: bool
    back_sheets: Optional[List[PILImage]]
    cards_info: List[dict]

    def __init__(self,
                 sheets: List[PILImage],
                 back_img: Union[PILImage, List[PILImage]],
                 back_sheets: Optional[List[PILImage]],
                 has_hide_img: bool,
                 sheets_sizes: List[Tuple[int, int, int]],
                 cards_info: List[dict]):
        self.sheets = sheets
        self.back_img = back_img
        self.back_sheets = back_sheets
        self.has_hide_img = has_hide_img
        self.sheets_sizes = sheets_sizes
        self.cards_info = cards_info
        self.saved_sheets = None

    def sheets_info(self):
        res = []
        for w, h, c in self.sheets_sizes:
            res.append(f'({w}x{h}): {c}')
        return ', '.join(res)

    def save(self, output_dir, prefix):
        faces = []
        for i, s in enumerate(self.sheets):
            path = os.path.abspath(os.path.join(output_dir, f'{prefix}_sheet_{i:02d}.png'))
            s.save(path)
            faces.append(path)

        if self.back_sheets is not None:
            backs = list()
            for i, s in enumerate(self.back_sheets):
                path = os.path.abspath(os.path.join(output_dir, f'{prefix}_back_{i:02d}.png'))
                s.save(path)
                backs.append(path)

        else:
            path = os.path.abspath(os.path.join(output_dir, f'{prefix}_back.png'))
            self.back_img.save(path)
            backs = [path for _ in range(len(faces))]

        self.saved_sheets = []
        for f, b, s in zip(faces, backs, self.sheets_sizes):
            self.saved_sheets.append(DeckSheet(f, b, s, not self.has_hide_img, self.back_sheets is not None))

        with open(os.path.join(output_dir, f'{prefix}_deck_info.json'), 'w') as o:
            json.dump(self.saved_sheets, o, default=vars)

        with open(os.path.join(output_dir, f'{prefix}_cards_info.json'), 'w') as o:
            json.dump(self.cards_info, o)

    @classmethod
    def create(cls, images: List[PILImage], info: Optional[List[dict]] = None, back_img=None, back_images=None,
               insert_hide=True, hide_img=None,
               sheet_width=MAX_SHEET_WIDTH, sheet_height=MAX_SHEET_HEIGHT,
               maxw=720, enable_tqdm=True, tqdm_inst=tqdm, bg_color=(255, 255, 255, 255)):
        if info is None:
            info = [{} for _ in range(len(images))]
        else:
            if len(info) != len(images):
                raise ValueError('Info list length mismatch')

        if insert_hide and hide_img is None:
            hide_img = ip.download_img(DEFAULT_HIDE_IMAGE)
        if back_img is None:
            back_img = ip.download_img(DEFAULT_BACK_IMAGE)

        if back_images is not None:
            if len(images) != len(back_images):
                raise ValueError(f'Back images are represented as sheet, but found size mismatch with faces sheet '
                                 f'({len(images)} vs. {len(back_images)})')
            back_images, _ = cls._generate_sheets(back_images, sheet_width, sheet_height, back_img, maxw,
                                                 'backs' if enable_tqdm else None, tqdm_inst, bg_color)

        sheets, sizes = cls._generate_sheets(images, sheet_width, sheet_height, hide_img, maxw,
                                            'faces' if enable_tqdm else None, tqdm_inst, bg_color)

        return Deck(sheets, back_img, back_images, insert_hide, sizes, info)

    @classmethod
    def _generate_sheets(cls, images, sheet_width, sheet_height, hide_img, maxw, tqdm_desc, tqdm_inst, bg_color):
        sheet_width = min(sheet_width, MAX_SHEET_WIDTH)
        sheet_height = min(sheet_height, MAX_SHEET_HEIGHT)

        ratio = None
        card_size: Optional[Tuple[int, int]] = None

        if tqdm_desc is not None:
            print(f'Preparing {tqdm_desc}...')

        for im in images:
            curr_ratio = im.size[0] / im.size[1]
            if ratio is None:
                ratio = curr_ratio
            elif abs(ratio - curr_ratio) > 0.01:
                raise ValueError('Found not equal ratio!')

            if im.size[0] > maxw:
                card_size = (maxw, maxw * im.size[1] // im.size[0])
                break
            if card_size is None or card_size[0] < im.size[0]:
                card_size = im.size

        if hide_img is not None:
            cards_per_sheet = sheet_width * sheet_height
            i = cards_per_sheet - 1
            while i < len(images):
                images.insert(i, hide_img)
                i += cards_per_sheet

        images_gen = images if tqdm_desc is None else tqdm_inst(images, total=len(images), unit='pic',
                                                                desc=f'Generating {tqdm_desc}')

        gen = SheetGenerator(sheet_width, sheet_height, card_size, len(images), bg_color)
        gen.generate(images_gen, hide_img is not None)

        if hide_img is not None:
            gen.append_hide_img(hide_img)

        return gen.get()


def _create_sheet(leftover, width, max_height, card_size, background_color=(255, 255, 255, 255)):
    height = int(math.ceil(leftover / width))
    height = min(height, max_height)
    return Image.new(
        'RGBA', (
            card_size[0] * width + MARGIN * (width - 1),
            card_size[1] * height + MARGIN * (height - 1)),
        background_color)


def load_cards_info(directory, prefix):
    with open(os.path.join(directory, f'{prefix}_cards_info.json')) as fp:
        return json.load(fp)
