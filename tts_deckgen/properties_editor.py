import json
import re
import sys
import traceback
from typing import List, Dict

from tts_deckgen.deck import DeckSheet, get_from_sheets

RESERVED_PROPS = ['name']


class CommandNotFoundError(RuntimeError):
    pass


def _print_all(props, cards):
    sign_dict = {}
    for i, signs in enumerate(props):
        sign = '\n'.join(sorted([f'\t{k}: {v}' for k, v in signs.items()]))
        if sign == '':
            sign = '\t(empty)'
        if sign not in sign_dict:
            sign_dict[sign] = []
        sign_dict[sign].append(f"[{i}] {cards[i]['Nickname']}")

    pairs = [(',\n'.join(names), sign) for sign, names in sign_dict.items()]
    print('\n'.join([':\n'.join(p) for p in pairs]))


def _confirm_props_modification(set_props, del_props, curr_props, cards):
    if len(set_props) == len(del_props) == 0:
        print('No changes made')
        return False

    create: Dict[int, List[str]] = {}
    alter: Dict[int, List[str]] = {}
    for i, c in set_props.items():
        card = curr_props[i]
        for k, v in c.items():
            if not _check_prop(k, False):
                continue

            if k not in card:
                if i not in create:
                    create[i] = []
                create[i].append(f'\t\t{k}: {v}')

            else:
                if i not in alter:
                    alter[i] = []
                alter[i].append(f'\t\t{k}: {card[k]} -> {v}')

    delete: Dict[int, List[str]] = {}
    for i, lst in del_props.items():
        delete[i] = []
        card = curr_props[i]
        for k in lst:
            delete[i].append(f'\t\t{k}: {card[k]}')

    create_str = []
    alter_str = []
    delete_str = []
    for res, dct in ((create_str, create), (alter_str, alter)):
        sign_dict = {}
        for i, signs in dct.items():
            sign = '\n'.join(sorted(signs))
            if sign not in sign_dict:
                sign_dict[sign] = []
            sign_dict[sign].append(f"\t[{i}] {cards[i]['Nickname']}")

        for sign, names in sign_dict.items():
            res.append((',\n'.join(names), sign))

    print('Changes to apply:')
    for s, arr in (('CREATE', create_str), ('ALTER', alter_str), ('DELETE', delete_str)):
        if len(arr) == 0:
            continue
        print(f'{s}:')
        print('\n'.join(map(lambda x: f'{x[0]}:\n{x[1]}', arr)))

    print('\nDo You confirm changes? (y/n)')

    ans = input()
    while ans not in ['yes', 'no', 'y', 'n']:
        print('yes/no/y/n only')
        ans = input('')

    return ans.startswith('y')


def _check_prop(k, warn=True):
    check = k in RESERVED_PROPS
    if check and warn:
        print(f'"{k}" is reserved property')
    return not check


def _print_props(props):
    for k, v in props.items():
        if _check_prop(k, False):
            print(f'\t{k}: {v}')


def print_help():
    print('Commands:\n'
          '\tshow|sh: show current card (PIL.Image.Image.show())\n'
          '\tnext|n: next card\n'
          '\tprev|p: previous card\n'
          '\tgoto|jump|j INT: jump to position (will jump to next empty card if INT is not stated)\n'
          '\tfind|f STR: find next card name contains entered string. '
          '"!" in start of string means exact matching name\n'
          '\tpfind|pf STR: find next card contains entered property (and value if stated).\n'
          '\tfnext|fn: Repeat last search'
          '\tset|s STR: edit (create) property of current card\n'
          '\tdel|d|rm STR delete property\n'
          '\tclr Clear current changes on current card\n'
          '\tclra Clear all properties on current card\n'
          '\tcopy|cp copy current properties in buffer\n'
          '\tpaste|pt paste current properties from buffer, not overwrite existing\n'
          '\tpaste-all|pta paste current properties from buffer to all card with current name, '
          'not overwrite existing\n'
          '\trpaste|rpt paste replacing all\n'
          '\texit|q quit program\n'
          '\thelp|h print this help\n'
          '\tprint print all properties, grouped\n\n')


class Editor:
    def __init__(self, sheets: List[DeckSheet], cards: List[dict]):
        self.sheets = sheets
        self.cards = cards

        self.curr = 0

        self.set_props: Dict[int, dict] = {}
        self.del_props: Dict[int, List[str]] = {}
        self.orig_props: Dict[int, dict] = {
            k: v['Properties'] if 'Properties' in v else {}
            for k, v in enumerate(cards)}

        self.buffer = {}
        self.prev_set = None
        self.prev_set_v = None
        self.prev_search = None
        self.prev_search_val = None
        self.prev_move = 'next'

    def get_props(self, idx=None):
        if not idx:
            idx = self.curr

        res = self.orig_props[idx].copy()
        if idx in self.del_props:
            for k in self.del_props[idx]:
                if k in res:
                    del res[k]
        if idx in self.set_props:
            for k, v in self.set_props[idx].items():
                res[k] = v

        return res

    def print_curr(self):
        print(f"[{self.curr}] \"{self.get_name()}\"")
        _print_props(self.get_props())

    def set_p(self, k, v):
        if len(v) == 0:
            v = 'true'
        if self.curr in self.del_props and k in self.del_props[self.curr]:
            self.del_props[self.curr].remove(k)
            if len(self.del_props[self.curr]) == 0:
                del self.del_props[self.curr]
        if self.curr not in self.set_props:
            self.set_props[self.curr] = {}
        self.set_props[self.curr][k] = v

    def find(self, predicate, curr):
        started = curr
        curr += 1
        curr %= len(self.cards)
        while not predicate(curr) and started != curr:
            curr += 1
            curr %= len(self.cards)

        return curr

    def inc_c(self, inc=1):
        self.curr += inc
        self.curr %= len(self.cards)

    def print_total(self, key):
        count = sum(key in self.get_props(i) for i in range(len(self.cards)))
        if count > 0:
            print(f'That key is used {count} times')
        else:
            print(f'ATTENTION: That key is first time used. Check for typo if that is unexpected')

    def paste(self, replace=False):
        props = self.get_props()
        for k, v in self.buffer.items():
            if not _check_prop(k, False):
                continue
            if replace or k not in props:
                self.set_p(k, v)

    def com_find(self, input_lower):
        if input_lower.startswith('!'):
            exact = True
            input_lower = input_lower[1:]
        else:
            exact = False

        def pd(curr):
            name = self.get_name(curr).lower()
            return input_lower == name or exact and input_lower in name

        found = self.find(pd, self.curr)
        if found == self.curr:
            print('Not found')
        else:
            self.prev_move = 'find'
            self.prev_search = input_lower
            self.prev_search_val = None
            
            self.curr = found
            self.print_curr()
            
    def com_pfind(self, command_input, val, skip_blocks=False):
        name = self.get_name()

        def pd(curr):
            props = self.get_props(curr)
            return (not skip_blocks or self.get_name(curr) != name) and \
                   command_input in props and (True if len(val) == 0 else val == props[command_input])

        found = self.find(pd, self.curr)
        if found == self.curr:
            print('Not found')
        else:
            self.prev_move = 'pfind'
            self.prev_search = command_input
            self.prev_search_val = val
            
            self.curr = found
            self.print_curr()

    def get_name(self, idx=None):
        if idx is None:
            idx = self.curr
        return self.cards[idx]['Nickname']

    def repeat_last(self, skip_blocks=False):
        if self.prev_move in ['next', 'prev']:
            self.command(self.prev_move)
        else:
            self.find_next(skip_blocks)
            
    def find_next(self, skip_blocks=False):
        if self.prev_search is None:
            return
        if self.prev_search_val is None:
            self.com_find(self.prev_search)
        else:
            self.com_pfind(self.prev_search, self.prev_search_val, skip_blocks=skip_blocks)

    def command(self, string):
        if len(string) == 0:
            self.repeat_last(True)
            return

        command = string.split(' ')[0]
        command_input = string[len(command):].strip()
        input_lower = command_input.lower()

        if command in ['show', 'sh']:
            get_from_sheets(self.sheets, self.curr).show()
            
        elif command in ['next', 'n']:
            self.inc_c()
            self.print_curr()
            self.prev_move = 'next'
        elif command in ['prev', 'p']:
            self.inc_c(-1)
            self.print_curr()
            self.prev_move = 'prev'
            
        elif command in ['find', 'f']:
            if len(command_input) > 0:
                self.com_find(input_lower)

        elif command in ['pfind', 'pf']:
            if len(command_input) > 0:
                val = input('value (optional): ').strip()
                self.com_pfind(command_input, val)

        elif command in ['jump', 'j', 'goto']:
            if re.match(r'\d+', command_input):
                self.curr = int(command_input)
                self.curr %= len(self.cards)
            else:
                found = self.find(lambda i: len(self.get_props(i)) == 0, self.curr)
                if self.curr == found:
                    found = self.find(lambda i: len(self.del_props[i]) == len(self.set_props[i]) == 0, self.curr)
                self.curr = found

            self.print_curr()

        elif command in ['set', 's']:
            if _check_prop(command_input):
                if len(command_input) == 0 and self.prev_set is not None:
                    command_input = self.prev_set
                    val = self.prev_set_v if self.prev_set_v is not None else ''
                else:
                    val = input('value (empty == true): ').strip()
                
                if len(command_input) == 0:
                    return
                    
                self.print_total(command_input)
                self.set_p(command_input, val)
                self.prev_set = command_input
                self.prev_set_v = val
                
                self.print_curr()

        elif command in ['del', 'd', 'rm']:
            if len(command_input) > 0 and _check_prop(command_input):
                if self.curr in self.set_props and command_input in self.set_props[self.curr]:
                    del self.set_props[self.curr][command_input]
                    if len(self.set_props[self.curr]) == 0:
                        del self.set_props[self.curr]
                if command_input not in self.orig_props[self.curr]:
                    return
                if self.curr not in self.del_props:
                    self.del_props[self.curr] = []
                self.del_props[self.curr].append(command_input)

        elif command in ['copy', 'cp']:
            props = self.get_props()
            self.buffer = props.copy()
            print('Copied:')
            _print_props(props)

        elif command in ['clr']:
            if self.curr in self.set_props:
                del self.set_props[self.curr]
            if self.curr in self.del_props:
                del self.del_props[self.curr]

        elif command in ['clra']:
            if self.curr in self.set_props:
                del self.set_props[self.curr]
            if self.curr not in self.del_props:
                self.del_props = self.curr
            for k in self.get_props():
                if k not in self.del_props[self.curr]:
                    self.del_props[self.curr].append(k)

        elif command in ['paste', 'pt', 'paste-all', 'pta', 'rpt', 'rpaste']:
            replace = command in ['rpt', 'rpaste']
            to_all = command in ['paste-all', 'pta']

            self.paste(replace)
            self.print_curr()

            if to_all:
                name = self.get_name()
                started = self.curr
                first = True
                while first or started != self.curr:
                    if first:
                        first = False

                    found = self.find(lambda i: self.get_name(i) == name, self.curr)
                    if found != self.curr and found != started:
                        self.curr = found
                        self.paste()
                        self.print_curr()
                    else:
                        break

            self.repeat_last()

        elif command in ['print']:
            _print_all((self.get_props(i) for i in range(len(self.cards))), self.cards)
            if len(self.set_props) > 0 or len(self.del_props) > 0:
                print('Modified, not saved')
            else:
                print('Up-to-date with disk')
                
        elif command in ['fnext', 'fn']:
            self.find_next()

        elif command in ['exit', 'q']:
            return _confirm_props_modification(self.set_props, self.del_props, self.orig_props, self.cards),\
                   self.set_props, self.del_props
        elif command in ['help', 'h']:
            print_help()
        else:
            raise CommandNotFoundError()


def edit_properties(sheets: List[DeckSheet], cards: List[dict]):
    if len(sheets) == 0:
        raise AssertionError('Deck is seems to be empty')

    editor = Editor(sheets, cards)

    print_help()
    editor.print_curr()
    while True:
        try:
            res = editor.command(input('> '))
            if res:
                return res
        except CommandNotFoundError:
            print('Command not found')
            print_help()
        except Exception as e:
            print('ERROR')
            print(traceback.format_exc())


def write_changes(file, cards, add, rm):
    for curr, card in enumerate(cards):
        if 'Properties' not in card:
            card['Properties'] = {}
        cp = card['Properties']

        if curr in rm:
            for k in rm[curr]:
                del cp[k]
        if curr in add:
            for k, v in add[curr].items():
                cp[k] = v

    with open(file, 'w') as fp:
        json.dump(cards, fp, indent=2)
