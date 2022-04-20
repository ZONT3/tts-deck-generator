function Vec2f(x, y)
    if type(x) == "userdata" then
        return Vector(x.x, 0, x.z)
    end
    return Vector(x, 0, y)
end

GW_GAME = {}

GW_GAME.data = {}

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
