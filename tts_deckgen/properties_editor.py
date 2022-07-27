import os
import re
import shutil

import pandas as pd
from PIL import Image

from . import deck as d
from . import image_processing as ip

KNOWN_SOURCES = ['kantai_collection']
SUGGEST_PROPERTIES = {
    'NSFW Rating': ['Safe', 'Questionable', 'NSFW'],
    'Unusual Outfit (for character)': ['true'],
}


def export_excel(path, cards):
    if not path.endswith('.xlsx'):
        path = '.'.join([path, 'xlsx'])

    df = cards_to_df(cards)
    df.to_excel(path)


def cards_to_df(cards):
    columns = []
    for c in cards:
        if 'Properties' not in c:
            c['Properties'] = {}
        for p in c['Properties']:
            if p not in columns:
                columns.append(str(p))
    columns = ['Nickname'] + list(sorted(columns))
    rows = []
    for c in cards:
        if 'Nickname' not in c:
            c['Nickname'] = ''
        row = [c['Nickname']]
        props = c['Properties']
        for p in columns[1:]:
            row.append(props[p] if p in props else '')
        rows.append(row)
    return pd.DataFrame(data=rows, columns=columns)


def import_excel(path, into=None):
    df = pd.read_excel(path, index_col=0, na_filter=False)
    if into is None:
        into = [{} for _ in range(len(df))]
    if len(into) != len(df):
        raise ValueError(f'Table data length isn\'t equal to original data length ({len(df)} != {len(into)})')

    changed_nicks = []
    for idx, d in df.iterrows():
        c = into[idx]
        new_nick = d.iloc[0]
        if 'Nickname' not in c or c['Nickname'] != new_nick:
            changed_nicks.append((c['Nickname'], new_nick))
            c['Nickname'] = new_nick
        if 'Properties' not in c:
            c['Properties'] = {}
        props = c['Properties']
        for k, v in d.iloc[1:].items():
            if v == '':
                if k in props:
                    del props[k]
                continue
            props[k] = v

    return into, changed_nicks


def norm_sort(to_sort):
    return sorted(to_sort, key=lambda x: x.lower())


def _strip_extensions(fnames):
    return ['.'.join(f.split('.')[:-1]) for f in fnames]


def _rename(old, new, directory):
    return os.path.normpath(os.path.join(directory, old)), \
           os.path.normpath(os.path.join(directory, '.'.join([new, old.split('.')[-1]])))


def _normalize_name(name):
    name = re.sub(r'_and_.*', '', name)
    for x in KNOWN_SOURCES:
        if name.endswith(x):
            name = re.sub(fr'_{re.escape(x)}$', '', name)
    join = ' '.join([f[0].upper() + f[1:] for f in (name.split('_'))])
    return join


def _suggest(key, from_list):
    print(f'{key}: ')
    from_list = ['(none)'] + from_list
    for i, v in enumerate(from_list):
        print(f'[{i}] {v}')
    while True:
        ans = input('> ')
        if ans != '' and not re.match(r'\d+', ans):
            continue
        ans = int(ans) if ans != '' else 0
        if 0 <= ans < len(from_list):
            break
    return '' if ans == 0 else from_list[ans]


class PropertiesEditor:
    def __init__(self, deck_path, images_path, expansion_path, prefix='grid', show=True, copy=False):
        self.expansion_paths = None
        self.expansion = None
        self.images_names = None
        self.images = None
        self.previous_name = None
        self.cards = d.load_cards_info(deck_path, prefix)
        self.images_path = images_path
        self.expansion_path = expansion_path
        self.deck_path = deck_path
        self.prefix = prefix
        self.show = show
        self.copy = copy
        self.idx = 0

        self.found_props = set()
        for c in self.cards:
            for k in c['Properties']:
                self.found_props.add(k)

        l = self.init_expansion()
        if l == 0:
            raise ValueError('No images in dir')

    def init_expansion(self):
        self.images = norm_sort([f for f in os.listdir(self.images_path) if ip.check_supported_ext(f)])
        self.images_names = _strip_extensions(self.images)
        self.expansion = list(os.listdir(self.expansion_path))
        return len(self.expansion)

    def _make_unique(self, name):
        split = name.split('.')
        name_no_ext, ext = '.'.join(split[:-1]), split[-1]
        s = name_no_ext
        i = 2
        while s in self.images_names:
            s = f'{s} [{i}]'
            i += 1

        self.images_names.append(s)
        return '.'.join([s, ext])

    def _insert_new(self, name, name_orig):
        self.images.append(name)
        self.images = norm_sort(self.images)
        idx = self.images.index(name)

        obj = {
            'Nickname': name_orig,
            'Properties': {}
        }
        self.cards.insert(idx, obj)
        return idx, obj

    def _try_inherit(self, idx, obj):
        neighbours = []
        if idx > 0:
            neighbours.append(self.cards[idx - 1])
        if idx < len(self.cards) - 1:
            neighbours.append(self.cards[idx + 1])
        for o in neighbours:
            if o['Nickname'] == obj['Nickname']:
                for k, v in o['Properties'].items():
                    obj['Properties'][k] = v
                break

    def suggest_props(self, obj):
        for p, l in SUGGEST_PROPERTIES.items():
            props = obj['Properties']
            if p in self.found_props:
                ans = _suggest(p, l)
                if ans == '':
                    if p in props:
                        del props[p]
                else:
                    props[p] = ans

    def handle_name(self, img):
        match = re.match(r'__([\w_-]+)_drawn_by_.*', img)
        if match:
            name = _normalize_name(match.group(1))
            print(f'Suggestion: {name}')
        elif self.previous_name:
            name = self.previous_name
            print(f'Suggestion: {name}')
        else:
            name = None
            print('No suggestion')

        s = input('> ')
        if s == '':
            if name:
                old, new = _rename(img, name, self.expansion_path)
            else:
                old, new = None, None
        else:
            self.previous_name = s
            old, new = _rename(img, s, self.expansion_path)

        if old is not None and new is not None:
            shutil.move(old, new)
            name_orig = os.path.split(new)[-1]
            return self._make_unique(name_orig), name_orig
        else:
            return self._make_unique(img), img

    def next(self):
        img = self.expansion[self.idx]
        img_path = os.path.join(self.expansion_path, img)
        print(img)

        if self.show:
            Image.open(img_path).convert('RGBA').show()

        img, orig = self.handle_name(img)
        img_path = os.path.join(self.expansion_path, orig)
        idx, obj = self._insert_new(img, '.'.join(orig.split('.')[:-1]))
        self._try_inherit(idx, obj)
        self.suggest_props(obj)

        new_path = os.path.join(self.images_path, img)
        if self.copy:
            shutil.copy(img_path, new_path)
        else:
            shutil.move(img_path, new_path)
        d.save_cards_info(self.cards, self.deck_path, self.prefix)

        print(f'{img_path} -> {new_path}')
        print(str(obj))
        print()
        self.idx += 1

    def has_next(self):
        return self.idx < len(self.expansion)


def properties_editor(deck_path, images_path, expansion_path, prefix='grid', show=True, copy=False):
    editor = PropertiesEditor(deck_path, images_path, expansion_path, prefix, show, copy)
    while editor.has_next():
        editor.next()
