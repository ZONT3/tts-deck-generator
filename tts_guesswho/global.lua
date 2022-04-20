GAME_ZONE_TL = Vector(-35.60, 1.60, 71.70)
GAME_ZONE_BR = Vector(35.60, 1.60, -71.7)
GAME_ZONE_W = 2
GAME_ZONE_H = 5

GUID_GRID_DECK_ZONE = ''
GUID_HAND_DECK_ZONE = ''
GUID_START_BUTTON = '35e1ac'

PLAYER_ZONES_MAPPING_ID2K = {
    'White', 'Brown', 'Red', 
    'Orange', 'Yellow', 'Green', 
    'Teal', 'Blue', 'Purple', 'Pink'
}

DEFAULT_CONFIG = {
    shuffle_players_grid = false,
}

function Vec2f(x, y)
    if type(x) == "userdata" then
        return Vector(x.x, 0, x.z)
    end
    return Vector(x, 0, y)
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

function Card(guid)
    local ref = getObjectFromGUID(guid)
    if not ref then return end

    local meta = {}

    meta.properties = propertiesToTable(ref.getDescription())
    meta.name = ref.getName()
    meta.ref_guid = guid
    meta.ref = ref

    function meta:IsEqual(another)
        return self.name == another.name
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

    if not config then config = {} end
    for k, v in pairs(DEFAULT_CONFIG) do
        if not config[k] then
            config[k] = v
        end
    end
    self.data.config = config

    self:FixNameCollisions()

    PLAYER_ZONES_MAPPING_K2ID = {}
    for k, v in pairs(PLAYER_ZONES_MAPPING_ID2K) do
        PLAYER_ZONES_MAPPING_K2ID[v] = k
    end

    self.data.player_zones = self:GenerateGridZones(GAME_ZONE_TL, GAME_ZONE_BR, GAME_ZONE_W, GAME_ZONE_H)
    self.data.game_height = math.max(GAME_ZONE_TL.y, GAME_ZONE_BR.y)
    self:InitZones()

    self.data.init_done = true
end

function GW_GAME:InitPlayer(player)
    local data = {}

    data.card_states = self:InitCardStates()
    data.cards_ordered = self:GetCardNamesOrdered(data.card_states)
    data.displayed = {}
    data.page = {}
    data.grid = self:GenerateGridPoints(self.data.player_zones[PLAYER_ZONES_MAPPING_ID2K[player]])

    self.data.players[player] = data
end

function GW_GAME:StartGame()
    self.data.stage = STAGE_PLAY
    for p, d in pairs(self.data.players) do
        if d.card_name then
            self:SetPage(p, 1)
        end
    end
end

function GW_GAME:InitDecks()
    for name, guid in pairs({ ['grid'] = GUID_GRID_DECK_ZONE, ['hand'] = GUID_HAND_DECK_ZONE }) do
        local field = name .. '_deck'
        if not self[field] then
            local deck
            for _, obj in ipairs(getObjectFromGUID(guid).getObjects()) do
                if obj.name == 'Deck' or obj.name == 'CustomDeck' then
                    deck = obj
                    break
                end
            end
            if not deck then
                print('ERROR: '..name..' deck not found!')
                return
            else
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

function GW_GAME:PlyTag(ply, tag)
    return (tag or 'tag')..':'..ply
end

function GW_GAME:FixNameCollisions()
    local names_set = {}
    local count = 0
    for _, card in ipairs(self:GetCardList()) do
        local val = names_set[card.name]
        if val then
            if type(val) == "string" then
                getObjectFromGUID(val).setName(card.name .. ' [1]')
                val = 1
            end

            val = val + 1
            card.ref.setName(card.name .. ' [' .. val .. ']')
            names_set[card.name] = val

            count = count + 1
        else
            names_set[card.name] = card.ref_guid
        end
    end

    if count > 0 then
        print('Fixed ' .. count .. ' name collisions')
    end
end

function GW_GAME:PlayerBlindfoldChanged(states)
    if self.data.stage ~= STAGE_PICKING then return end
    if not self.data.init_done then return end

    if self.data.picking_player and not states[self.data.picking_player] then
        -- TODO hide picking ui
        self.data.picking_player = nil
    end

    if self.data.picking_player then
        return
    else
        for ply, bool in pairs(states) do
            if bool then
                self.data.picking_player = ply
                break
            end
        end
    end

    -- TODO show picking ui
    local cards = self:GetCardList()
    self:PlayerData(self.data.picking_player).card_name = cards[math.random(#cards)]
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

function GW_GAME:FindCard(name, list)
    for _, card in ipairs(list or self:GetCardList()) do
        if card.name == name then
            return card
        end
    end
end

function GW_GAME:GetCardList()
    self:InitDecks()
    local res = {}
    for _, obj in ipairs(self.grid_deck) do
        table.insert(Card(obj.getObjects().guid))
    end
    return res
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

    if idx == 0 then
        for guid, _ in pairs(data.displayed) do
            local obj = getObjectFromGUID(guid)
            if obj then
                destroyObject(obj)
            end
        end
        data.displayed = {}

    else
        local page_len = #data.grid
        local start = page_len * (idx - 1) + 1
        local stop = start + page_len - 1
        local ordered = data.cards_ordered
        local rotation = self:GetPlyInst(ply).getHandTransform().rotation
        local list = self:GetCardList()
        data.displayed = {}

        rotation.y = (rotation.y + 180) % 360

        self:SetPage(ply, 0)

        for i = start, stop do
            if #ordered < i then
                break
            end

            local pos = self:Vec2fTo3f(data.grid[i])
            local card_name = ordered[i]
            local card = self:FindCard(card_name, list)
            local flipped = data.card_states[card_name]
            local r = Vector(rotation.x, rotation.y, flipped and 180 or 0)

            local obj_data = card.ref.getData()
            obj_data.GUID = nil

            local obj = spawnObjectData({
                position = pos,
                rotation = r,
                data = obj_data,
            })
            obj.addTag(self:PlyTag(ply, 'gridZone'))
            data.displayed[obj.guid] = {pos=pos, r=r}
        end
    end

    data.page = idx
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

function GW_GAME:GenerateGridZones(p_tl, p_br, w, h)
    local left = p_tl.x
    local top = p_tl.z
    local right = p_br.x
    local bot = p_br.z

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

    local cell_w = (right - left) / w
    local cell_h = (top - bot) / h

    local res = {}
    local d = 1
    for i = 1, w do
        for j = d > 0 and 1 or h, d > 0 and h or 1, d do
            res[#res + 1] = {
                tl = Vec2f(left + cell_w * (i - 1), bot + cell_h * j),
                br = Vec2f(left + cell_w * i, bot + cell_h * (j - 1))
            }
        end
        d = -d
    end
    return res
end

function GW_GAME:GenerateGridPoints(p_tl, p_br, w, h)
    local res = {}
    for _, p in ipairs(self:GenerateGridZones(p_tl, p_br, w, h)) do
        local left = p.tl.x < p.rb.x and p.tl.x or p.rb.x
        local right = p.tl.x < p.rb.x and p.rb.x or p.tl.x
        local top = p.tl.z < p.rb.z and p.tl.z or p.rb.z
        local bot = p.tl.z < p.rb.z and p.rb.z or p.tl.z
        res[#res + 1] = {
            Vec2f(left + (right - left) / 2, top + (top - bot) / 2)
        }
    end
    return res
end

function onSave()
    if GW_GAME.data.init_done then
        return JSON.encode(GW_GAME.data)
    end
end

function onLoad(state)
    if #state > 0 then
       GW_GAME.data = JSON.decode(state)
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
        destroyObject(start_btn)
    end
end
