-- =========================================================
-- SPACE COLONIZATION ALGORITHM (SCA)
-- Gera árvores orgânicas baseadas em atração por pontos
-- =========================================================

math.randomseed(os.time())
math.random(); math.random(); math.random()

local outputFileName = "../models/sc_tree.obj"

-- ==========================================
-- 1. CONFIGURAÇÕES DA ÁRVORE
-- ==========================================
local config = {
    numPoints = 1000,        -- Quantidade de "luz/folhas" (mais = mais denso)
    crownRadius = 5.0,       -- Tamanho da copa da árvore
    crownHeight = 10.0,      -- Altura onde a copa começa (centro)
    
    trunkHeight = 4.0,       -- Altura do tronco inicial (antes de ramificar)
    
    killDistance = 1.5,      -- Distância para "comer" o ponto (chegou ao destino)
    influenceRadius = 15.0,  -- Distância máxima para ver um ponto
    branchLength = 0.5,      -- Tamanho de cada segmento novo
    
    startRadius = 0.35,      -- Grossura do tronco na base
    minRadius = 0.05         -- Grossura mínima nas pontas
}

-- ==========================================
-- 2. MATEMÁTICA VETORIAL (Igual ao anterior)
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
    print("1. A gerar nuvem de atracao...")
    
    -- A. CRIAR NUVEM DE PONTOS (ATTRACTORS)
    -- Vamos criar uma esfera de pontos no topo
    local attractors = {}
    for i=1, config.numPoints do
        -- Gerar ponto aleatório numa esfera
        local theta = math.random() * 2 * math.pi
        local phi = math.acos(2 * math.random() - 1)
        local r = config.crownRadius * math.pow(math.random(), 1/3) -- Uniforme
        
        local px = r * math.sin(phi) * math.cos(theta)
        local py = r * math.sin(phi) * math.sin(theta) + config.crownHeight
        local pz = r * math.cos(phi)
        
        table.insert(attractors, {pos={x=px, y=py, z=pz}, active=true})
    end

    -- B. CRIAR TRONCO INICIAL (NODES)
    -- Criamos nós empilhados até chegar perto da copa
    local nodes = {}
    local currY = 0
    local root = {pos={x=0, y=0, z=0}, parent=nil, childIndex=-1, thickness=config.startRadius}
    table.insert(nodes, root)
    
    -- Criar segmentos verticais até chegar à altura da copa
    local currentNode = root
    while currY < config.trunkHeight do
        currY = currY + config.branchLength
        local newNode = {
            pos = {x=0, y=currY, z=0},
            parent = #nodes, -- Indice do pai
            dir = {x=0, y=1, z=0}, -- Direção de crescimento
            count = 0 -- Quantos pontos estão a puxar este nó
        }
        table.insert(nodes, newNode)
        currentNode = newNode
    end

    print("2. A crescer ramos (Space Colonization)...")
    
    -- C. LOOP DE CRESCIMENTO
    local growing = true
    local iterations = 0
    
    while growing and iterations < 200 do
        iterations = iterations + 1
        growing = false -- Assumimos que parou, a menos que algo cresça
        
        -- Reset das forças nos nós
        for _, n in ipairs(nodes) do
            n.force = {x=0, y=0, z=0}
            n.count = 0
        end

        -- 1. Associar pontos aos nós mais próximos
        local pointsActive = 0
        
        for _, point in ipairs(attractors) do
            if point.active then
                pointsActive = pointsActive + 1
                local closestNode = nil
                local minDist = 999999.0
                local closestIndex = -1

                -- Procura o nó mais próximo deste ponto
                -- (Isto podia ser otimizado com Octree, mas para <2000 pontos serve)
                for i, node in ipairs(nodes) do
                    local d = vecDist(point.pos, node.pos)
                    if d < minDist and d < config.influenceRadius then
                        minDist = d
                        closestNode = node
                        closestIndex = i
                    end
                end

                if closestNode then
                    -- Se o ponto estiver muito perto, morre (foi comido)
                    if minDist < config.killDistance then
                        point.active = false
                    else
                        -- Senão, o ponto PUXA o nó
                        local dir = vecNorm(vecSub(point.pos, closestNode.pos))
                        closestNode.force = vecAdd(closestNode.force, dir)
                        closestNode.count = closestNode.count + 1
                        growing = true -- Ainda há atividade
                    end
                end
            end
        end

        -- Se não sobrar pontos, paramos
        if pointsActive == 0 then break end

        -- 2. Criar novos ramos baseado nas forças
        local newNodes = {}
        for i, node in ipairs(nodes) do
            if node.count > 0 then
                -- A direção é a média de todas as atrações
                local avgDir = vecNorm(node.force)
                
                -- Adicionar um novo nó nessa direção
                local newPos = vecAdd(node.pos, vecMul(avgDir, config.branchLength))
                
                table.insert(newNodes, {
                    pos = newPos,
                    parent = i, -- O pai é o indice atual
                    thickness = config.minRadius -- Temporário
                })
            end
        end

        -- Adicionar os novos ramos à lista principal
        for _, n in ipairs(newNodes) do
            table.insert(nodes, n)
        end
    end
    
    print("3. Calculando espessuras (Pipe Model)...")
    -- Simulação simples de espessura (Leonardo da Vinci rule invertida)
    -- Vamos atribuir peso baseado na quantidade de filhos (simplificado para profundidade)
    -- Como é complexo fazer backtracking perfeito em Lua simples, vamos fazer um Tapering linear baseado na altura
    for _, node in ipairs(nodes) do
        -- Quanto mais alto (Y), mais fino
        local ratio = 1.0 - (node.pos.y / (config.crownHeight + config.crownRadius))
        if ratio < 0.1 then ratio = 0.1 end
        node.thickness = config.startRadius * ratio
    end

    return nodes
end

-- ==========================================
-- 4. EXPORTAR OBJ (CILINDROS)
-- ==========================================
function writeOBJ(nodes)
    print("4. A exportar geometria 3D... " .. outputFileName)
    local file = io.open(outputFileName, "w")
    if not file then print("ERRO!"); return end

    file:write("# Space Colonization Tree\n")
    
    local globalVertexCount = 0
    local sides = 6 -- Hexagonos

    -- Ignoramos o primeiro nó (root) porque precisamos de pares (Pai -> Filho)
    for i=2, #nodes do
        local node = nodes[i]
        local parent = nodes[node.parent]
        
        local p1 = parent.pos
        local p2 = node.pos
        local r = node.thickness or 0.1
        
        -- Geometria do Cilindro (Igual ao L-System)
        local forward = vecNorm(vecSub(p2, p1))
        local tempUp = {x=0, y=1, z=0}
        if math.abs(forward.y) > 0.9 then tempUp = {x=1, y=0, z=0} end
        local right = vecNorm(vecCross(forward, tempUp))
        local up = vecNorm(vecCross(right, forward))

        local startIndices = {}
        local endIndices = {}

        for k = 0, sides do
            local angle = (k / sides) * math.pi * 2
            local offset = vecAdd(vecMul(right, math.cos(angle)*r), vecMul(up, math.sin(angle)*r))
            
            -- Vertices
            local vBase = vecAdd(p1, offset)
            file:write(string.format("v %.4f %.4f %.4f\n", vBase.x, vBase.y, vBase.z))
            local vTop = vecAdd(p2, offset)
            file:write(string.format("v %.4f %.4f %.4f\n", vTop.x, vTop.y, vTop.z))
            
            -- UVs (Tempo = indice do nó)
            local timeID = i
            file:write(string.format("vt %.1f 0.0\n", timeID))
            file:write(string.format("vt %.1f 0.0\n", timeID))
            
            globalVertexCount = globalVertexCount + 2
            table.insert(startIndices, globalVertexCount - 1)
            table.insert(endIndices, globalVertexCount)
        end
        
        -- Faces
        for k = 1, sides do
            local b1 = startIndices[k]; local b2 = startIndices[k+1]
            local t1 = endIndices[k];   local t2 = endIndices[k+1]
            file:write(string.format("f %d/%d %d/%d %d/%d\n", b1,b1, b2,b2, t1,t1))
            file:write(string.format("f %d/%d %d/%d %d/%d\n", t1,t1, b2,b2, t2,t2))
        end
    end

    file:close()
    print(">> Sucesso! Arvore SC gerada.")
end

-- EXECUTAR
local treeNodes = generateTree()
writeOBJ(treeNodes)