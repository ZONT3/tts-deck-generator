GAME_ZONE_TL = Vector(-20, 5, -20)
GAME_ZONE_BR = Vector(20, 5, 20)
GAME_ZONE_W = 2
GAME_ZONE_H = 5

PLAYER_ZONES_MAPPING = {
    ['White'] = 1, ['Brown'] = 2, ['Red'] = 3, 
    ['Orange'] = 4, ['Yellow'] = 5, ['Green'] = 6, 
    ['Teal'] = 7, ['Blue'] = 8, ['Purple'] = 9, ['Pink'] = 10
}

function Vec2f(x, y)
    if type(x) == "userdata" then
        return Vector(x.x, 0, x.z)
    end
    return Vector(x, 0, y)
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

function GW_GAME:InitGame()
    print(' ==== GW Game Init ==== ')
    self.data.stage = STAGE_PICKING
    self.data.players = {}

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

    self.data.player_zones = self:GenerateGridZones(GAME_ZONE_TL, GAME_ZONE_BR, GAME_ZONE_W, GAME_ZONE_H)
    self.data.game_height = math.max(GAME_ZONE_TL.y, GAME_ZONE_BR.y)

    if count > 0 then
        print('Fixed ' .. count .. ' name collisions')
    end
end

function GW_GAME:InitPlayer(player, card_name)
    local data = {}

    data.card_name = card_name
    data.card_states = self:InitCardStates()
    data.cards_ordered = self:GetCardNamesOrdered(data.card_states)
    data.displayed = {}
    data.page = {}
    data.grid = self:GenerateGridPoints(self.data.player_zones[PLAYER_ZONES_MAPPING[player]])

    self.data.players[player] = data
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
    -- TODO
end

function GW_GAME:FindCard(name)
    for _, card in ipairs(self:GetCardList()) do
        if card.name == name then
            return card
        end
    end
end

function GW_GAME:GetCardList()
    -- TODO
end

function GW_GAME:StartGame()
    self.data.stage = STAGE_PLAY
    for p, _ in pairs(self.data.players) do
        self:SetPage(p, 1)
    end
end

function GW_GAME:SetPage(ply, idx)
    local data = self:PlayerData(ply)
    if idx == 0 then
        for _, guid in data.displayed do
            local obj = getObjectFromGUID(guid)
            if obj then
                destroyObject(obj)
            end
        end

    else
        local page_len = #data.grid
        local start = page_len * (idx - 1) + 1
        local stop = start + page_len - 1
        local ordered = data.cards_ordered

        self:SetPage(ply, 0)
        
        for i = start, stop do
            if #ordered < i then
                break
            end

            local pos = data.grid[i]
            local card_name = ordered[i]
            local card = self:FindCard(card_name)
            local flipped = data.card_states[card_name]
            
            -- TODO
        end
    end
    data.page = idx
end

function GW_GAME:GenerateGridZones(p_tl, p_br, w, h)
    local left = p_tl.x
    local top = p_tl.z
    local right = p_br.x
    local bot = p_br.z

    -- fix wrong orientation
    if left > right then
        local b = left
        left = right
        right = b
    end
    if top > bot then
        local b = top
        top = bot
        bot = b
    end

    w = w or 2
    h = h or 5

    local cell_w = (right - left) / w
    local cell_h = (bot - top) / h

    local res = {}
    for i = 1, w do
        for j = 1, h do
            res[#res + 1] = {
                tl = Vec2f(left + cell_w * (i - 1), top + cell_h * (j - 1)),
                br = Vec2f(left + cell_w * i, top + cell_h * j)
            }
        end
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
            Vec2f(left + (left - right) / 2, top + (bot - top) / 2)
        }
    end
    return res
end

function onSave()
    return JSON.encode(GW_GAME.data)
end

function onLoad(state)
    GW_GAME.data = JSON.decode(state)
    return state
end
