import json
import os.path
import random
import shutil

from deck import Deck

_reference_fallback_contained_object = """{
  "GUID": "fc648e",
  "Name": "Card",
  "Transform": {
    "posX": -2.56400275,
    "posY": 1.55906236,
    "posZ": -16.0311089,
    "rotX": 0.01687331,
    "rotY": 179.999969,
    "rotZ": 180.07988,
    "scaleX": 1.0,
    "scaleY": 1.0,
    "scaleZ": 1.0
  },
  "Nickname": "",
  "Description": "",
  "GMNotes": "",
  "ColorDiffuse": {
    "r": 0.713235259,
    "g": 0.713235259,
    "b": 0.713235259
  },
  "LayoutGroupSortIndex": 0,
  "Value": 0,
  "Locked": false,
  "Grid": true,
  "Snap": true,
  "IgnoreFoW": false,
  "MeasureMovement": false,
  "DragSelectable": true,
  "Autoraise": true,
  "Sticky": true,
  "Tooltip": true,
  "GridProjection": false,
  "Hands": true,
  "CardID": 1704,
  "SidewaysCard": false,
  "XmlUI": "",
  "ContainedObjects": []
}"""
_reference_fallback_custom_deck = """{
  "FaceURL": "",
  "BackURL": "",
  "NumWidth": 10,
  "NumHeight": 2,
  "BackIsHidden": false,
  "UniqueBack": true,
  "Type": 0
}"""


def _to_file_path(path):
    path = os.path.abspath(path)
    if path.startswith('/'):
        path = path[1:]
    return 'file:///' + path


class SaveProcessor:
    deck_obj: dict
    save_obj: dict
    obj_guid: str
    save_path: str
    reference_contained_object: str
    reference_custom_deck: str

    def __init__(self, save_path, obj_guid, verbose=True):
        self.verbose = verbose
        if verbose:
            print('Reading save...')

        with open(save_path) as fin:
            save_obj = json.load(fin)

        if 'ObjectStates' not in save_obj:
            raise ValueError('Cannot find ObjectStates in save')

        self.save_obj = save_obj
        self.save_path = save_path

        self.set_object(obj_guid)

        self.guids = set()
        self._collect_guids()

        self.custom_decks_start = 0
        self._find_custom_decks()

    def set_object(self, obj_guid):
        objects = self.save_obj['ObjectStates']
        for o in objects:
            if o['GUID'] == obj_guid:
                deck_obj = o
                break
        else:
            raise ValueError(f'Cannot find referenced deck in save '
                             f'(GUID: {obj_guid}, Objects in save: {len(objects)})')

        try:
            cd = deck_obj['CustomDeck']
            for k in cd.keys():
                self.reference_custom_deck = json.dumps(cd[k])
                break
        except KeyError:
            print('WARN: Cannot find custom deck reference, falling to internal snapshot')
            self.reference_custom_deck = _reference_fallback_custom_deck

        try:
            self.reference_contained_object = json.dumps(deck_obj['ContainedObjects'][0])
        except KeyError:
            print('WARN: Cannot find contained object reference, falling to internal snapshot')
            self.reference_contained_object = _reference_fallback_contained_object

        self.obj_guid = obj_guid
        self.deck_obj = deck_obj

        self.deck_obj['CustomDeck'] = {}
        self.deck_obj['DeckIDs'] = []
        self.deck_obj['ContainedObjects'] = []

    def write_decks(self, *decks: Deck):
        custom_decks = {}
        deck_ids = []
        contained_objects = []

        if self.verbose: print('Generating data...')

        for deck_idx, deck in enumerate(decks):
            if deck.saved_sheets is None:
                print(f'WARN: Deck #{deck_idx} not saved!')
                continue

            start = len(deck_ids)

            for sheet in deck.saved_sheets:
                sheet_idx = len(custom_decks) + 1 + self.custom_decks_start

                custom_deck = json.loads(self.reference_custom_deck)
                custom_deck['FaceURL'] = _to_file_path(sheet.face_path)
                custom_deck['BackURL'] = _to_file_path(sheet.back_path)
                custom_deck['NumWidth'] = sheet.size[0]
                custom_deck['NumHeight'] = sheet.size[1]
                custom_deck['BackIsHidden'] = sheet.back_is_hidden
                custom_deck['UniqueBack'] = sheet.unique_back
                custom_decks[str(sheet_idx)] = custom_deck

                deck_ids += [sheet_idx * 100 + i for i in range(sheet.size[2])]

            for i, inf in enumerate(deck.cards_info):
                obj = json.loads(self.reference_contained_object)
                for k, v in inf.items():
                    obj[k] = v

                card_id = deck_ids[start + i]
                obj['CardID'] = card_id

                sheet_idx = str(card_id // 100)
                obj['CustomDeck'] = {sheet_idx: custom_decks[sheet_idx]}

                obj['GUID'] = self._generate_guid()
                contained_objects.append(obj)

        self.deck_obj['CustomDeck'] = custom_decks
        self.deck_obj['DeckIDs'] = deck_ids
        self.deck_obj['ContainedObjects'] = contained_objects

        if self.verbose: print('Backing up save...')
        filedir, filename = os.path.split(self.save_path)
        first_bak_path = os.path.join(filedir, filename + '.ttsdg.bak')
        if not os.path.exists(first_bak_path):
            shutil.copy(self.save_path, first_bak_path)
        else:
            shutil.copy(self.save_path, os.path.join(filedir, filename + '.bak'))
        os.remove(self.save_path)

        if self.verbose: print('Writing save...')
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
