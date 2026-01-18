-- Inicializar a semente de aleatoriedade com o tempo atual
math.randomseed(os.time())
-- "Rodar" o random algumas vezes para aquecer (bug comum em Lua/C)
math.random(); math.random(); math.random()

-- ==========================================
-- 1. BIBLIOTECA DE ÁRVORES (COM VARIAÇÕES)
-- ==========================================
local treeLibrary = {
    -- TIPO 1: Arvore Classica (Variação nos ramos)
    ["1"] = {
        name = "Arvore Classica Variada",
        axiom = "X",
        rules = {
            -- A regra X agora é uma LISTA de opções. O código escolhe uma ao calhas.
            X = {
                "F[+X]F[-X]+X",   -- Opção A: Normal
                "F[-X]F[+X]-X",   -- Opção B: Invertida
                "F[+X]F[-X]",     -- Opção C: Falha um ramo (mais velha)
                "F[-X]F[+X]F+X"   -- Opção D: Ramo extra
            },
            F = "FF"
        },
        angle = 25.0,
        iterations = 5,
        stepSize = 0.5,
        wobble = 10 -- Quanto o angulo treme (graus)
    },

    -- TIPO 2: Arbusto Denso
    ["2"] = {
        name = "Arbusto Selvagem",
        axiom = "F",
        rules = {
            F = {
                "FF+[+F-F-F]-[-F+F+F]", -- Normal
                "FF-[-F+F+F]+[+F-F-F]", -- Espelhado
                "FF+[+F-F]-[-F+F]"      -- Mais magro
            }
        },
        angle = 22.5,
        iterations = 4,
        stepSize = 0.3,
        wobble = 5
    },

    -- TIPO 3: Planta Alta (Bambu/Erva)
    ["3"] = {
        name = "Planta Alta",
        axiom = "X",
        rules = {
            X = {
                "F-[[X]+X]+F[+FX]-X",
                "F+[[X]-X]-F[-FX]+X",
                "F[+X]-X" -- Versão curta
            },
            F = { "FF", "FF", "F" } -- As vezes cresce menos
        },
        angle = 20.0,
        iterations = 5,
        stepSize = 0.4,
        wobble = 2
    }
}

local currentConfig = nil
local outputFileName = "../models/generated_tree.obj"

-- ==========================================
-- 2. GERAR STRING COM ALEATORIEDADE
-- ==========================================
function generateLSystem()
    local currentString = currentConfig.axiom
    
    for i = 1, currentConfig.iterations do
        local nextString = ""
        for j = 1, #currentString do
            local char = string.sub(currentString, j, j)
            local rule = currentConfig.rules[char]
            
            if rule then
                -- SE FOR UMA TABELA (LISTA), ESCOLHE UMA OPÇÃO ALEATÓRIA
                if type(rule) == "table" then
                    local randomIndex = math.random(1, #rule)
                    nextString = nextString .. rule[randomIndex]
                -- SE FOR STRING, USA DIRETO
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
-- 3. EXPORTAR OBJ (Modo Fitas)
-- ==========================================
function writeOBJ(lString)
    print(">> A escrever OBJ: " .. outputFileName)
    local file = io.open(outputFileName, "w")
    if not file then print("ERRO!"); return end

    file:write("# L-System: " .. currentConfig.name .. "\n")

    local baseAngle = currentConfig.angle
    local wobbleMax = currentConfig.wobble or 0
    local step = currentConfig.stepSize
    
    local state = { pos = {x=0, y=0, z=0}, dir = {x=0, y=1, z=0} }
    local stack = {}
    local vertices = {}     
    local lines = {} 

    table.insert(vertices, {x=state.pos.x, y=state.pos.y, z=state.pos.z})
    local currentIndex = 1

    for i = 1, #lString do
        local char = string.sub(lString, i, i)
        
        if char == "F" then
            -- Mover
            state.pos.x = state.pos.x + state.dir.x * step
            state.pos.y = state.pos.y + state.dir.y * step
            state.pos.z = state.pos.z + state.dir.z * step
            
            table.insert(vertices, {x=state.pos.x, y=state.pos.y, z=state.pos.z})
            local newIndex = #vertices
            table.insert(lines, {currentIndex, newIndex})
            currentIndex = newIndex
            
        elseif char == "+" or char == "-" then
            -- ALEATORIEDADE ORGÂNICA NO ÂNGULO
            -- O angulo varia um pouco (ex: entre 20 e 30 graus em vez de fixo 25)
            local randomWobble = (math.random() * wobbleMax * 2) - wobbleMax
            local finalAngle = math.rad(baseAngle + randomWobble)
            
            -- Se for '-', inverte o angulo
            if char == "-" then finalAngle = -finalAngle end

            -- Rodar em Z
            local ox, oy = state.dir.x, state.dir.y
            state.dir.x = ox * math.cos(finalAngle) - oy * math.sin(finalAngle)
            state.dir.y = ox * math.sin(finalAngle) + oy * math.cos(finalAngle)
            
        elseif char == "[" then
            table.insert(stack, {
                pos={x=state.pos.x, y=state.pos.y, z=state.pos.z}, 
                dir={x=state.dir.x, y=state.dir.y, z=state.dir.z},
                index=currentIndex 
            })
        elseif char == "]" then
            if #stack > 0 then
                local saved = table.remove(stack)
                state.pos = saved.pos
                state.dir = saved.dir
                currentIndex = saved.index
            end
        end
    end

    -- Escrever Geometria (Vertices + Triangulos de Fita)
    for _, v in ipairs(vertices) do
        file:write(string.format("v %.4f %.4f %.4f\n", v.x, v.y, v.z))
    end
    
    local vertexCount = #vertices
    local width = 0.05

    for _, l in ipairs(lines) do
        local i1 = l[1]
        local i2 = l[2]
        local v1 = vertices[i1]
        
        file:write(string.format("v %.4f %.4f %.4f\n", v1.x + width, v1.y, v1.z + width))
        vertexCount = vertexCount + 1
        local i3 = vertexCount
        
        file:write(string.format("f %d %d %d\n", i1, i2, i3))
        file:write(string.format("f %d %d %d\n", i3, i2, i1))
    end

    file:close()
    print(">> Sucesso! Gerado modelo único.")
end

-- ==========================================
-- 4. FUNÇÃO PRINCIPAL
-- ==========================================
function runLSystem()
    print("-----------------------------------")
    print("    GERADOR ESTOCASTICO DE ARVORES ")
    print("-----------------------------------")

    local selection = arg[1] or "1"
    
    if treeLibrary[selection] then
        currentConfig = treeLibrary[selection]
        print("Selecionaste: [" .. selection .. "] " .. currentConfig.name)
        print("A gerar uma variacao unica...")
        
        local finalString = generateLSystem()
        writeOBJ(finalString)
    else
        print("Opcao invalida. A usar padrao (1).")
        currentConfig = treeLibrary["1"]
        local finalString = generateLSystem()
        writeOBJ(finalString)
    end
    print("-----------------------------------")
end

runLSystem()