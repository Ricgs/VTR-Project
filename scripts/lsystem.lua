-- ==========================================
-- 1. CONFIGURAÇÕES (BIBLIOTECA DE ÁRVORES)
-- ==========================================
local treeLibrary = {
    -- TIPO 1: A Árvore Básica (que já tinhas)
    ["1"] = {
        name = "Arvore Classica",
        axiom = "X",
        rules = {
            X = "F[+X]F[-X]+X",
            F = "FF"
        },
        angle = 25.0,
        iterations = 5,
        stepSize = 0.5
    },

    -- TIPO 2: Arbusto Denso
    ["2"] = {
        name = "Arbusto Denso",
        axiom = "F",
        rules = {
            F = "FF+[+F-F-F]-[-F+F+F]"
        },
        angle = 22.5,
        iterations = 4,
        stepSize = 0.3
    },

    -- TIPO 3: Planta Alta e Fina
    ["3"] = {
        name = "Planta Alta",
        axiom = "X",
        rules = {
            X = "F-[[X]+X]+F[+FX]-X",
            F = "FF"
        },
        angle = 20.0,
        iterations = 5,
        stepSize = 0.4
    },
    
    -- TIPO 4: Erva Daninha (Simétrica)
    ["4"] = {
        name = "Erva Daninha",
        axiom = "X",
        rules = {
            X = "F[+X][-X]FX",
            F = "FF"
        },
        angle = 25.7,
        iterations = 5,
        stepSize = 0.3
    }
}

-- Variáveis globais que serão preenchidas pela escolha
local currentConfig = nil
local outputFileName = "../models/generated_tree.obj"

-- ==========================================
-- 2. LÓGICA DO L-SYSTEM
-- ==========================================
function generateLSystem()
    local currentString = currentConfig.axiom
    for i = 1, currentConfig.iterations do
        local nextString = ""
        for j = 1, #currentString do
            local char = string.sub(currentString, j, j)
            -- Se houver regra substitui, senão mantém
            if currentConfig.rules[char] then 
                nextString = nextString .. currentConfig.rules[char]
            else 
                nextString = nextString .. char 
            end
        end
        currentString = nextString
    end
    return currentString
end

-- ==========================================
-- 3. EXPORTAR OBJ (Modo Fitas/Ribbons)
-- ==========================================
function writeOBJ(lString)
    print(">> A escrever OBJ: " .. outputFileName)
    local file = io.open(outputFileName, "w")
    if not file then print("ERRO ao criar ficheiro!"); return end

    file:write("# L-System: " .. currentConfig.name .. "\n")

    local angleRad = math.rad(currentConfig.angle)
    local step = currentConfig.stepSize
    
    local state = { pos = {x=0, y=0, z=0}, dir = {x=0, y=1, z=0} }
    local stack = {}
    local vertices = {}     
    local lines = {} 

    -- Vértice inicial
    table.insert(vertices, {x=state.pos.x, y=state.pos.y, z=state.pos.z})
    local currentIndex = 1

    -- Processar a String
    for i = 1, #lString do
        local char = string.sub(lString, i, i)
        
        if char == "F" then
            -- Mover
            state.pos.x = state.pos.x + state.dir.x * step
            state.pos.y = state.pos.y + state.dir.y * step
            state.pos.z = state.pos.z + state.dir.z * step
            
            -- Guardar
            table.insert(vertices, {x=state.pos.x, y=state.pos.y, z=state.pos.z})
            local newIndex = #vertices
            table.insert(lines, {currentIndex, newIndex})
            currentIndex = newIndex
            
        elseif char == "+" then -- Rodar Esquerda (Z)
            local ox, oy = state.dir.x, state.dir.y
            state.dir.x = ox * math.cos(angleRad) - oy * math.sin(angleRad)
            state.dir.y = ox * math.sin(angleRad) + oy * math.cos(angleRad)
            
        elseif char == "-" then -- Rodar Direita (Z)
            local ox, oy = state.dir.x, state.dir.y
            local na = -angleRad
            state.dir.x = ox * math.cos(na) - oy * math.sin(na)
            state.dir.y = ox * math.sin(na) + oy * math.cos(na)
            
        elseif char == "[" then -- Push
            table.insert(stack, {
                pos={x=state.pos.x, y=state.pos.y, z=state.pos.z}, 
                dir={x=state.dir.x, y=state.dir.y, z=state.dir.z},
                index=currentIndex 
            })
        elseif char == "]" then -- Pop
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
    local width = 0.15 -- Espessura da fita

    for _, l in ipairs(lines) do
        local i1 = l[1]
        local i2 = l[2]
        local v1 = vertices[i1]
        
        -- Criar vértice deslocado para dar espessura
        file:write(string.format("v %.4f %.4f %.4f\n", v1.x + width, v1.y, v1.z + width))
        vertexCount = vertexCount + 1
        local i3 = vertexCount
        
        -- Triângulo frente e verso
        file:write(string.format("f %d %d %d\n", i1, i2, i3))
        file:write(string.format("f %d %d %d\n", i3, i2, i1))
    end

    file:close()
    print(">> Sucesso! Gerado modelo: " .. currentConfig.name)
end

-- ==========================================
-- 4. FUNÇÃO PRINCIPAL (COM ARGUMENTOS)
-- ==========================================
function runLSystem()
    print("-----------------------------------")
    print("       GERADOR DE ARVORES LUA      ")
    print("-----------------------------------")

    -- Ler o argumento da linha de comandos (ou assumir "1" por defeito)
    local selection = arg[1] or "1"
    
    -- Validar seleção
    if treeLibrary[selection] then
        currentConfig = treeLibrary[selection]
        print("Selecionaste: [" .. selection .. "] " .. currentConfig.name)
        
        local finalString = generateLSystem()
        writeOBJ(finalString)
    else
        print("ERRO: Tipo '" .. selection .. "' desconhecido.")
        print("Opcoes disponiveis:")
        for k, v in pairs(treeLibrary) do
            print("  " .. k .. ": " .. v.name)
        end
    end
    print("-----------------------------------")
end

-- Executar
runLSystem()