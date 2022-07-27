import io
import random
from typing import Tuple, Union

import PIL.Image
import requests
from PIL import Image, ImageDraw
from PIL.Image import Image as PILImage


def check_supported_ext(f):
    return f.lower().split('.')[-1] in ['png', 'jpg', 'jpeg']


def download_img(img_url) -> PIL.Image.Image:
    r = requests.get(img_url)
    return Image.open(io.BytesIO(r.content))


def round_r(size: Tuple[int, int]):
    return int(round(size[1] * 15 / 512))


def round_w(size: Tuple[int, int]):
    return int(round(size[1] * 10 / 512))


def fix_ratio(img: Union[str, Image.Image], ratio=(2, 3), freeze_width=False, freeze_height=False):
    if isinstance(img, str):
        img_open = Image.open(img)
        img = img_open.convert('RGBA')
        img_open.close()

    width, height = img.size

    if not freeze_height and ratio[0] / ratio[1] > width / height or freeze_width:
        new_height = width * ratio[1] / ratio[0]
        new_width = width
    else:
        new_width = height * ratio[0] / ratio[1]
        new_height = height

    return img.crop(find_center((width, height), (new_width, new_height)))


def find_center(box_size, content_size):
    w, h = box_size[0], box_size[1]
    cw, ch = content_size[0], content_size[1]
    return (
        int((w - cw) / 2), int((h - ch) / 2),
        int((w + cw) / 2), int((h + ch) / 2))


def stamp(orig_img: PILImage, stamp_img: PILImage, back_color=(54, 54, 54, 200)):
    w = stamp_img.size[0]
    h = w * orig_img.size[1] // orig_img.size[0]

    stamp_back = Image.new('RGBA', (w, h), back_color)
    angle = -random.randint(0, 90)
    stamp_img = stamp_img.rotate(angle, Image.BICUBIC)

    center = find_center(stamp_back.size, stamp_img.size)
    offset_x, offset_y = center[0], center[1]
    offset_x = random.randint(0, offset_x * 2) - offset_x
    offset_y = random.randint(0, offset_y * 2) - offset_y

    center = (
        center[0] + offset_x, center[1] + offset_y,
        center[2] + offset_x, center[3] + offset_y)

    stamp_back.paste(stamp_img, center, stamp_img)
    stamp_back = stamp_back.resize(orig_img.size, Image.ANTIALIAS)
    return Image.alpha_composite(orig_img, stamp_back)


def round_frame(img: str, ratio=(2, 3)):
    with Image.open(img).convert('RGBA') as img:
        img = fix_ratio(img, ratio)
        over = Image.new('RGBA', img.size, (255, 255, 255, 0))
        over_draw = ImageDraw.Draw(over)
        over_draw.rounded_rectangle(
            ((0, 0), img.size),
            round_r(img.size),
            width=round_w(img.size),
            fill=(255, 255, 255, 0),
            outline=(31, 157, 26))
        return Image.alpha_composite(img, over)
