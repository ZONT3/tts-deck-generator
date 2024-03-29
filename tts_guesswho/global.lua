--[[  Field Settings  ]]

GAME_ZONE_TL = Vector(-35.60, 1.48, 71.70)
GAME_ZONE_BR = Vector(35.60, 1.48, -71.70)
GAME_ZONE_W = 2
GAME_ZONE_H = 5

PLAYER_MAPPING_ID2K = {
    'White', 'Brown', 'Red',
    'Orange', 'Yellow', 'Green',
    'Teal', 'Blue', 'Purple', 'Pink'
}

--[[ Gane config ]]

ENABLE_ZERO_PAGE = false

DEFAULT_CONFIG = {
    shuffle_players_grid = false,
    shuffle_grid = true,
    one_page = true,
}

--[[  Pack config  ]]

CATEGORIES_ALIASES = {
    ['From Title'] = 'Title'
}

CAT_OTHER = 'Other'
CAT_SOURCE = 'Title Source'
CAT_GENRE = 'Title Genre'
BOOLEAN_CATEGORIES = {
    ['From Game'] = CAT_SOURCE,
    ['From Collection-RPG Game'] = CAT_SOURCE,
    ['From non-Asian Title'] = CAT_SOURCE,
    ['From non-Asian Animation'] = CAT_SOURCE,
    ['From Anime/Manga/Ranobe'] = CAT_SOURCE,
    ['Title Genre - Romance'] = CAT_GENRE,
    ['Title Genre - Harem-Like'] = CAT_GENRE,
}

--[[  Advanced field settings  ]]

PLAYER_ZONE_MARGIN = 1.0

CARD_W = 2.0
CARD_H = 3.0
CARD_MIN_MARGIN = 0.1 -- can be negative to enable overlapping
CARD_OVERLAP_STEP = 0.02 -- height to lift each new card

--[[  Objects  ]]

GUID_GRID_DECK_ZONE = '41563e'
GUID_HAND_DECK_ZONE = '3a3afd'
GUID_START_BUTTON = '35e1ac'
GUID_OPERATING_TABLE = 'a7d1ba'

GUIDS_REMOVE_AT_START = {'893b37'}

--[[  UI settings  ]]

FILTER_CELL_WIDTH = 300
FILTER_CELL_HEIGHT = 32
FILTER_CELL_CW = 2
FILTER_CELL_CH = 8

FILTER_PANE_WIDTH = (FILTER_CELL_CW * FILTER_CELL_WIDTH + (FILTER_CELL_CW - 1) * 4) / 0.7
FILTER_PANE_HEIGHT = (FILTER_CELL_CH * FILTER_CELL_HEIGHT + (FILTER_CELL_CH - 1) * 4) / 0.9
FILTER_PANE_BUTTONS_SIZE = FILTER_PANE_HEIGHT * 0.05

--[[  System  ]]

POS_OPERATING_TABLE = Vector({0.00, -2, 85.77})

CONTROL_TABLE_ELEVATION = -0.95
CONTROL_TABLE_SIZE_KOEF = 500
CONTROL_TABLE_W = 27
CONTROL_TABLE_H = 16.8

--[[  Lang  ]]

LANG = {}
LANG.PICKED = 'Players picked:<br/><b>%d / %d</b>'
LANG.ONLY_PICKED = 'Start with only picked players (%d/%d)'
LANG.RANDOM_ALL = 'Pick random for all players and start'
LANG.RANDOM_OTHER = 'Pick random for all players, who didn\'t pick (%d) and start'


function DIAG_Time(label, fnc)
    local st = os.time() * 1000
    local res = table.pack(fnc())
    local et = os.time() * 1000
    log(label..": "..(et - st).."ms")
    return table.unpack(res)
end

function Vec2f(x, y)
    if type(x) == "userdata" then
        return Vector(x.x, 0, x.z)
    end
    return Vector(x, 0, y)
end

function RotToDir(rotation)
    local v = Vector(0, 0, 1)
    v:rotateOver('x', rotation.x)
    v:rotateOver('y', rotation.y)
    v:rotateOver('z', rotation.z)
    return v
end

function TblAdd(dest, src, inherit)
    for k,v in pairs(src or {}) do
        if inherit ~= true or dest[k] == nil then
            dest[k] = v
        end
    end
end

function TblShallowCopy(t)
    local t2 = {}
    for k,v in pairs(t) do
        t2[k] = v
    end
    return t2
end

function TblLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function FlipKV(tbl, fill_instead)
    local tmp = {}
    local i = 1
    for k, v in pairs(tbl) do
        if not not v then
            if v == true then
                v = i
                i = i + 1
            end

            if fill_instead ~= nil then
                tmp[v] = fill_instead
            else
                tmp[v] = k
            end
        end
    end
    return tmp
end

function TblValCount(tbl)
    local tmp = {}
    for _, v in pairs(tbl) do
        tmp[v] = (tmp[v] or 0) + 1
    end
    return tmp
end

function SplitStr(str, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for s in string.gmatch(str, "([^"..sep.."]+)") do
        table.insert(t, s)
    end
    return t
end

function TrimStr(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function StartsWith(str, prefix)
    return string.sub(str,1,string.len(prefix))==prefix
 end

function PropertiesToTable(str)
    local lines = SplitStr(str, '\n;')
    local tbl = {}
    for _, line in ipairs(lines) do
        local kv = SplitStr(line, ':')
        tbl[kv[1]] = kv[2] and TrimStr(kv[2]) or true
    end
    return tbl
end

function SetTooltip(id, text)
    UI.setAttribute(id, 'tooltip', text)
    UI.setAttribute(id, 'textColor', '#F0F0F0')
end


PLAYER_MAPPING_K2ID = FlipKV(PLAYER_MAPPING_ID2K)


function Card(inf, deck, deck_hand)
    if not inf or not inf.name then print('ERROR: Cannot init card: not inf'); return end

    local meta = {}

    if not deck then
        for k, v in pairs(inf) do
            meta[k] = v
        end
    else
        meta.properties = PropertiesToTable(inf.description or {})
        meta.name = inf.name
        meta.guid = inf.guid
        meta.guid_hand = inf.guid_hand

        meta.properties['uniqueName'] = meta.name
    end

    function meta:WriteProperties()
        self:Operate(function (obj, hand)
            local str = ''
            for k, v in pairs(self.properties) do
                if v then
                    if v == true then
                        str = str..(#str > 0 and '\n' or '')..k
                    else
                        str = str..(#str > 0 and '\n' or '')..k..': '..v
                    end
                end
            end
            obj.setDescription(str)
            hand.setDescription(str)
        end)
    end

    function meta:GetName()
        return self.properties['uniqueName'] or self.name
    end

    function meta:SetName(name)
        self.properties['uniqueName'] = name
        self:WriteProperties()
    end

    function meta:GetJSON()
        if not self.data then
            self.data, self.data_hand = self:Operate(function(obj, hand)
                return obj.getJSON(), hand.getJSON()
            end)
        end
        return self.data, self.data_hand
    end

    function meta:Operate(fnc)
        if not self.operating then
            local ref_grid = getObjectFromGUID(self.guid)
            local ref_hand = getObjectFromGUID(self.guid_hand)

            if not ref_grid and deck then
                ref_grid = deck.takeObject({
                    position = POS_OPERATING_TABLE,
                    guid = self.guid,
                    smooth = false,
                })
                ref_hand = deck_hand.takeObject({
                    position = POS_OPERATING_TABLE,
                    guid = self.guid_hand,
                    smooth = false,
                })
            elseif ref_grid and ref_hand then
                ref_grid.setPosition(POS_OPERATING_TABLE)
                ref_hand.setPosition(POS_OPERATING_TABLE)
            else
                print('ERROR: Ref to card not found')
                return
            end
            ref_grid.setLock(true)
            ref_hand.setLock(true)

            self.data = nil
            self.data_hand = nil

            self.operating = ref_grid
            self.operating_hand = ref_hand
        end

        return fnc(self.operating, self.operating_hand)
    end

    return meta
end

STAGE_PICKING = 1
STAGE_PLAY = 2

GW_GAME = {}
GW_GAME.data = {}
GW_GAME.config = {}

function GW_GAME:InitGame()
    log(' ==== GW Game Init ==== ')
    self.data.init_done = false
    self.data.game_started = false

    self.data.stage = STAGE_PICKING
    self.data.players = {}
    self.data.prepared_players = {}

    if self.objects then
        for _, v in pairs(self.objects) do
            if v then
                v.destroyObject()
            end
        end
    end
    self.objects = {}

    TblAdd(self.config, DEFAULT_CONFIG, true)
    self.data.config = self.config

    for _, guid in ipairs(GUIDS_REMOVE_AT_START) do
        local obj = getObjectFromGUID(guid)
        if obj then obj.destroyObject() end
    end

    local card_list = DIAG_Time('LoadCards', function()
        return self:LoadCards()
    end)
    DIAG_Time('FixNameCollisions', function()
        self:FixNameCollisions(card_list)
    end)
    DIAG_Time('InitCards', function()
        self:InitCards(card_list)
    end)
    DIAG_Time('InitFilters', function()
        self.data.filters, self.data.filter_categories, self.data.filter_order = self:InitFilters(card_list)
    end)
    DIAG_Time('GenerateCardsCache', function()
        self.data.cards_cache = self:GenerateCardsCache(card_list)
    end)

    DIAG_Time('GenerateGridZones', function()
        self.data.player_zones = self:GenerateGridZones(GAME_ZONE_TL, GAME_ZONE_BR, GAME_ZONE_W, GAME_ZONE_H, PLAYER_ZONE_MARGIN)
        self.data.game_height = math.max(GAME_ZONE_TL.y, GAME_ZONE_BR.y)
    end)
    DIAG_Time('InitZones', function()
        self:InitZones()
    end)

    UI.show('pickTip')
    UI.show('pickCounter')

    UI.hide('configPane')
    UI.hide('startPick')
    UI.show('pickDone')

    UI.hide('onlyPicked')
    UI.hide('randAll')

    UI.setValue('pickCounter', string.format(LANG.PICKED, 0, #self:GetPlayers()))
    SetTooltip('startNow', LANG.RANDOM_ALL)
    SetTooltip('randAll', LANG.RANDOM_ALL)

    self.data.init_done = true
end

function GW_GAME:PickDone(type)
    if TblLength(self.data.prepared_players or {}) == 0 then
        self:StartGame(true, true)
    else
        self:StartGame(type >= 2, type == 3)
    end

    UI.hide('pickDone')
    UI.hide('pickCounter')
    UI.hide('pickTip')
end

function GW_GAME:StartGame(randomize, all)
    self.data.stage = STAGE_PLAY

    self:HidePickUI()
    DIAG_Time('InitPlayers', function()
        self:InitPlayers(randomize, all)
    end)

    DIAG_Time('UiInitFilters', function()
        self:UiInitFilters()
        UI.show('openFilters')
    end)

    self.data.game_started = true
end

function GW_GAME:InitPlayers(randomize, all)
    for _, p in ipairs(self:GetPlayers()) do
        local name = self.data.prepared_players[p.color]
        if all or not name and randomize then
            name = true
        end

        if name then
            name = self:InitPlayer(p.color, name)
            self:SetPage(p.color, 1)
            for _, pp in ipairs(self:GetPlayers()) do
                if p.color ~= pp.color then
                    local obj = self:DuplicateHandCard(self:FindCard(name, self.cards_ordered))
                    obj.setName('['..Color.fromString(p.color):toHex(false)..']'..obj.getName())
                    obj.setDescription(p.steam_name.."'s guess target\n\n"..obj.getDescription())
                    obj.deal(1, pp.color)
                end
            end
        end
    end
end

function GW_GAME:InitPlayer(player, card_name)
    local data = {}

    local pl_id = PLAYER_MAPPING_K2ID[player]
    local rotate = true
    local card_w = not rotate and CARD_W or CARD_H
    local card_h = not rotate and CARD_H or CARD_W

    local zone = self.data.player_zones[pl_id]
    local zw = zone.br.x - zone.tl.x
    local zh = zone.tl.z - zone.br.z
    local w = math.floor(zw / (card_w + math.max(CARD_MIN_MARGIN, - CARD_W * 0.8)))
    local h = math.floor(zh / card_h)
    data.grid = self:GenerateGridPoints(zone.tl, zone.br, w, h)

    self.data.page_len = self.data.page_len and math.min(self.data.page_len, #data.grid) or #data.grid

    if not self.cards_ordered then
        self.cards_ordered = self:InitCardsOrdered()
    end

    if card_name == true then
        card_name = self.cards_ordered[math.random(#self.cards_ordered)]:GetName()
    end

    data.card_name = card_name
    data.cards_ordered = self:InitPlyCardsOrdered(self.cards_ordered)
    data.card_states = self:InitCardStates(self.cards_ordered)
    data.displayed = {}
    data.page = 0

    if not self.data.config.one_page then
        self.objects['cdesk:'..player] = self:SpawnControlDesk(player)
        self:InitControlDesk(player, math.ceil(#data.cards_ordered / #data.grid))
    end

    self.data.players[player] = data

    return card_name
end

function GW_GAME:InitZones()
    for _, obj in ipairs(getObjects()) do
        if obj.getDescription == '$playerZone' then
            destroyObject(obj)
        end
    end

    self.data.player_zones_objs = {}

    for i, z in ipairs(self.data.player_zones) do
        local hw = (z.br.x - z.tl.x) / 2
        local hh = (z.tl.z - z.br.z) / 2
        local pos = Vector(
                z.tl.x + hw,
                self.data.game_height,
                z.br.z + hh)
        local scale = Vector(hw * 2, 2, hh * 2)
        local name = PLAYER_MAPPING_ID2K[i]

        local obj = spawnObject({
            type = 'ScriptingTrigger',
            position = pos,
            scale = scale,
            sound = false,
            callback_function=function(obj)
                obj.setName(name)
                obj.setDescription('$playerZone')
                obj.addTag('gridZone')
                obj.addTag(self:PlyTag(name, 'gridZone'))
            end
        })
        self.data.player_zones_objs[i] = obj.guid
    end
end

function GW_GAME:PlayerBlindfoldChanged(states)
    if self.data.stage ~= STAGE_PICKING then return end

    local total = 0
    local picked = 0
    for _, ply in ipairs(self:GetPlayers()) do
        total = total + 1
        if self.data.prepared_players[ply.color] then
            picked = picked + 1
        end
    end
    local all_picked = picked >= total

    if self.data.picking_player and not states[self.data.picking_player] then
        -- player stopped being picking one
        local result = self.data.prepared_players[self.data.picking_player]
        for _, ply in ipairs(self:GetPlayers()) do
            if ply.color ~= self.data.picking_player then
                ply.broadcast(self.data.picking_player.." Pick results: "..(result or 'NONE'), Color.fromString(self.data.picking_player))
            end
        end
        self.data.picking_player = nil

    elseif self.data.picking_player then
        -- player is still picking
        return
    end

    -- trying to find another picker
    for ply, bool in pairs(states) do
        if bool then
            self.data.picking_player = ply
            break
        end
    end

    if self.data.picking_player then
        -- found new picker
        UI.hide('pickTip')
        self:ShowPickUI(self.data.picking_player)
        broadcastToAll("Now picking for: "..self.data.picking_player, self.data.picking_player)
    else
        -- no one is picking
        self:HidePickUI()
        if not all_picked then
            UI.show('pickTip')
        end
    end
end

function GW_GAME:OnPickCard(deck, obj)
    if not self.data.picked_now then self.data.picked_now = {} end
    table.insert(self.data.picked_now, {guid = obj.getGUID(), name = self:GetCardName(obj)})
end

function GW_GAME:GetCardName(obj)
    local prop = PropertiesToTable(obj.getDescription())
    return prop['uniqueName'] or obj.getName()
end

function GW_GAME:UpdPickDeck()
    local deck = getObjectFromGUID(self.data.pick_deck_guid)
    if not deck and (not self.data.picked_now or #self.data.picked_now == 0) then return end

    Wait.frames(function ()
        local objs = self.data.picked_now
        local names = {}

        for _, d in ipairs(self.data.picked_now) do
            table.insert(names, d.name)
        end

        if self.data.picking_player and #objs > 0 then
            local result = names[math.random(#names)]

            self.data.prepared_players[self.data.picking_player] = result

            log(self.data.picking_player..': '..result)
            for _, ply in ipairs(self:GetPlayers()) do
                if ply.color ~= self.data.picking_player then
                    ply.broadcast("Selected: "..(result or 'NONE'), Color.fromString(self.data.picking_player))
                end
            end
        end

        self.data.picked_now = {}
        for _, d in ipairs(objs) do
            local obj = getObjectFromGUID(d.guid)
            if obj then
                deck.putObject(obj)
            end
        end

        self:UpdPicked()
    end)
end

function GW_GAME:UpdPicked()
    local total = 0
    local picked = 0
    for _, ply in ipairs(self:GetPlayers()) do
        total = total + 1
        if self.data.prepared_players[ply.color] then
            picked = picked + 1
        end
    end
    local all_picked = picked >= total

    UI.setValue("pickCounter", string.format(LANG.PICKED, picked, total))

    if all_picked then
        SetTooltip("startNow", "")
        UI.show("randAll")
        UI.hide("onlyPicked")
    elseif picked > 0 then
        SetTooltip("startNow", LANG.RANDOM_OTHER:format(total - picked))
        UI.show("randAll")
        UI.show("onlyPicked")
    else
        SetTooltip("startNow", LANG.RANDOM_ALL)
        UI.hide("randAll")
        UI.hide("onlyPicked")
    end

    SetTooltip('onlyPicked', LANG.ONLY_PICKED:format(picked, total))
end

function GW_GAME:ShowPickUI(picking_player)
    if not self.data.hand_deck_json then
        print('ERROR: Cannot find pick deck.')
        return
    end

    local deck = self.data.pick_deck_guid and getObjectFromGUID(self.data.pick_deck_guid)
    if deck then
        deck.UI.setValue('name', string.format('Now picking for:<br/><textcolor color="#%s"><b>%s</b></textcolor>',
            Color.fromString(picking_player):toHex(), self:GetPlyName(picking_player)))
        return
    end

    deck = spawnObjectJSON({
        position = {0, self.data.game_height, 0},
        rotation = {0, 0, 180},
        json = self.data.hand_deck_json
    })

    deck.setLock(false)
    deck.UI.setXml(string.format('<Text position="0 250 0" rotation="0 180 180" fontSize="36" outline="#202020" color="#FFFFFF">'..
                   'Use "Search" context action (RMB)<br/>and drag onto table desired card!</Text>'..
                   '<Text id="name" position="0 -250 0" rotation="0 180 180" fontSize="36" outline="#202020" color="#FFFFFF">'..
                   'Now picking for:<br/><textcolor color="#%s"><b>%s</b></textcolor></Text>', Color.fromString(picking_player):toHex(), self:GetPlyName(picking_player)))

    self.data.pick_deck_guid = deck.getGUID()
end

function GW_GAME:GetPlyName(ply)
    ply = self:GetPlyInst(ply)
    if ply then
        return ply.steam_name
    end
end

function GW_GAME:HidePickUI()
    local deck = getObjectFromGUID(self.data.pick_deck_guid)
    if deck then
        destroyObject(deck)
    end
end

function GW_GAME:SpawnControlDesk(player)
    local ply = self:GetPlyInst(player)
    local transform = ply.getHandTransform()
    local r = Vector({0, transform.rotation.y, 0})
    local pos = transform.position - RotToDir(r) * 12

    local desk = getObjectFromGUID(GUID_OPERATING_TABLE)
    local cdesk = self:DuplicateObj(
        desk.getJSON(),
        {pos.x, CONTROL_TABLE_ELEVATION, pos.z},
        {0, -r.y, 0}, {scale = {0.85,1,1}})

    cdesk.UI.setXml(desk.UI.getXml())

    return cdesk
end

function GW_GAME:InitControlDesk(player, num_pages)
    local cdesk = self:GetControlDesk(player)

    self:CDeskInitPages(player, cdesk, num_pages)

    local try = function ()
        cdesk.UI.show('main')
    end
    Wait.condition(try, function () return not cdesk.UI.loading end, 15, function()
        print('ERROR: Cannot load control desk UI')
    end)
end

function GW_GAME:CDeskInitPages(player, cdesk, num_pages)
    local max_page = num_pages
    num_pages = num_pages + (ENABLE_ZERO_PAGE and 1 or 0)

    local desk_w = CONTROL_TABLE_W
    local desk_h = CONTROL_TABLE_H
    local k = CONTROL_TABLE_SIZE_KOEF

    local center = 0
    local space = 0.05
    local size = 220 / k

    local max_bt_count = math.floor(desk_w / (space + size))
    local num_buttons = math.min(max_bt_count, num_pages + 2)

    local width = size * num_buttons + space * (num_buttons - 1)
    local x = center - width / 2

    local this = self

    for i = 1, num_buttons do
        if i == 1 or i > num_pages + 1 then
            local fnc_name = "onClickPageChevron_"..player.."_"..i
            local left = i == 1
            local start = ENABLE_ZERO_PAGE and 0 or 1

            -- pizdets, tts govno
            _G[fnc_name] = function()
                local  page = this:PlayerData(player).page + (left and -1 or 1)
                if     page > max_page then page = start
                elseif page < start    then page = max_page end

                this:SetPage(player, page)
                -- this:UpdPageButtons(num_pages)
            end

            cdesk.createButton({
                label=tostring(string.char(left and 8249 or 8250)),
                font_size=200,
                width=size * k, height=size * k, position={x, 0.65, - desk_h / 2},
                click_function=fnc_name
            })

        else
            local page = i - (ENABLE_ZERO_PAGE and 2 or 1)
            local fnc_name = "onClickPageNum_"..player.."_"..page

            -- pizdets, tts govno
            _G[fnc_name] = function()
                this:SetPage(player, page)
                -- this:UpdPageButtons(num_pages)
            end

            cdesk.createButton({
                label=tostring(page), font_size=200,
                width=size * k, height=size * k, position={x, 0.65, - desk_h / 2},
                click_function=fnc_name
            })
        end
        x = x + size + space
    end
end

function GW_GAME:ToggleFilters(ply)
    self.filters_opened[ply] = not self.filters_opened[ply]

    local count = 0
    local players = {}
    for p, state in pairs(self.filters_opened) do
        if state then
            table.insert(players, p)
            if p ~= ply then count = count + 1 end
        end
    end

    local str = ''
    for _, v in ipairs(players) do
        if str ~= '' then
            str = str..'|'
        end
        str = str..v
    end

    UI.setAttribute("filtersPanel", "visibility", str)
    if str == '' then
        UI.setAttribute("filtersPanel", "active", "false")
    elseif count == 0 then
        UI.setAttribute("filtersPanel", "active", "true")
    end
end

function GW_GAME:InitFilters(card_list)
    local cat_map = {}
    local filter_order = {}

    for _, card in ipairs(card_list) do
        local properties = TblShallowCopy(card.properties)
        properties['Name'] = card.name

        for k, v in pairs(properties) do
            if k ~= 'uniqueName' then
                local alias = CATEGORIES_ALIASES[k]
                if alias then k = alias end

                local cur_cat = k
                local cur_f = v
                if type(v) ~= "string" then
                    cur_cat = BOOLEAN_CATEGORIES[k] or CAT_OTHER
                    cur_f = k
                end

                if not cat_map[cur_cat] then
                    cat_map[cur_cat] = {}
                end
                if not cat_map[cur_cat][cur_f] then
                    cat_map[cur_cat][cur_f] = {}
                    table.insert(filter_order, cur_f)
                end
                table.insert(cat_map[cur_cat][cur_f], card:GetName())
            end
        end
    end

    table.sort(filter_order)

    local cat_order = {}
    for cat, _ in pairs(cat_map) do
        if cat == 'Name' then
            table.insert(cat_order, 1, cat)
        elseif cat ~= CAT_OTHER then
            table.insert(cat_order, cat)
        end
    end
    if cat_map[CAT_OTHER] then
        table.insert(cat_order, CAT_OTHER)
    end

    return cat_map, cat_order, filter_order
end

function GW_GAME:UiInitFilters()
    local ui_xml = UI.getXmlTable()
    local panel_childs = getById(ui_xml, "filtersPanel").children

    local ply_panels = {}
    local ply_panels_sizes = {}
    local cat_btns = {}
    local cat_idx = 1
    for _, cat in ipairs(self.data.filter_categories) do
        local map = self.data.filters[cat]
        local fnc_name = "exposeFilters_"..cat_idx
        local cur_cat_idx = cat_idx
        _G[fnc_name] = function(ply) self:ExposeFilters(ply.color, cur_cat_idx) end
        table.insert(cat_btns, createButtonCategory(cat, fnc_name))

        for ply, data in pairs(self.data.players) do
            local show = not ply_panels[ply]
            if show then
                local panel, holder = createFilterPane(ply)
                ply_panels[ply] = holder
                ply_panels_sizes[ply] = 0
                table.insert(panel_childs, panel)
            end

            local columns = math.ceil(TblLength(map) / FILTER_CELL_CH)
            local width = columns * FILTER_CELL_WIDTH + (columns - 1) * 4

            local filter_pane = ply_panels[ply]
            local filter_grid, filter_grid_id = createFilterGrid(ply, cat_idx, width, show)

            if ply_panels_sizes[ply] < width then
                filter_pane.attributes.width = width
                ply_panels_sizes[ply] = width
            end

            if not data.filter_grids then data.filter_grids = {} end
            table.insert(data.filter_grids, filter_grid_id)
            table.insert(filter_pane.children, filter_grid)

            local filter_btns = {}
            local x_idx = 1
            local set = {}
            for _, filter in ipairs(self.data.filter_order) do
                local list = map[filter]
                if list and not set[filter] then
                    set[filter] = true
                    
                    local display_name = nil
                    local test = cat.." - "
                    if not StartsWith(filter, test) then
                        test = cat
                        if not StartsWith(filter, test) then
                            display_name = filter
                        end
                    end
                    if not display_name then
                        display_name = string.sub(filter, #test + 1)
                    end

                    local text = display_name.." ("..#list..")"
                    local fnc_name = "toggleFilter_"..cat_idx.."_"..x_idx.."_"..ply
                    local fnc_name_second = fnc_name.."_second"
                    local fnc_second_id = cat_idx.."_"..x_idx

                    _G[fnc_name] = function() self:ToggleCards(ply, list) end
                    _G[fnc_name_second] = function() self:ToggleCards(ply, list, fnc_second_id) end
                    table.insert(filter_btns, createButtonFilter(text, fnc_name, fnc_name_second))
                    x_idx = x_idx + 1
                end
            end

            filter_grid.children = filter_btns
        end

        cat_idx = cat_idx + 1
    end

    getById(ui_xml, "category").children = cat_btns
    getById(ui_xml, "filtersPanel").attributes.width = FILTER_PANE_WIDTH
    getById(ui_xml, "filtersPanel").attributes.height = FILTER_PANE_HEIGHT
    getById(ui_xml, "toggleAll").attributes.height = FILTER_PANE_BUTTONS_SIZE
    UI.setXmlTable(ui_xml)

    self.filters_opened = {}
end

function GW_GAME:ExposeFilters(ply, cat_idx)
    local data = self:PlayerData(ply)
    local cur_id = "filterList_"..ply.."_"..cat_idx
    for _, id in ipairs(data.filter_grids) do
        if id ~= cur_id then
            UI.hide(id)
        end
    end
    UI.show(cur_id)
end

function GW_GAME:ToggleCards(ply, list, inclusive)
    local on_table = self:GetCardsOnTable(ply)
    local data = self:PlayerData(ply)

    if not inclusive then
        local new_state = false
        for _, name in ipairs(list) do
            if not data.card_states[name] then
                new_state = true
                break
            end
        end

        for _, name in ipairs(list) do
            self:ToggleCard(ply, name, new_state, on_table)
        end

    else
        local same = data.last_inclusice == inclusive
        local invert = same

        local map = {}
        for _, name in ipairs(list) do
            map[name] = true
        end

        if same then
            for name, state in pairs(data.card_states) do
                if (map[name] ~= nil) == state then
                    invert = false
                    break
                end
            end
        end

        for name, _ in pairs(data.card_states) do
            if not map[name] then
                self:ToggleCard(ply, name, not invert, on_table)
            elseif same then
                self:ToggleCard(ply, name, invert, on_table)
            end
        end
    end

    data.last_inclusice = inclusive or nil
end

function GW_GAME:ToggleCard(ply, name, new_state, on_table_list)
    local data = self:PlayerData(ply)

    if new_state == nil then
        new_state = not data.card_states[name]
    end

    if not on_table_list then
        on_table_list = self:GetCardsOnTable(ply)
    end

    if data.card_states[name] ~= new_state then
        local obj = on_table_list[name]
        if obj then
            obj.flip()
        end
        data.card_states[name] = new_state
    end
end

function GW_GAME:GetCardsOnTable(ply)
    local on_table = {}
    local zone = self:GetPlyZone(ply)
    for _, obj in pairs(zone.getObjects()) do
        if obj then
            local card = self:GetCardName(obj)
            if card then
                on_table[card] = obj
            end
        end
    end
    return on_table
end

function GW_GAME:GetControlDesk(player)
    return self.objects['cdesk:'..player]
end

function GW_GAME:PlyTag(ply, tag)
    return (tag or 'tag')..':'..ply
end

function GW_GAME:CanPlayerFlip(ply, obj)
    local data = self:PlayerData(ply)
    if not data then return end

    if obj.hasTag(self:PlyTag(ply, 'gridZone')) then
        return true
    end

    for p, _ in pairs(self.data.players) do
        if p ~= ply then
            if obj.hasTag(self:PlyTag(p, 'gridZone')) then
                return false
            end
        end
    end

    return 0
end

function GW_GAME:CheckZoneEnterance(zone, obj)
    local owner_tag
    local player_owner

    for p, _ in pairs(self.data.players) do
        local tag = self:PlyTag(p, 'gridZone')
        if obj.hasTag(tag) then
            owner_tag = tag
            player_owner = p
            break
        end
    end

    if not owner_tag then return end

    if not zone.hasTag(owner_tag) then
        destroyObject(obj)

        self:RunLater(player_owner..':disturbing', function()
            broadcastToColor("DO NOT disturb other player's zones!", player_owner, Color.Red)
            self:SetPage(player_owner, true)
        end, true)
    end
end

function GW_GAME:RunLater(id, fnc, once)
    if not self.run_later then self.run_later = {} end
    if once then id = id..':once' end

    if self.run_later[id] and not once then
        table.insert(self.run_later[id], fnc)
        return
    end

    self.run_later[id] = {fnc}

    Wait.frames(function()
        if not self.run_later[id] then return end
        for _, f in ipairs(self.run_later[id]) do
            f()
        end
        self.run_later[id] = nil
    end, 30)
end

function GW_GAME:GetPlyZone(ply)
    return getObjectFromGUID(self.data.player_zones_objs[PLAYER_MAPPING_K2ID[ply]])
end

function GW_GAME:OnPlayerFlippedObj(ply, obj, invert)
    local data = self:PlayerData(ply)
    if not data then return end

    local state = obj.is_face_down
    if invert then
        state = not state
    end

    data.card_states[self:GetCardName(obj)] = state
end

function GW_GAME:FixNameCollisions(card_list)
    local names_set = {}
    local count = 0
    for _, card in ipairs(card_list) do
        local val = names_set[card:GetName()]
        if val then
            local old_name = card:GetName()

            if type(val) ~= "number" then
                local new_name = old_name .. ' (1)'
                val:SetName(new_name)

                val = 1
            end

            val = val + 1

            local new_name = old_name .. ' (' .. val .. ')'
            card:SetName(new_name)

            names_set[old_name] = val
            count = count + 1
        else
            names_set[card:GetName()] = card
        end
    end

    if count > 0 then
        log('Fixed ' .. count .. ' name collisions')
    end
end

function GW_GAME:PlayerData(ply)
    return self.data.players[ply]
end

function GW_GAME:InitCardStates(list)
    local res = {}
    for _, card in ipairs(list) do
        res[card:GetName()] = false
    end
    return res
end

function GW_GAME:FindCard(name, list)
    for _, card in ipairs(list or self:GetCardList()) do
        if card:GetName() == name then
            return card
        end
    end
end

function GW_GAME:GetCardList()
    if not self.data.cards_cache then
        self.data.cards_cache = self:GenerateCardsCache(self:LoadCards())
    end
    return self:FromCardsCache(self.data.cards_cache)
end

function GW_GAME:InitCards(card_list)
    local data_grid = {}
    local data_hand = {}

    for _, card in ipairs(card_list) do
        local g, h = card:GetJSON()
        table.insert(data_grid, g)
        table.insert(data_hand, h)
    end

    local pos_g1 = POS_OPERATING_TABLE - Vector(10, 0, -10)
    local pos_g2 = POS_OPERATING_TABLE - Vector(10, 0, -20)
    local pos_h1 = POS_OPERATING_TABLE - Vector(-10, 0, -10)
    local pos_h2 = POS_OPERATING_TABLE - Vector(-10, 0, -20)

    local deck_g
    local deck_h

    for i, grid in ipairs(data_grid) do
        local hand = data_hand[i]

        local g = self:DuplicateObj(grid, i == 1 and pos_g1 or pos_g2)
        local h = self:DuplicateObj(hand, i == 1 and pos_h1 or pos_h2)
        g.setLock(false)
        h.setLock(false)

        if i == 1 then
            deck_g = g
            deck_h = h
        else
            deck_g = deck_g.putObject(g)
            deck_h = deck_h.putObject(h)
            deck_g.setPosition(pos_g1)
            deck_h.setPosition(pos_h1)
        end
    end

    self.data.grid_deck_json = deck_g.getJSON()
    self.data.hand_deck_json = deck_h.getJSON()

    destroyObject(deck_g)
    destroyObject(deck_h)
end

function GW_GAME:InitDecks()
    for name, guid in pairs({
        ['grid'] = GUID_GRID_DECK_ZONE,
        ['hand'] = GUID_HAND_DECK_ZONE
    }) do
        local field = name .. '_deck'
        if not self[field] then
            local deck = nil
            for _, obj in ipairs(getObjectFromGUID(guid).getObjects()) do
                if obj.type == 'Deck' or obj.type == 'DeckCustom' then
                    deck = obj
                    break
                end
            end
            if not deck then
                print('ERROR: '..name..' deck not found!')
            else
                log(field..' deck found: '..deck.getGUID())
                self[field] = deck.getGUID()
            end
        end
    end
end

function GW_GAME:LoadCards()
    self:InitDecks()

    local res = {}
    local deck = getObjectFromGUID(self.grid_deck)
    local deck_hand = getObjectFromGUID(self.hand_deck)

    local objs = deck.getObjects()
    local objs_hand = deck_hand.getObjects()
    if #objs ~= #objs_hand then
        print('ERROR: Decks size not equal!')
        return
    end

    for i, obj in ipairs(objs) do
        obj.guid_hand = objs_hand[i].guid
        table.insert(res, Card(obj, deck, deck_hand))
    end

    return res
end

function GW_GAME:GenerateCardsCache(tbl)
    local res = {}
    for _, i in ipairs(tbl) do
        table.insert(res, {
            name = i.name,
            properties = i.properties,
            guid_hand = i.guid_hand,
            guid = i.guid,
            data_hand = i.data_hand,
            data = i.data,
        })
    end
    return res
end

function GW_GAME:FromCardsCache(tbl)
    local res = {}
    for _, i in ipairs(tbl) do
        table.insert(res, Card(i))
    end
    return res
end

function GW_GAME:InitCardsOrdered()
    local list = self:GetCardList()
    local shuffle = self.data.config.shuffle_grid

    if shuffle then
        local weighted = {}
        for _, card in ipairs(list) do
            local name = card:GetName()
            weighted[name] = math.random()
        end
        table.sort(list, function(a, b) return weighted[a:GetName()] < weighted[b:GetName()] end)
    end

    if self.data.config.one_page then
        local res = {}
        local map = TblValCount(self.data.prepared_players)
        local plys = TblLength(self.data.prepared_players)
        local count = math.min(self.data.page_len, #list)

        for i, card in ipairs(list) do
            local name = card:GetName()
            local mapped = map[name] or 0
            if i <= count - plys or mapped > 0 then
                if mapped then
                    plys = plys - mapped
                end

                local x = #res
                table.insert(res, x > 1 and math.random(x) or 1, card)
            end
            if #res >= count then
                break
            end
        end

        return res
    else
        return list
    end
end

function GW_GAME:InitPlyCardsOrdered(list)
    local shuffle = self.data.config.shuffle_players_grid
    if not shuffle and self.data.static_order then
        return self.data.static_order

    else
        local sorted = {}
        if shuffle then
            local weighted = {}
            for _, card in ipairs(list) do
                local k = card:GetName()
                weighted[k] = math.random()
                table.insert(sorted, k)
            end
            table.sort(sorted, function(a, b) return weighted[a] < weighted[b] end)

        else
            for _, card in ipairs(list) do
                table.insert(sorted, card:GetName())
            end
            self.data.static_order = sorted
        end

        return sorted
    end
end

function GW_GAME:GetPlayers()
    local t = {}
    for _, player in ipairs(Player.getPlayers()) do
        if PLAYER_MAPPING_K2ID[player.color] then
            table.insert(t, player)
        end
    end
    return t
end

function GW_GAME:GetPlyInst(ply)
    for _, player in ipairs(self:GetPlayers()) do
        if player.color == ply then
            return player
        end
    end
end

function GW_GAME:SetPage(ply, idx)
    local data = self:PlayerData(ply)

    if not data then return end
    if idx == data.page then return end

    if not idx then idx = data.page + 1 end
    if idx == true then idx = data.page end

    local page_len = #data.grid
    local ordered = data.cards_ordered
    local pages_total = math.ceil(#ordered / page_len)

    if idx < 0 then idx = pages_total - idx + 1 end
    if idx > pages_total then 
        idx = (idx % pages_total)
        idx = idx > 0 and idx or pages_total
    end

    local fnc_clear = function ()
        local zone = self:GetPlyZone(ply)
        for _, obj in pairs(zone.getObjects()) do
            if obj then
                destroyObject(obj)
            end
        end
        data.page = 0
    end

    if idx == 0 then
        Wait.frames(fnc_clear)

    else
        local start = page_len * (idx - 1) + 1
        local stop = start + page_len - 1
        local rotation = self:GetPlyInst(ply).getHandTransform().rotation
        local list = self:GetCardList()

        rotation.y = (rotation.y + 180) % 360

        local fnc = function()
            for i = start, stop do
                if #ordered < i then
                    break
                end

                local diff = i - start
                local pos = data.grid[diff + 1]
                pos = {
                    pos.x,
                    self.data.game_height + (CARD_MIN_MARGIN <= 0 and diff * CARD_OVERLAP_STEP or 0),
                    pos.z
                }
                local card_name = ordered[i]
                local card = self:FindCard(card_name, list)
                local flipped = data.card_states[card_name]
                local r = {rotation.x, rotation.y, flipped and 180 or 0}

                local obj = self:DuplicateCard(card, pos, r)
                obj.setLock(false)
                obj.addTag('gridZone')
                obj.addTag(self:PlyTag(ply, 'gridZone'))
            end
            data.page = idx
        end

        Wait.frames(function ()
            fnc_clear()
            Wait.frames(fnc)
        end)
    end
end

function GW_GAME:DuplicateObj(data, pos, r, rest)
    local tbl = {
        position = pos or POS_OPERATING_TABLE,
        rotation = r or {0, 0, 0},
        json = data,
    }
    TblAdd(tbl, rest)
    return spawnObjectJSON(tbl)
end

function GW_GAME:DuplicateCard(card, pos, r)
    return self:DuplicateObj(select(1, card:GetJSON()), pos, r)
end

function GW_GAME:DuplicateHandCard(card, pos, r)
    return self:DuplicateObj(select(2, card:GetJSON()), pos, r)
end

function GW_GAME:OnCardLeft(obj)
    for p, d in pairs(self.data.players) do
        if d.data.displayed then
            for guid, pos in pairs(d.data.displayed) do
                if guid == obj.getGUID() then
                    obj.setPositionSmooth(pos.pos, false, true)
                    obj.setRotationSmooth(pos.r, false, true)
                    broadcastToColor('Do not pull your cards out of your zone!', p, Color.Orange)
                    break
                end
            end
        end
    end
end

function GW_GAME:Vec2fTo3f(vec)
    return Vector(vec.x, self.data.game_height, vec.z)
end

function GW_GAME:GenerateGridZones(p_tl, p_br, w, h, margin)
    local left = p_tl.x
    local top = p_tl.z
    local right = p_br.x
    local bot = p_br.z
    margin = margin or 0

    -- fixing wrong orientation
    if left > right then
        local b = left
        left = right
        right = b
    end
    if bot > top then
        local b = top
        top = bot
        bot = b
    end

    w = w or 2
    h = h or 5

    local cell_w = (right - left - margin * w) / w
    local cell_h = (top - bot - margin * h) / h
    left = left + margin / 2
    bot = bot + margin / 2

    local res = {}
    local d = 1
    for i = 1, w do
        for j = d > 0 and 1 or h, d > 0 and h or 1, d do
            local startx = left + (cell_w + margin) * (i - 1)
            local starty = bot + (cell_h + margin) * (j - 1)
            res[#res + 1] = {
                tl = Vec2f(startx, starty + cell_h),
                br = Vec2f(startx + cell_w, starty)
            }
        end
        d = -d
    end
    return res
end

function GW_GAME:GenerateGridPoints(p_tl, p_br, w, h)
    local res = {}
    for _, p in ipairs(self:GenerateGridZones(p_tl, p_br, w, h)) do
        local left = p.tl.x < p.br.x and p.tl.x or p.br.x
        local right = p.tl.x < p.br.x and p.br.x or p.tl.x
        local top = p.tl.z > p.br.z and p.tl.z or p.br.z
        local bot = p.tl.z > p.br.z and p.br.z or p.tl.z
        res[#res + 1] = Vec2f(left + (right - left) / 2, bot + (top - bot) / 2)
    end
    return res
end


-- UI Functions
function getDefaults(data)
    return getByTag(data, 'Defaults')[1]
end

function getByTag(data, tag, recursive)
    local res = {}

    for _, node in ipairs(data) do
        local add = recursive ~= false and node.children and getByTag(node.children, tag) or {}
        if node.tag == tag then
            table.insert(add, node)
        end
        for _, n in ipairs(add) do
            table.insert(res, n)
        end
    end

    return res
end

function getById(data, id, recursive)
    for _, node in ipairs(data) do
        if node.attributes and node.attributes.id == id then
            return node
        end

        if recursive ~= false and node.children then
            local res = getById(node.children, id)
            if res then
                return res
            end
        end
    end
end

function createButtonCategory(text, fnc_name)
    return {
        tag="Panel",
        attributes={
            preferredheight=64,
        },
        children={
            {
                tag="Button",
                attributes={
                    onClick="Global/"..(fnc_name or "none"),
                },
                value=text or "---",
            }
        }
    }
end

function createButtonFilter(text, fnc_name, fnc_name_second)
    return {
        tag="Panel",
        attributes={
            width="100%",
            height="100%",
        },
        children={
            {
                tag="Button",
                attributes={
                    onClick="Global/"..(fnc_name or "none"),
                    fontSize="14",
                    width="85%",
                    rectAlignment="MiddleLeft",
                },
                value=text or "---",
            },
            {
                tag="Button",
                attributes={
                    onClick="Global/"..(fnc_name_second or "none"),
                    fontSize="24",
                    width="15%",
                    rectAlignment="MiddleRight",
                },
                value="O",
            }
        }
    }
end

function createFilterPane(ply)
    local holder = {
        tag="Panel",
        attributes={
            height="100%",
            width="100%",
        },
        children={},
    }
    local pane = {
        tag="HorizontalScrollView",
        attributes={
            visibility=ply,
            height="95%",
            width="70%",
            rectAlignment="LowerRight",
        },
        children={
            holder
        }
    }
    return pane, holder
end

function createFilterGrid(ply, cat_idx, width, show)
    local id = "filterList_"..ply.."_"..cat_idx
    return {
        tag="GridLayout",
        attributes={
            id=id,
            active=show and "true" or "false",
            rectAlignment="UpperLeft",
            width=width,
            height="100%",
            childAlignment="UpperLeft",
            cellSize=FILTER_CELL_WIDTH.." "..FILTER_CELL_HEIGHT,
            spacing="4 4",
            startAxis="Vertical",
            constraint="FixedRowCount",
            constraintCount=""..FILTER_CELL_CH,
        }
    }, id
end


-- Load/Save

function onSave()
    -- if GW_GAME.data.init_done then
    --     GW_GAME.data.objects = {}
    --     for k, v in pairs(GW_GAME.objects) do
    --         if v then
    --             GW_GAME.data.objects[k] = v.guid
    --         end
    --     end
    --     return JSON.encode(GW_GAME.data)
    -- end
end

function onLoad(state)
    -- if #state > 0 then
    --    GW_GAME.data = JSON.decode(state)
    --     for k, v in pairs(GW_GAME.data.objects) do
    --         if not GW_GAME.objects[k] then
    --             GW_GAME.objects[k] = getObjectFromGUID(v)
    --         end
    --     end
    -- end
end


-- BUTTONS

function onClickStartPick()
    GW_GAME:InitGame()
end

function onClickPickDone()
    GW_GAME:PickDone(2)
end

function onClickOnlyPicked()
    GW_GAME:PickDone(1)
end

function onClickRandAll()
    GW_GAME:PickDone(3)
end

function onClickFilters(ply)
    GW_GAME:ToggleFilters(ply.color)
end

function onClickToggleAll(ply)
    local list = {}
    for x, _ in pairs(GW_GAME:PlayerData(ply.color).card_states) do
        table.insert(list, x)
    end
    GW_GAME:ToggleCards(ply.color, list)
end

function onToggleOnePage(ply, value)
    GW_GAME.config.one_page = value == "true"
end


-- EVENTS

function onBlindfold()
    if not GW_GAME.data.init_done    then return end
    if     GW_GAME.data.game_started then return end

    local tbl = {}
    for _, p in ipairs(GW_GAME:GetPlayers()) do
        tbl[p.color] = p.blindfolded
    end
    GW_GAME:PlayerBlindfoldChanged(tbl)
end

function onScriptingButtonUp(index, color)
    if not GW_GAME.data.game_started then return end
    if GW_GAME.data.config.one_page then return end
    GW_GAME:SetPage(color, index < 10 and index or nil)
end

function onPlayerAction(player, action, targets)
    for _, obj in ipairs(targets) do
        if obj.getGUID() == GW_GAME.data.pick_deck_guid and action ~= Player.Action.Select then
            return false
        end
    end

    if not GW_GAME.data.game_started then return end

    if action == Player.Action.FlipOver
        or action == Player.Action.FlipIncrementalLeft
        or action == Player.Action.FlipIncrementalRight
        or action == Player.Action.PickUp
    then
        local res = true
        for _, obj in ipairs(targets) do
            local can_he = GW_GAME:CanPlayerFlip(player.color, obj)
            if can_he == false then
                res = false
                broadcastToColor("DO NOT touch other player's cards!", player.color, Color.Red)
                break

            elseif action == Player.Action.FlipOver and can_he == true then
                GW_GAME:OnPlayerFlippedObj(player.color, obj, true)
            end
        end
        return res
    end

    return true
end

function onObjectDrop(player, obj)
    if not GW_GAME.data.game_started then
        updPickDeck()
        return
    end

    if GW_GAME:CanPlayerFlip(player, obj) then
        GW_GAME:OnPlayerFlippedObj(player, obj, false)
    end
end

function onObjectEnterZone(zone, object)
    if not GW_GAME.data.game_started then return end
    GW_GAME:CheckZoneEnterance(zone, object)
end

function onObjectLeaveContainer(container, object)
    if not GW_GAME.data.init_done    then return end
    if     GW_GAME.data.game_started then return end

    if container.getGUID() == GW_GAME.data.pick_deck_guid then
        GW_GAME:OnPickCard(container, object)
    end
end

function updPickDeck()
    if not GW_GAME.data.init_done    then return end
    if     GW_GAME.data.game_started then return end
    GW_GAME:UpdPickDeck()
end

function onObjectSearchEnd()
    updPickDeck()
end




-- OTHER

function none() end