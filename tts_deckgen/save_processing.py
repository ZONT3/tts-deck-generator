import json
import os.path
import random
import shutil
from typing import Optional, List, Tuple, Union

from . import save_data as data
from .deck import Deck, DeckSheet


def to_file_path(path):
    path = os.path.abspath(path)
    if path.startswith('/'):
        path = path[1:]
    return 'file:///' + path


class SaveProcessor:
    deck_obj: dict
    save_obj: dict
    obj_guid: str
    save_path: str
    reference_contained_object: Optional[str]
    reference_custom_deck: Optional[str]

    def __init__(self, save_path, verbose=True):
        self.verbose = verbose
        if verbose:
            print('Reading save...')

        with open(save_path) as fin:
            save_obj = json.load(fin)

        if 'ObjectStates' not in save_obj:
            raise ValueError('Cannot find ObjectStates in save')

        self.save_obj = save_obj
        self.save_path = save_path

        self.referenced = False
        self.reference_custom_deck = None
        self.reference_contained_object = None

        self.guids = set()
        self._collect_guids()

        self.custom_decks_start = 0
        self._find_custom_decks()

    def set_object(self, obj_guid, use_stored_data=True, append_content=False):
        objects = self.save_obj['ObjectStates']
        for o in objects:
            if o['GUID'] == obj_guid:
                deck_obj = o
                break
        else:
            raise ValueError(f'Cannot find referenced deck in save '
                             f'(GUID: {obj_guid}, Objects in save: {len(objects)})')

        if not use_stored_data:
            try:
                cd = deck_obj['CustomDeck']
                for k in cd.keys():
                    self.reference_custom_deck = json.dumps(cd[k])
                    break
            except KeyError:
                print('WARN: Cannot find custom deck reference, falling to internal snapshot')

            try:
                self.reference_contained_object = json.dumps(deck_obj['ContainedObjects'][0])
            except KeyError:
                print('WARN: Cannot find contained object reference, falling to internal snapshot')

        if self.reference_custom_deck is None:
            self.reference_custom_deck = data.custom_deck_entry
        if self.reference_contained_object is None:
            self.reference_contained_object = data.contained_object

        self.obj_guid = obj_guid

        if not use_stored_data or append_content:
            if not append_content:
                deck_obj['CustomDeck'] = {}
                deck_obj['DeckIDs'] = []
                deck_obj['ContainedObjects'] = []
            self.deck_obj = deck_obj
            self.referenced = True
        else:
            self.deck_obj = json.loads(data.deck_custom)

    def write_decks(self, *decks: Union[Deck, Tuple[List[DeckSheet], List[dict]]]):
        custom_decks = {}
        deck_ids = []
        contained_objects = []

        if self.verbose:
            print('Generating data...')

        for deck_idx, deck in enumerate(decks):
            saved_sheets, cards_info = deck if not isinstance(deck, Deck) else (deck.saved_sheets, deck.cards_info)
            if saved_sheets is None:
                print(f'WARN: Deck #{deck_idx} not saved!')
                continue

            start = len(deck_ids)

            for sheet in saved_sheets:
                sheet_idx = len(custom_decks) + 1 + self.custom_decks_start

                custom_deck = json.loads(self.reference_custom_deck)
                custom_deck['FaceURL'] = to_file_path(sheet.face_path)
                custom_deck['BackURL'] = to_file_path(sheet.back_path)
                custom_deck['NumWidth'] = sheet.size[0]
                custom_deck['NumHeight'] = sheet.size[1]
                custom_deck['BackIsHidden'] = sheet.back_is_hidden
                custom_deck['UniqueBack'] = sheet.unique_back
                custom_decks[str(sheet_idx)] = custom_deck

                deck_ids += [sheet_idx * 100 + i for i in range(sheet.size[2])]

            for i, inf in enumerate(cards_info):
                obj = json.loads(self.reference_contained_object)
                for k, v in inf.items():
                    obj[k] = v

                card_id = deck_ids[start + i]
                obj['CardID'] = card_id

                obj['GUID'] = self._generate_guid()
                contained_objects.append(obj)

        self.deck_obj['CustomDeck'].update(custom_decks)
        self.deck_obj['DeckIDs'] += deck_ids
        self.deck_obj['ContainedObjects'] += contained_objects

        if not self.referenced:
            for i, o in enumerate(self.save_obj['ObjectStates']):
                if o['GUID'] == self.obj_guid:
                    self.save_obj['ObjectStates'][i] = self.deck_obj
                    break

        if self.verbose:
            print('Backing up save...')
        filedir, filename = os.path.split(self.save_path)
        first_bak_path = os.path.join(filedir, filename + '.ttsdg.bak')
        if not os.path.exists(first_bak_path):
            shutil.copy(self.save_path, first_bak_path)
        else:
            shutil.copy(self.save_path, os.path.join(filedir, filename + '.bak'))
        os.remove(self.save_path)

        if self.verbose:
            print('Writing save...')
        with open(self.save_path, 'w') as fout:
            json.dump(self.save_obj, fout, indent=4)

    def _collect_guids(self):
        self._foreach_object(lambda o: self.guids.add(o['GUID']), lambda o: 'GUID' in o)
        if self.verbose:
            print('Total GUIDs in save:', len(self.guids))

    def _generate_guid(self):
        guid = ''
        while guid == '' or guid in self.guids:
            guid = f'{random.randint(0, 0xffffff):06x}'

        self.guids.add(guid)
        return guid

    def _find_custom_decks(self):
        def func(o):
            if 'CustomDeck' in o:
                for k in o['CustomDeck'].keys():
                    idx = int(k)
                    if self.custom_decks_start < idx:
                        self.custom_decks_start = idx

        self._foreach_object(func)
        if self.verbose:
            print('Custom decks start:', self.custom_decks_start)

    def _foreach_object(self, func, condition=lambda o: True, objects=None):
        if objects is None:
            objects = self.save_obj['ObjectStates']

        for o in objects:
            if condition(o):
                func(o)
            if 'ContainedObjects' in o:
                self._foreach_object(func, condition, o['ContainedObjects'])
