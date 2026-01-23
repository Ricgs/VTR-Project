-- Inicializar semente
math.randomseed(os.time())
math.random(); math.random(); math.random()

-- ==========================================
-- 1. MATEMÁTICA VETORIAL 3D (AVANÇADA)
-- ==========================================
function vecAdd(v1, v2) return {x=v1.x+v2.x, y=v1.y+v2.y, z=v1.z+v2.z} end
function vecSub(v1, v2) return {x=v1.x-v2.x, y=v1.y-v2.y, z=v1.z-v2.z} end
function vecMul(v, s)   return {x=v.x*s, y=v.y*s, z=v.z*s} end
function vecLen(v)      return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z) end
function vecDot(v1, v2) return v1.x*v2.x + v1.y*v2.y + v1.z*v2.z end

function vecNorm(v)
    local len = vecLen(v)
    if len < 0.0001 then return {x=0,y=1,z=0} end -- Proteção contra div por 0
    return {x=v.x/len, y=v.y/len, z=v.z/len}
end

function vecCross(a, b)
    return {
        x = a.y * b.z - a.z * b.y,
        y = a.z * b.x - a.x * b.z,
        z = a.x * b.y - a.y * b.x
    }
end

-- Fórmula de Rodrigues para rodar um vetor (v) à volta de um eixo (k)
function rotateVector(v, k, theta)
    -- v_rot = v * cos(t) + (k x v) * sin(t) + k * (k . v) * (1 - cos(t))
    local cosT = math.cos(theta)
    local sinT = math.sin(theta)
    
    local part1 = vecMul(v, cosT)
    local part2 = vecMul(vecCross(k, v), sinT)
    local dot = vecDot(k, v)
    local part3 = vecMul(k, dot * (1 - cosT))
    
    local res = vecAdd(part1, vecAdd(part2, part3))
    return res
end

-- ==========================================
-- 2. CONFIGURAÇÕES
-- ==========================================
local treeLibrary = {
    ["a"] = {
        name = "Exemplo A",
        axiom = "F",
        rules = {
            F = { "F[+F]F[-F]F" }
        },
        angle = 25.7,
        iterations = 4,
        stepSize = 0.3,
        radius = 0.02,
        wobble = 5
    },
    ["b"] = {
        name = "Exemplo B",
        axiom = "F",
        rules = {
            F = { "F[+F]F[-F][F]" }
        },
        angle = 20,
        iterations = 5,
        stepSize = 0.3,
        radius = 0.02,
        wobble = 5
    },
    ["c"] = {
        name = "Exemplo C",
        axiom = "F",
        rules = {
            F = { "FF-[-F+F+F]+[+F-F-F]" }
        },
        angle = 22.5,
        iterations = 4,
        stepSize = 0.3,
        radius = 0.02,
        wobble = 5
    },
    ["d"] = {
        name = "Exemplo D",
        axiom = "X",
        rules = {
            X = { "F[+X]F[-X]+X" },
            F = "FF"
        },
        angle = 20,
        iterations = 7,
        stepSize = 0.1,
        radius = 0.02,
        wobble = 10
    },
    ["e"] = {
        name = "Exemplo E",
        axiom = "X",
        rules = {
            X = { "F[+X][-X]FX" },
            F = "FF"
        },
        angle = 25.7,
        iterations = 7,
        stepSize = 0.1,
        radius = 0.02,
        wobble = 10
    },
    ["f"] = {
        name = "Exemplo F",
        axiom = "X",
        rules = {
            X = { "F-[[X]+X]+F[+FX]-X" },
            F = "FF"
        },
        angle = 22.5,
        iterations = 5,
        stepSize = 0.3,
        radius = 0.02,
        wobble = 10
    }
}

local currentConfig = nil
local outputFileName = "../models/lsystem_tree.obj"

-- ==========================================
-- 3. GERAR L-SYSTEM
-- ==========================================
function generateLSystem()
    local currentString = currentConfig.axiom
    for i = 1, currentConfig.iterations do
        local nextString = ""
        for j = 1, #currentString do
            local char = string.sub(currentString, j, j)
            local rule = currentConfig.rules[char]
            if rule then
                if type(rule) == "table" then
                    nextString = nextString .. rule[math.random(1, #rule)]
                else
                    nextString = nextString .. rule
                end
            else
                nextString = nextString .. char
            end
        end
        currentString = nextString
    end
    return currentString
end

-- ==========================================
-- 4. EXPORTAR OBJ (3D REAL)
-- ==========================================
function writeOBJ(lString)
    print(">> A gerar Arvore Volumetrica 3D... " .. outputFileName)
    local file = io.open(outputFileName, "w")
    if not file then print("ERRO!"); return end

    file:write("# L-System FULL 3D\n")

    local step = currentConfig.stepSize
    local sides = 6
    
    -- ESTADO DA TARTARUGA 3D
    -- Agora temos Direção (H), Cima (U) e Esquerda (L)
    local state = { 
        pos = {x=0, y=0, z=0}, 
        dir = {x=0, y=1, z=0}, -- Aponta para CIMA
        up  = {x=1, y=0, z=0}, -- Referência lateral
        radius = currentConfig.radius 
    }
    local stack = {}
    local segments = {} 
    local growthIndex = 0

    for i = 1, #lString do
        local char = string.sub(lString, i, i)
        
        if char == "F" then
            local startPos = {x=state.pos.x, y=state.pos.y, z=state.pos.z}
            
            -- Mover na direção atual
            state.pos = vecAdd(state.pos, vecMul(state.dir, step))
            
            local endPos = {x=state.pos.x, y=state.pos.y, z=state.pos.z}
            growthIndex = growthIndex + 1

            table.insert(segments, {
                p1=startPos, p2=endPos, 
                radius=state.radius, id=growthIndex
            })
            -- state.radius = state.radius * 0.95 

        elseif char == "+" or char == "-" then
            -- RODAR (YAW / PITCH MISTO)
            -- A lógica antiga apenas rodava em Z. Agora vamos rodar à volta do vetor 'up'.
            
            local wobble = (math.random() * (currentConfig.wobble or 0) * 2) - (currentConfig.wobble or 0)
            local ang = math.rad(currentConfig.angle + wobble)
            if char == "-" then ang = -ang end

            -- Roda a Direção e o vetor Up
            -- Usamos o produto vetorial (Cross) para achar o eixo de rotação local
            local axis = vecCross(state.dir, state.up) -- Eixo 'Esquerda'
            
            -- Para ser mais interessante, vamos rodar à volta do eixo da ESQUERDA (Pitch)
            -- Isto faz o ramo inclinar-se para a frente/trás
            state.dir = vecNorm(rotateVector(state.dir, axis, ang))
            state.up  = vecNorm(rotateVector(state.up, axis, ang))

        elseif char == "[" then
            -- GUARDAR ESTADO
            table.insert(stack, {
                pos=state.pos, dir=state.dir, up=state.up, radius=state.radius
            })
            
            -- *** O SEGREDO DO 3D ***
            -- Sempre que criamos um novo ramo ([), rodamos a tartaruga aleatoriamente
            -- à volta do PRÓPRIO TRONCO (Roll).
            -- Isto espalha os ramos em todas as direções (360 graus).
            
            local rollAngle = math.rad(math.random(0, 360))
            state.up = vecNorm(rotateVector(state.up, state.dir, rollAngle))
            -- (Nota: Rodar o 'up' à volta do 'dir' não muda a direção do movimento,
            -- mas muda para onde o PRÓXIMO '+' ou '-' vai virar)

        elseif char == "]" then
            if #stack > 0 then
                local saved = table.remove(stack)
                state.pos = saved.pos
                state.dir = saved.dir
                state.up  = saved.up
                state.radius = saved.radius
            end
        end
    end

    -- GERAR MALHA (IGUAL AO ANTERIOR)
    local globalVertexCount = 0
    for _, seg in ipairs(segments) do
        local p1 = seg.p1; local p2 = seg.p2; local r = seg.radius; local id = seg.id
        
        local forward = vecNorm(vecSub(p2, p1))
        local tempUp = {x=0, y=1, z=0}
        if math.abs(forward.y) > 0.9 then tempUp = {x=1, y=0, z=0} end
        local right = vecNorm(vecCross(forward, tempUp))
        local up = vecNorm(vecCross(right, forward))

        local startIndices = {}; local endIndices = {}

        for i = 0, sides do
            local angle = (i / sides) * math.pi * 2
            local cosA = math.cos(angle); local sinA = math.sin(angle)
            local offset = vecAdd(vecMul(right, cosA * r), vecMul(up, sinA * r))
            
            -- Vértices
            local vBase = vecAdd(p1, offset)
            file:write(string.format("v %.4f %.4f %.4f\n", vBase.x, vBase.y, vBase.z))
            local vTop = vecAdd(p2, offset)
            file:write(string.format("v %.4f %.4f %.4f\n", vTop.x, vTop.y, vTop.z))
            
            -- Tempo (vt)
            file:write(string.format("vt %.1f 0.0\n", id)) 
            file:write(string.format("vt %.1f 0.0\n", id))

            globalVertexCount = globalVertexCount + 2
            table.insert(startIndices, globalVertexCount - 1)
            table.insert(endIndices, globalVertexCount)
        end
        
        -- Faces
        for i = 1, sides do
            local b1 = startIndices[i]; local b2 = startIndices[i+1]
            local t1 = endIndices[i];   local t2 = endIndices[i+1]
            file:write(string.format("f %d/%d %d/%d %d/%d\n", b1,b1, b2,b2, t1,t1))
            file:write(string.format("f %d/%d %d/%d %d/%d\n", t1,t1, b2,b2, t2,t2))
        end
    end
    file:close()
    print(">> Sucesso! Arvore 3D gerada.")
end

function runLSystem()
    local selection = arg[1] or "a"
    if treeLibrary[selection] then currentConfig = treeLibrary[selection] else currentConfig = treeLibrary["a"] end
    writeOBJ(generateLSystem())
end

runLSystem()