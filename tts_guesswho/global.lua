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

GUIDS_REMOVE_AT_START = {'893b37'}

POS_OPERATING_TABLE = Vector({0.00, -2, 85.77})

CONTROL_TABLE_ELEVATION = 1.0
CONTROL_TABLE_SIZE_KOEF = 500
CONTROL_TABLE_W = 31.5
CONTROL_TABLE_H = 16.8

ENABLE_ZERO_PAGE = false

PLAYER_MAPPING_ID2K = {
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

PLAYER_MAPPING_K2ID = {}
for k, v in pairs(PLAYER_MAPPING_ID2K) do
    PLAYER_MAPPING_K2ID[v] = k
end


function Card(inf, deck, deck_hand)
    if not inf or not inf.name then print('ERROR: Cannot init card: not inf'); return end

    local meta = {}

    if not deck then
        for k, v in pairs(inf) do
            meta[k] = v
        end
    else
        meta.properties = propertiesToTable(inf.description or {})
        meta.name = inf.name
        meta.guid = inf.guid
        meta.guid_hand = inf.guid_hand
    end

    function meta:GetData()
        if not self.data then
            self.data, self.data_hand = self:Operate(function(obj, hand)
                return obj.getData(), hand.getData()
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

function GW_GAME:InitGame(config)
    print(' ==== GW Game Init ==== ')
    self.data.init_done = false
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

    config = config or {}
    TblAdd(config, DEFAULT_CONFIG, true)
    self.data.config = config

    for _, guid in ipairs(GUIDS_REMOVE_AT_START) do
        local obj = getObjectFromGUID(guid)
        if obj then obj.destroyObject() end
    end

    self:InitCards()

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

    local pl_id = PLAYER_MAPPING_K2ID[player]
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
    local cards = self:GetCardList()
    for _, p in ipairs(Player.getPlayers()) do
        local card = cards[math.random(#cards)]
        self:InitPlayer(p.color, card.name)
        self:SetPage(p.color, 1)
        for _, pp in ipairs(Player.getPlayers()) do
            if p.color ~= pp.color then
                local obj = self:DuplicateHandCard(card)
                obj.setName('['..Color.fromString(p.color):toHex(false)..']'..card.name)
                obj.deal(1, pp.color)
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
                obj.addTag(self:PlyTag(name, 'gridZone'))
            end
        })
        self.data.player_zones_objs[i] = obj.guid
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
        local cards = self:GetCardList()
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
                width=size * k, height=size * k, position={x, -0.1, desk_h / 2},
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
                width=size * k, height=size * k, position={x, -0.1, desk_h / 2},
                click_function=fnc_name
            })
        end
        x = x + size + space
    end

    cdesk.createButton({
        label="TIP: You can use custom keys (numpad by default) for selecting pages 1-9",
        font_size=50, rotation={0,180,180},
        width=0, height=0, position={center, -0.1, desk_h / 2 - size},
        click_function="none"
    })
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

    local ply_zone = self:GetPlyZone(ply)
    if ply_zone.hasMatchingTag(obj) then
        return true
    end

    for p, _ in pairs(self.data.players) do
        if p ~= ply then
            local zone = self:GetPlyZone(p)
            if zone.hasMatchingTag(obj) then
                return false
            end
        end
    end

    return 0
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

    data.card_states[obj.getName()] = state
end

function GW_GAME:FixNameCollisions(card_list)
    local names_set = {}
    local count = 0
    for _, card in ipairs(card_list) do
        local val = names_set[card.name]
        if val then
            local old_name = card.name

            if type(val) ~= "number" then
                local new_name = old_name .. ' (1)'
                val.name = new_name

                val:Operate(function (obj, hand)
                    obj.setName(new_name)
                    hand.setName(new_name)
                end)

                val = 1
            end

            val = val + 1

            local new_name = old_name .. ' (' .. val .. ')'
            card.name = new_name
            card:Operate(function (obj, hand)
                obj.setName(new_name)
                hand.setName(new_name)
            end)

            names_set[old_name] = val
            count = count + 1
        else
            names_set[card.name] = card
        end
    end

    if count > 0 then
        print('Fixed ' .. count .. ' name collisions')
    end
end

function GW_GAME:PlayerData(ply)
    return self.data.players[ply]
end

function GW_GAME:InitCardStates()
    local res = {}
    for _, card in ipairs(self:GetCardList()) do
        res[card.name] = false
    end
    return res
end

function GW_GAME:FindCard(name, list)
    for _, card in ipairs(list or self:GetCardList()) do
        if card.name == name then
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

function GW_GAME:InitCards()
    local card_list = self:LoadCards()

    self:FixNameCollisions(card_list)

    for _, card in ipairs(card_list) do
        card:GetData()
    end
    
    self.data.cards_cache = self:GenerateCardsCache(card_list)
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

        if not shuffle then
            self.data.static_order = sorted
        end

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
    local data = self:PlayerData(ply)

    if not data then return end
    if idx == data.page then return end

    if not idx then idx = data.page + 1 end

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
        data = data,
    }
    TblAdd(tbl, rest)
    return spawnObjectData(tbl)
end

function GW_GAME:DuplicateCard(card, pos, r)
    return self:DuplicateObj(select(1, card:GetData()), pos, r)
end

function GW_GAME:DuplicateHandCard(card, pos, r)
    return self:DuplicateObj(select(2, card:GetData()), pos, r)
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

function onScriptingButtonUp(index, color)
    if not GW_GAME.data.init_done then return end
    GW_GAME:SetPage(color, index < 10 and index or nil)
end

function onPlayerAction(player, action, targets)
    if not GW_GAME.data.init_done then return end
    if action == Player.Action.FlipOver
        or action == Player.Action.FlipIncrementalLeft
        or action == Player.Action.FlipIncrementalRight
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
    if not GW_GAME.data.init_done then return end
    if GW_GAME:CanPlayerFlip(player, obj) then
        GW_GAME:OnPlayerFlippedObj(player, obj, false)
    end
end


function none() end