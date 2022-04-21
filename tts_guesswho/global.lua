GAME_ZONE_TL = Vector(-35.60, 1.48, 71.70)
GAME_ZONE_BR = Vector(35.60, 1.48, -71.7)
GAME_ZONE_W = 2
GAME_ZONE_H = 5

PLAYER_ZONE_MARGIN = 1.0

CARD_W = 2.0
CARD_H = 3.0
CARD_MIN_MARGIN = 0.1 -- can be negative to enable overlapping
CARD_OVERLAP_STEP = 0.02 -- height to lift each new card

GUID_GRID_DECK_ZONE = '41563e'
GUID_HAND_DECK_ZONE = '3a3afd'
GUID_START_BUTTON = '35e1ac'
GUID_OPERATING_TABLE = 'a7d1ba'

POS_OPERATING_TABLE = Vector({0.00, -2, 85.77})

CONTROL_TABLE_ELEVATION = 1.0
CONTROL_TABLE_SIZE_KOEF = 500
CONTROL_TABLE_W = 16.8
CONTROL_TABLE_H = 31.5

ENABLE_ZERO_PAGE = true

PLAYER_ZONES_MAPPING_ID2K = {
    'White', 'Brown', 'Red', 
    'Orange', 'Yellow', 'Green', 
    'Teal', 'Blue', 'Purple', 'Pink'
}
ROTATED_PLAYERS = {2,3,4,7,8,9}

DEFAULT_CONFIG = {
    shuffle_players_grid = false,
}


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

function FlipKV(tbl)
    local tmp = {}
    for _, v in ipairs(tbl) do
        tmp[v] = true
    end
    return tmp
end

function split(str, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for s in string.gmatch(str, "([^"..sep.."]+)") do
        table.insert(t, s)
    end
    return t
end

function propertiesToTable(str)
    local lines = split(str, '%n;')
    local tbl = {}
    for _, line in ipairs(lines) do
        local kv = split(line, ':')
        tbl[kv[1]] = kv[2] or true
    end
    return tbl
end


ROTATED_PLAYERS = FlipKV(ROTATED_PLAYERS)

PLAYER_ZONES_MAPPING_K2ID = {}
for k, v in pairs(PLAYER_ZONES_MAPPING_ID2K) do
    PLAYER_ZONES_MAPPING_K2ID[v] = k
end


function Card(inf, deck, from_cache)
    if not inf or not inf.name then return end

    local meta = {}

    if not from_cache then
        meta.properties = propertiesToTable(inf.description or {})
        meta.name = inf.name
        meta.guid = inf.guid
    else
        for k, v in pairs(inf) do
            meta[k] = v
        end
    end

    function meta:GetData()
        if not self.data then
            self.data = self:Operate(function(obj)
                return obj.getData()
            end)
        end
        return self.data
    end

    function meta:Operate(fnc)
        if not self.operating then
            local ref = getObjectFromGUID(self.guid)
            if not ref and deck then
                ref = deck.takeObject({
                    position = POS_OPERATING_TABLE,
                    guid = self.guid,
                    smooth = false,
                })
            elseif ref then
                ref.setPosition(POS_OPERATING_TABLE)
            else
                print('ERROR: Ref to card not found')
                return
            end
            ref.setLock(true)
            self.data = nil
            self.operating = ref
        end

        return fnc(self.operating)
    end

    function meta:IsEqual(another)
        return self.name == another.name
    end

    return meta
end

STAGE_PICKING = 1
STAGE_PLAY = 2

GW_GAME = {}
GW_GAME.data = {}
GW_GAME.grid_locked = {}
GW_GAME.objects = {}

function GW_GAME:InitGame(config)
    print(' ==== GW Game Init ==== ')
    self.data.init_done = false
    self.data.stage = STAGE_PICKING
    self.data.players = {}
    self.data.prepared_players = {}

    for _, v in pairs(self.objects) do
        if v then
            v.destroyObject()
        end
    end
    self.objects = {}

    config = config or {}
    TblAdd(config, DEFAULT_CONFIG, true)
    self.data.config = config

    self:FixNameCollisions()

    self.data.player_zones = self:GenerateGridZones(GAME_ZONE_TL, GAME_ZONE_BR, GAME_ZONE_W, GAME_ZONE_H, PLAYER_ZONE_MARGIN)
    self.data.game_height = math.max(GAME_ZONE_TL.y, GAME_ZONE_BR.y)
    self:InitZones()

    self.data.init_done = true
end

function GW_GAME:InitPlayer(player, card_name)
    local data = {}

    data.card_name = card_name
    data.card_states = self:InitCardStates()
    data.cards_ordered = self:GetCardNamesOrdered(data.card_states)
    data.displayed = {}
    data.page = 0

    local pl_id = PLAYER_ZONES_MAPPING_K2ID[player]
    local rotate = ROTATED_PLAYERS[pl_id]
    local card_w = not rotate and CARD_W or CARD_H
    local card_h = not rotate and CARD_H or CARD_W

    local zone = self.data.player_zones[pl_id]
    local zw = zone.br.x - zone.tl.x
    local zh = zone.tl.z - zone.br.z
    local w = math.floor(zw / (card_w + math.max(CARD_MIN_MARGIN, - CARD_W * 0.8)))
    local h = math.floor(zh / card_h)
    data.grid = self:GenerateGridPoints(zone.tl, zone.br, w, h)
    
    self.objects['cdesk:'..player] = self:SpawnControlDesk(player)
    self:InitControlDesk(player, math.ceil(#data.cards_ordered / #data.grid))

    self.data.players[player] = data
end

function GW_GAME:StartGame()
    self.data.stage = STAGE_PLAY
    -- for p, name in pairs(self.data.prepared_players) do
    --     self:InitPlayer(p, name)
    --     self:SetPage(p, 1)
    -- end
    -- TEMP JUMPER
    local cards = self:GetGridCardList()
    for _, p in ipairs(Player.getPlayers()) do
        local card = cards[math.random(#cards)]
        self:InitPlayer(p.color, card.name)
        self:SetPage(p.color, 1)
        for _, pp in ipairs(Player.getPlayers()) do
            if p.color ~= pp.color then
                local obj = self:DuplicateCard(card)
                obj.setName('['..Color.fromString(p.color):toHex(false)..']'..card.name)
                obj.deal(1, pp.color)
            end
        end
    end
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
                log(field..' found: '..deck.getGUID(), 'GW')
                self[field] = deck
            end
        end
    end
end

function GW_GAME:InitZones()
    for _, obj in ipairs(getObjects()) do
        if obj.getDescription == '$playerZone' then
            destroyObject(obj)
        end
    end

    for i, z in ipairs(self.data.player_zones) do
        local hw = (z.br.x - z.tl.x) / 2
        local hh = (z.tl.z - z.br.z) / 2
        local pos = Vector(
                z.tl.x + hw,
                self.data.game_height,
                z.br.z + hh)
        local scale = Vector(hw * 2, 2, hh * 2)
        local name = PLAYER_ZONES_MAPPING_ID2K[i]

        spawnObject({
            type = 'ScriptingTrigger',
            position = pos,
            scale = scale,
            sound = false,
            callback_function=function(obj)
                obj.setName(name)
                obj.setDescription('$playerZone')
                obj.addTag(self:PlyTag(name, 'gridZone'))
            end
        })
    end
end

function GW_GAME:PlayerBlindfoldChanged(states)
    if self.data.stage ~= STAGE_PICKING then return end

    if self.data.picking_player and not states[self.data.picking_player] then
        -- player stopped being picking one
        -- TODO hide picking ui
        print(self.data.picking_player .. ": " .. self.data.prepared_players[self.data.picking_player])
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
        -- TODO show picking ui
        local cards = self:GetGridCardList()
        self.data.prepared_players[self.data.picking_player] = cards[math.random(#cards)].name
    end

    -- else no one is picking
end

function GW_GAME:SpawnControlDesk(player)
    local ply = self:GetPlyInst(player)
    local transform = ply.getHandTransform()
    local r = transform.rotation
    local pos = transform.position - RotToDir(r) * 12
    return self:DuplicateObj(
        getObjectFromGUID(GUID_OPERATING_TABLE).getData(),
        {pos.x, CONTROL_TABLE_ELEVATION, pos.z},
        {r.x, r.y, 180},
        {scale = {1,1,1}})
end

function GW_GAME:InitControlDesk(player, num_pages)
    local cdesk = self:GetControlDesk(player)

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
                font_size=200, rotation={0,180,180},
                width=size * k, height=size * k, position={x, -0.1, desk_w / 2},
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
                label=tostring(page), font_size=200, rotation={0,180,180},
                width=size * k, height=size * k, position={x, -0.1, desk_w / 2},
                click_function=fnc_name
            })
        end
        x = x + size + space
    end
end

function GW_GAME:GetControlDesk(player)
    return self.objects['cdesk:'..player]
end

function GW_GAME:PlyTag(ply, tag)
    return (tag or 'tag')..':'..ply
end

function GW_GAME:FixNameCollisions()
    local names_set = {}
    local count = 0
    local card_list = self:GetGridCardList()
    for _, card in ipairs(card_list) do
        local val = names_set[card.name]
        if val then
            local old_name = card.name

            if type(val) ~= "number" then
                local new_name = old_name .. ' (1)'
                val.name = new_name
                val:Operate(function (obj)
                    obj.setName(new_name)
                end)
                val = 1
            end

            val = val + 1

            local new_name = old_name .. ' (' .. val .. ')'
            card.name = new_name
            card:Operate(function (obj)
                obj.setName(new_name)
            end)

            names_set[old_name] = val
            count = count + 1
        else
            names_set[card.name] = card
        end
    end

    if count > 0 then
        self.data.grid_cards_cache = self:GenerateCardsCache(card_list)
        print('Fixed ' .. count .. ' name collisions')
    end
end

function GW_GAME:PlayerData(ply)
    return self.data.players[ply]
end

function GW_GAME:InitCardStates()
    local res = {}
    for _, card in ipairs(self:GetGridCardList()) do
        res[card.name] = false
    end
    return res
end

function GW_GAME:FindCard(name, list)
    for _, card in ipairs(list or self:GetGridCardList()) do
        if card.name == name then
            return card
        end
    end
end

function GW_GAME:GetGridCardList()
    if not self.data.grid_cards_cache then
        self:InitCardsCache()
    end
    return self:FromCardsCache(self.data.grid_cards_cache, self.grid_deck)
end

function GW_GAME:InitCardsCache()
    self:InitDecks()
    for _, name in ipairs({'grid', 'hand'}) do
        local res = {}
        local deck = self[name..'_deck']
        for _, obj in ipairs(deck.getObjects()) do
            table.insert(res, Card(obj, deck))
        end
        self.data[name..'_cards_cache'] = self:GenerateCardsCache(res)
    end
end

function GW_GAME:GenerateCardsCache(tbl)
    local res = {}
    for _, i in ipairs(tbl) do
        table.insert(res, {
            name = i.name,
            properties = i.properties,
            guid = i.guid,
            data = i.data,
        })
    end
    return res
end

function GW_GAME:FromCardsCache(tbl, deck)
    local res = {}
    for _, i in ipairs(tbl) do
        table.insert(res, Card(i, deck, true))
    end
    return res
end

function GW_GAME:GetCardNamesOrdered(card_set)
    local shuffle = self.data.config.shuffle_players_grid
    if not shuffle and self.data.static_order then
        return self.data.static_order
    else
        local weighted = {}
        local sorted = {}
        for k, _ in pairs(card_set) do
            weighted[k] = math.random()
            table.insert(sorted, k)
        end
        table.sort(sorted, function(a, b) return weighted[a] < weighted[b] end)
        return sorted
    end
end

function GW_GAME:GetPlyInst(ply)
    for _, player in ipairs(Player.getPlayers()) do
        if player.color == ply then
            return player
        end
    end
end

function GW_GAME:SetPage(ply, idx)
    if self.grid_locked[ply] then return end
    local data = self:PlayerData(ply)

    if idx == data.page then return end

    local fnc_clear = function ()
        for guid, _ in pairs(data.displayed) do
            local obj = getObjectFromGUID(guid)
            if obj then
                destroyObject(obj)
            end
        end
        data.displayed = {}
        data.page = 0
    end

    if idx == 0 then
        Wait.frames(fnc_clear)

    else
        self.grid_locked[ply] = true

        local page_len = #data.grid
        local start = page_len * (idx - 1) + 1
        local stop = start + page_len - 1
        local ordered = data.cards_ordered
        local rotation = self:GetPlyInst(ply).getHandTransform().rotation
        local list = self:GetGridCardList()

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
                obj.addTag(self:PlyTag(ply, 'gridZone'))
                data.displayed[obj.getGUID()] = {pos = pos, r = r}
            end
            data.page = idx
            self.grid_locked[ply] = false
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
        data = data,
    }
    TblAdd(tbl, rest)
    return spawnObjectData(tbl)
end

function GW_GAME:DuplicateCard(card, pos, r)
    return self:DuplicateObj(card:GetData(), pos, r)
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

function onSave()
    if GW_GAME.data.init_done then
        GW_GAME.data.objects = {}
        for k, v in pairs(GW_GAME.objects) do
            if v then
                GW_GAME.data.objects[k] = v.guid
            end
        end
        return JSON.encode(GW_GAME.data)
    end
end

function onLoad(state)
    if #state > 0 then
       GW_GAME.data = JSON.decode(state)
        for k, v in pairs(GW_GAME.data.objects) do
            if not GW_GAME.objects[k] then
                GW_GAME.objects[k] = getObjectFromGUID(v)
            end
        end
    end

    local start_btn = getObjectFromGUID(GUID_START_BUTTON)
    if start_btn and not GW_GAME.data.init_done then
        start_btn.createButton({
            label="Start Game", font_size=200,
            width=1400, height=440, position={0, 0.1, 0},
            click_function="onClickStartGame"
        })
    elseif start_btn then
        destroyObject(start_btn)
    end
end

function onClickStartGame()
    GW_GAME:InitGame()
    local start_btn = getObjectFromGUID(GUID_START_BUTTON)
    if start_btn then
        start_btn.clearButtons()
        start_btn.createButton({
            label="Pick Done", font_size=200,
            width=1400, height=440, position={0, 0.1, 0},
            click_function="onClickPickDone"
        })
    end
end

function onClickPickDone()
    GW_GAME:StartGame()
    local start_btn = getObjectFromGUID(GUID_START_BUTTON)
    if start_btn then
        destroyObject(start_btn)
    end
end

function onBlindfold()
    if not GW_GAME.data.init_done then return end

    local tbl = {}
    for _, p in ipairs(Player.getPlayers()) do
        tbl[p.color] = p.blindfolded
    end
    GW_GAME:PlayerBlindfoldChanged(tbl)
end