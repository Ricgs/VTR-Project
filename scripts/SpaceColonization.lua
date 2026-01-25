-- =========================================================
-- SPACE COLONIZATION ALGORITHM (COM VARIAÇÕES)
-- =========================================================

math.randomseed(os.time())
math.random(); math.random(); math.random()

local outputFileName = "../models/sc_tree.obj"

-- ==========================================
-- 1. BIBLIOTECA DE ESPÉCIES
-- ==========================================
local treeLibrary = {
    -- TIPO A: Carvalho (Copa Esférica Clássica)
    ["a"] = {
        name = "Carvalho Redondo",
        shape = "sphere",
        numPoints = 1200,
        crownRadius = 6.0,
        crownHeight = 12.0, -- Centro da esfera
        trunkHeight = 5.0,
        killDistance = 1.5,
        influenceRadius = 15.0,
        branchLength = 0.5,
        startRadius = 0.25,
        minRadius = 0.05
    },

    -- TIPO B: Pinheiro (Forma Cónica)
    ["b"] = {
        name = "Pinheiro Bravo",
        shape = "cone",
        numPoints = 1500,
        crownRadius = 5.0,  -- Raio na base do cone
        crownHeight = 15.0, -- Altura total do cone
        trunkHeight = 3.0,  -- Tronco curto
        killDistance = 1.2,
        influenceRadius = 20.0, -- Vê longe para crescer a direito
        branchLength = 0.5,
        startRadius = 0.25,
        minRadius = 0.02
    },

    -- TIPO C: Cipreste (Cilindro Alto e Fino)
    ["c"] = {
        name = "Cipreste Fino",
        shape = "cylinder",
        numPoints = 1000,
        crownRadius = 1.5,  -- Muito estreito
        crownHeight = 14.0, -- Altura do cilindro
        trunkHeight = 1.0,
        killDistance = 1.0,
        influenceRadius = 10.0,
        branchLength = 0.4,
        startRadius = 0.15,
        minRadius = 0.05
    },

    -- TIPO D: Arbusto Espalhado (Meia Esfera Baixa)
    ["d"] = {
        name = "Arbusto Largo",
        shape = "hemisphere",
        numPoints = 1500,
        crownRadius = 8.0,
        crownHeight = 0.0, -- No chão
        trunkHeight = 0.5,
        killDistance = 1.0,
        influenceRadius = 20.0,
        branchLength = 0.4,
        startRadius = 0.15,
        minRadius = 0.02
    }
}

local config = nil -- Será preenchido pela escolha

-- ==========================================
-- 2. MATEMÁTICA VETORIAL
-- ==========================================
function vecAdd(v1, v2) return {x=v1.x+v2.x, y=v1.y+v2.y, z=v1.z+v2.z} end
function vecSub(v1, v2) return {x=v1.x-v2.x, y=v1.y-v2.y, z=v1.z-v2.z} end
function vecMul(v, s)   return {x=v.x*s, y=v.y*s, z=v.z*s} end
function vecLen(v)      return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z) end
function vecDist(v1, v2) return vecLen(vecSub(v1, v2)) end
function vecNorm(v)
    local len = vecLen(v)
    if len < 0.0001 then return {x=0,y=1,z=0} end
    return {x=v.x/len, y=v.y/len, z=v.z/len}
end
function vecCross(a, b)
    return { x = a.y*b.z - a.z*b.y, y = a.z*b.x - a.x*b.z, z = a.x*b.y - a.y*b.x }
end

-- ==========================================
-- 3. ALGORITMO DE CRESCIMENTO
-- ==========================================
function generateTree()
    print("1. A gerar nuvem para: " .. config.name .. " (" .. config.shape .. ")")
    
    -- A. CRIAR NUVEM DE PONTOS (Baseado na forma)
    local attractors = {}
    
    for i=1, config.numPoints do
        local px, py, pz
        
        if config.shape == "sphere" then
            -- Esfera no topo
            local theta = math.random() * 2 * math.pi
            local phi = math.acos(2 * math.random() - 1)
            local r = config.crownRadius * (math.random() ^ (1/3))
            px = r * math.sin(phi) * math.cos(theta)
            py = r * math.sin(phi) * math.sin(theta) + config.crownHeight
            pz = r * math.cos(phi)
            
        elseif config.shape == "cone" then
            -- Cone (Pinheiro)
            local h = math.random() * config.crownHeight -- Altura aleatória dentro do cone
            local maxR_at_H = config.crownRadius * (1 - (h / config.crownHeight)) -- Raio diminui ao subir
            local theta = math.random() * 2 * math.pi
            local r = math.sqrt(math.random()) * maxR_at_H
            
            px = r * math.cos(theta)
            py = h + config.trunkHeight -- Começa acima do tronco
            pz = r * math.sin(theta)
            
        elseif config.shape == "cylinder" then
            -- Cilindro (Cipreste)
            local h = math.random() * config.crownHeight
            local theta = math.random() * 2 * math.pi
            local r = math.sqrt(math.random()) * config.crownRadius
            
            px = r * math.cos(theta)
            py = h + config.trunkHeight
            pz = r * math.sin(theta)

        elseif config.shape == "hemisphere" then
            -- Meia esfera (Arbusto)
            local theta = math.random() * 2 * math.pi
            local phi = math.acos(math.random()) -- Apenas metade superior (0 a PI/2)
            local r = config.crownRadius * (math.random() ^ (1/3))
            
            px = r * math.sin(phi) * math.cos(theta)
            pz = r * math.sin(phi) * math.sin(theta) 
            py = r * math.cos(phi) + config.trunkHeight
        end
        
        table.insert(attractors, {pos={x=px, y=py, z=pz}, active=true})
    end

    -- B. CRIAR TRONCO INICIAL
    local nodes = {}
    local currY = 0
    local root = {pos={x=0, y=0, z=0}, parent=nil, childIndex=-1, thickness=config.startRadius}
    table.insert(nodes, root)
    
    -- Se o tronco for muito pequeno, garante pelo menos 1 segmento
    if config.trunkHeight < config.branchLength then config.trunkHeight = config.branchLength end

    while currY < config.trunkHeight do
        currY = currY + config.branchLength
        local newNode = {
            pos = {x=0, y=currY, z=0},
            parent = #nodes,
            dir = {x=0, y=1, z=0},
            count = 0
        }
        table.insert(nodes, newNode)
    end

    print("2. A colonizar espaco...")
    
    -- C. LOOP DE CRESCIMENTO
    local growing = true
    local iterations = 0
    
    while growing and iterations < 300 do
        iterations = iterations + 1
        growing = false 
        
        -- Reset
        for _, n in ipairs(nodes) do n.force = {x=0,y=0,z=0}; n.count = 0 end

        -- 1. Associar pontos
        local pointsActive = 0
        for _, point in ipairs(attractors) do
            if point.active then
                pointsActive = pointsActive + 1
                local closestNode = nil
                local minDist = 999999.0
                local closestIndex = -1

                for i, node in ipairs(nodes) do
                    local d = vecDist(point.pos, node.pos)
                    if d < minDist and d < config.influenceRadius then
                        minDist = d; closestNode = node; closestIndex = i
                    end
                end

                if closestNode then
                    if minDist < config.killDistance then
                        point.active = false -- Comeu o ponto
                    else
                        local dir = vecNorm(vecSub(point.pos, closestNode.pos))
                        closestNode.force = vecAdd(closestNode.force, dir)
                        closestNode.count = closestNode.count + 1
                        growing = true
                    end
                end
            end
        end

        if pointsActive == 0 then break end

        -- 2. Criar novos ramos
        local newNodes = {}
        for i, node in ipairs(nodes) do
            if node.count > 0 then
                local avgDir = vecNorm(node.force)
                -- Pequeno jitter para não ficar linhas retas perfeitas
                avgDir.x = avgDir.x + (math.random()-0.5)*0.1
                avgDir.z = avgDir.z + (math.random()-0.5)*0.1
                avgDir = vecNorm(avgDir)

                local newPos = vecAdd(node.pos, vecMul(avgDir, config.branchLength))
                table.insert(newNodes, { pos = newPos, parent = i, thickness = config.minRadius })
            end
        end

        for _, n in ipairs(newNodes) do table.insert(nodes, n) end
    end
    
    print("3. Calculando espessuras...")
    -- Tapering simples baseado na altura relativa
    local maxHeight = 0
    for _, n in ipairs(nodes) do if n.pos.y > maxHeight then maxHeight = n.pos.y end end
    
    for _, node in ipairs(nodes) do
        local ratio = 1.0 - (node.pos.y / (maxHeight + 1))
        if ratio < 0.1 then ratio = 0.1 end
        node.thickness = config.startRadius * ratio
    end

    return nodes
end

-- ==========================================
-- 4. EXPORTAR OBJ
-- ==========================================
function writeOBJ(nodes)
    print("4. A exportar OBJ... " .. outputFileName)
    local file = io.open(outputFileName, "w")
    if not file then print("ERRO!"); return end

    file:write("# Space Colonization: " .. config.name .. "\n")
    local sides = 6
    local globalVertexCount = 0

    for i=2, #nodes do
        local node = nodes[i]
        local parent = nodes[node.parent]
        local p1 = parent.pos; local p2 = node.pos; local r = node.thickness
        
        local forward = vecNorm(vecSub(p2, p1))
        local tempUp = {x=0, y=1, z=0}
        if math.abs(forward.y) > 0.9 then tempUp = {x=1, y=0, z=0} end
        local right = vecNorm(vecCross(forward, tempUp))
        local up = vecNorm(vecCross(right, forward))

        local startIndices = {}; local endIndices = {}

        for k = 0, sides do
            local angle = (k / sides) * math.pi * 2
            local offset = vecAdd(vecMul(right, math.cos(angle)*r), vecMul(up, math.sin(angle)*r))
            
            local vBase = vecAdd(p1, offset)
            file:write(string.format("v %.4f %.4f %.4f\n", vBase.x, vBase.y, vBase.z))
            local vTop = vecAdd(p2, offset)
            file:write(string.format("v %.4f %.4f %.4f\n", vTop.x, vTop.y, vTop.z))
            
            -- UVs para animação (ID do nó)
            local id = i
            file:write(string.format("vt %.1f 0.0\n", id))
            file:write(string.format("vt %.1f 0.0\n", id))
            
            globalVertexCount = globalVertexCount + 2
            table.insert(startIndices, globalVertexCount - 1)
            table.insert(endIndices, globalVertexCount)
        end
        
        for k = 1, sides do
            local b1 = startIndices[k]; local b2 = startIndices[k+1]
            local t1 = endIndices[k];   local t2 = endIndices[k+1]
            file:write(string.format("f %d/%d %d/%d %d/%d\n", b1,b1, b2,b2, t1,t1))
            file:write(string.format("f %d/%d %d/%d %d/%d\n", t1,t1, b2,b2, t2,t2))
        end
    end
    file:close()
    print(">> Sucesso!")
end

-- ==========================================
-- 5. RUN
-- ==========================================
local selection = arg[1] or "a"

if treeLibrary[selection] then
    config = treeLibrary[selection]
else
    print("Opcao invalida. A usar padrao [a].")
    config = treeLibrary["a"]
end

local treeNodes = generateTree()
writeOBJ(treeNodes)