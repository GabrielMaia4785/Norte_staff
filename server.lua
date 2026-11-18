-- norte_staff: comandos de staff.
-- Todos usam Whip.command com dev = true: só a consola e contas com whip.devtools
-- e o modo de desenvolvedor ligado (/w) os conseguem usar. O WHIP recusa o resto.

local carros = {}       -- [source] = vehicleId do carro de /car (sessão só, limpo ao sair)
local posAnterior = {}  -- [source] = vector4 antes do último teleporte, para /voltar
local congelados = {}   -- [source] = true enquanto congelado por /freeze

local function responder(src, texto, tipo)
    if src == 0 then
        print(('[norte_staff] %s'):format(texto))
    else
        exports.whip_core:NotifyPlayer(src, texto, tipo or 'info')
    end
end

local function registar(src, comando, detalhe)
    local nome = src == 0 and 'consola' or (GetPlayerName(src) or '?')
    print(('[norte_staff] %s (%d) /%s %s'):format(nome, src, comando, detalhe or ''))
end

-- Lê o id de um jogador online. Sem argumento devolve o próprio (nunca a consola).
local function alvo(src, arg, permiteProprio)
    if not arg then
        if permiteProprio and src ~= 0 then return src end
        return false, 'Indica o id do jogador'
    end
    local id = tonumber(arg)
    if not id or id < 1 or id % 1 ~= 0 then return false, 'Id inválido' end
    if not GetPlayerName(id) then return false, ('Jogador %d não está online'):format(id) end
    return id
end

local function soJogador(src)
    if src == 0 then
        print('[norte_staff] Este comando só funciona dentro do jogo')
        return false
    end
    return true
end

local function guardarPosicao(src)
    local c = exports.whip_core:GetPlayerCoords(src)
    if c then posAnterior[src] = c end
end

local function teleportar(src, x, y, z, h)
    guardarPosicao(src)
    TriggerClientEvent('norte_staff:teleport', src, x, y, z, h)
end

local function removerCarro(src)
    local id = carros[src]
    if not id then return end
    carros[src] = nil
    exports.whip_core:DespawnVehicle(id)
end

-- ============================================
-- Ferramentas próprias (no cliente)
-- ============================================

for _, nome in ipairs({ 'noclip', 'invis' }) do
    Whip.command(nome, { dev = true, whileDead = nome ~= 'noclip' }, function(src)
        if not soJogador(src) then return end
        registar(src, nome)
        TriggerClientEvent('norte_staff:toggle', src, nome)
    end)
end

-- God: o cliente trata da invencibilidade e da vida. O servidor mantém colete, fome e sede no máximo,
-- porque só o servidor muda stats. Sai sozinho quando o modo de desenvolvedor desliga.
local god = {}            -- [source] = true enquanto o /god está ligado
local GOD_STATS = { armour = 100, hunger = 100, thirst = 100 }
local godLoop = false

local function encherStats(src)
    for stat, max in pairs(GOD_STATS) do
        local atual = exports.whip_core:GetStat(src, stat)
        if atual and atual < max then
            exports.whip_core:SetStat(src, stat, max, 'norte_staff:god')
        end
    end
end

local function iniciarGodLoop()
    if godLoop then return end
    godLoop = true
    CreateThread(function()
        while next(god) do
            for src in pairs(god) do
                if not GetPlayerName(src) or not exports.whip_core:HasDevTools(src) then
                    god[src] = nil
                else
                    encherStats(src)
                end
            end
            Wait(Config.GodIntervalo)
        end
        godLoop = false
    end)
end

Whip.command('god', { dev = true, whileDead = true }, function(src)
    if not soJogador(src) then return end
    local estado = not god[src]
    god[src] = estado or nil
    registar(src, 'god', tostring(estado))
    TriggerClientEvent('norte_staff:toggle', src, 'god', estado)
    if estado then
        encherStats(src)
        iniciarGodLoop()
    end
end)

-- ============================================
-- Veículos
-- ============================================

Whip.command('car', { dev = true }, function(src, args)
    if not soJogador(src) then return end

    local modelo = args[1] and args[1]:lower()
    if not modelo or #modelo > 32 or not modelo:match('^[%w_]+$') then
        return responder(src, 'Uso: /car <modelo>', 'error')
    end

    local player = exports.whip_core:GetPlayer(src)
    if not player then return responder(src, 'Carrega uma personagem primeiro', 'error') end

    local c = exports.whip_core:GetPlayerCoords(src)
    if not c then return responder(src, 'Posição desconhecida', 'error') end

    removerCarro(src)

    local id, err = exports.whip_core:SpawnTempVehicle(modelo, c, {
        forSource = src,
        locked = false,
        keyInIgnition = true,
        despawnAfter = Config.CarroDuracao,
    })
    if not id then return responder(src, err or 'Não foi possível criar o carro', 'error') end

    -- SpawnTempVehicle espera: o jogador pode ter saído ou trocado de personagem.
    if not exports.whip_core:IsSessionCurrent(src, player.session) then
        exports.whip_core:DespawnVehicle(id)
        return
    end

    carros[src] = id
    registar(src, 'car', modelo)

    -- O carro pode demorar alguns frames a ganhar netId depois de SpawnTempVehicle.
    local netId
    for _ = 1, 30 do
        local v = exports.whip_core:GetVehicle({ id = id })
        if not v then break end
        if v.netId then netId = v.netId break end
        Wait(100)
    end
    if netId and GetPlayerName(src) then
        TriggerClientEvent('norte_staff:entrarCarro', src, netId)
    end
    responder(src, ('Carro %s criado'):format(modelo), 'success')
end)

local function carroAlvo(src)
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end

    local pos = GetEntityCoords(ped)
    local melhor, dist = 0, Config.RaioDv
    for _, v in ipairs(GetAllVehicles()) do
        local d = #(GetEntityCoords(v) - pos)
        if d < dist then melhor, dist = v, d end
    end
    return melhor
end

Whip.command('dv', { dev = true }, function(src)
    if not soJogador(src) then return end

    local veh = carroAlvo(src)
    if veh == 0 then return responder(src, 'Nenhum carro perto', 'error') end

    -- Um carro com dono volta para a garagem. Um carro de rua ou temporário sai do mundo.
    exports.whip_core:DespawnVehicle({ entity = veh })
    if DoesEntityExist(veh) then DeleteEntity(veh) end

    for dono, id in pairs(carros) do
        local v = exports.whip_core:GetVehicle({ id = id })
        if not v or not v.spawned then carros[dono] = nil end
    end

    registar(src, 'dv')
    responder(src, 'Carro removido', 'success')
end)

Whip.command('fix', { dev = true }, function(src)
    if not soJogador(src) then return end

    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if veh == 0 then return responder(src, 'Entra num carro primeiro', 'error') end

    -- Carros que o WHIP não conhece (rua) recusam: só o reparo no jogo importa para eles.
    exports.whip_core:ClearVehicleDamage({ entity = veh })

    -- Como o Repair Vehicle do /w: o reparo corre no jogo de quem controla o carro.
    local dono = NetworkGetEntityOwner(veh)
    if type(dono) ~= 'number' or dono <= 0 then dono = src end
    TriggerClientEvent('norte_staff:reparar', dono, NetworkGetNetworkIdFromEntity(veh))
    registar(src, 'fix')
    responder(src, 'Carro reparado', 'success')
end)

-- ============================================
-- Jogadores
-- ============================================

Whip.command('revive', { dev = true, whileDead = true }, function(src, args)
    local id, why = alvo(src, args[1], true)
    if not id then return responder(src, why, 'error') end

    local ok, err = exports.whip_core:RevivePlayer(id, 'norte_staff')
    if not ok then return responder(src, err or 'Não foi possível reanimar', 'error') end

    registar(src, 'revive', id)
    responder(src, ('Jogador %d reanimado'):format(id), 'success')
end)

Whip.command('heal', { dev = true, whileDead = true }, function(src, args)
    local id, why = alvo(src, args[1], true)
    if not id then return responder(src, why, 'error') end

    if exports.whip_core:IsPlayerDead(id) then
        exports.whip_core:RevivePlayer(id, 'norte_staff')
    end

    local valores = { health = 200, armour = 100, hunger = 100, thirst = 100 }
    for stat, valor in pairs(valores) do
        local ok, err = exports.whip_core:SetStat(id, stat, valor, 'norte_staff:heal')
        if not ok and stat == 'health' then
            return responder(src, err or 'Não foi possível curar', 'error')
        end
    end

    registar(src, 'heal', id)
    responder(src, ('Jogador %d curado'):format(id), 'success')
end)

Whip.command('kick', { dev = true }, function(src, args)
    local id, why = alvo(src, args[1], false)
    if not id then return responder(src, why, 'error') end

    local motivo = table.concat(args, ' ', 2)
    if motivo == '' then motivo = 'Removido pela staff' end

    registar(src, 'kick', ('%d %s'):format(id, motivo))
    local ok, err = exports.whip_core:KickPlayer(id, motivo)
    if not ok then return responder(src, err or 'Não foi possível expulsar', 'error') end
    responder(src, ('Jogador %d expulso'):format(id), 'success')
end)

Whip.command('freeze', { dev = true }, function(src, args)
    local id, why = alvo(src, args[1], false)
    if not id then return responder(src, why, 'error') end

    local estado = not congelados[id]
    congelados[id] = estado or nil
    TriggerClientEvent('norte_staff:congelar', id, estado)

    registar(src, 'freeze', ('%d %s'):format(id, tostring(estado)))
    responder(src, ('Jogador %d %s'):format(id, estado and 'congelado' or 'descongelado'), 'success')
end)

-- ============================================
-- Teleportes
-- ============================================

Whip.command('tp', { dev = true }, function(src, args)
    if not soJogador(src) then return end
    local id, why = alvo(src, args[1], false)
    if not id then return responder(src, why, 'error') end

    local c = exports.whip_core:GetPlayerCoords(id)
    if not c then return responder(src, 'Posição do jogador desconhecida', 'error') end

    teleportar(src, c.x, c.y, c.z)
    registar(src, 'tp', id)
end)

Whip.command('bring', { dev = true }, function(src, args)
    if not soJogador(src) then return end
    local id, why = alvo(src, args[1], false)
    if not id then return responder(src, why, 'error') end

    local c = exports.whip_core:GetPlayerCoords(src)
    if not c then return responder(src, 'A tua posição é desconhecida', 'error') end

    teleportar(id, c.x, c.y, c.z)
    registar(src, 'bring', id)
    responder(src, ('Jogador %d trazido'):format(id), 'success')
end)

Whip.command('tpm', { dev = true }, function(src)
    if not soJogador(src) then return end
    guardarPosicao(src)
    TriggerClientEvent('norte_staff:teleportMarcador', src)
    registar(src, 'tpm')
end)

Whip.command('tpc', { dev = true }, function(src, args)
    if not soJogador(src) then return end
    local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    if not (x and y and z) or math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 3000 then
        return responder(src, 'Uso: /tpc <x> <y> <z>', 'error')
    end
    teleportar(src, x, y, z)
    registar(src, 'tpc', ('%.1f %.1f %.1f'):format(x, y, z))
end)

Whip.command('voltar', { dev = true }, function(src)
    if not soJogador(src) then return end
    local c = posAnterior[src]
    if not c then return responder(src, 'Sem posição anterior', 'error') end
    teleportar(src, c.x, c.y, c.z, c.w)
    registar(src, 'voltar')
end)

-- ============================================
-- Mundo e servidor
-- ============================================

Whip.command('hora', { dev = true }, function(src, args)
    local h, m = tonumber(args[1]), tonumber(args[2] or 0)
    if not h or not m then return responder(src, 'Uso: /hora <hora> [minuto]', 'error') end
    h, m = math.floor(h) % 24, math.floor(m) % 60

    local ok, err = exports.whip_core:SetTime(h, m)
    if not ok then return responder(src, err or 'Hora inválida', 'error') end
    registar(src, 'hora', ('%02d:%02d'):format(h, m))
    responder(src, ('Hora mudada para %02d:%02d'):format(h, m), 'success')
end)

Whip.command('clima', { dev = true }, function(src, args)
    if not args[1] then return responder(src, 'Uso: /clima <CLEAR|RAIN|THUNDER|...>', 'error') end

    local ok, err = exports.whip_core:SetWeather(args[1])
    if not ok then return responder(src, err or 'Clima inválido', 'error') end
    registar(src, 'clima', args[1])
    responder(src, ('Clima mudado para %s'):format(args[1]:upper()), 'success')
end)

Whip.command('anuncio', { dev = true }, function(src, args, raw)
    local texto = raw:match('^%S+%s+(.+)$')
    if not texto then return responder(src, 'Uso: /anuncio <texto>', 'error') end
    texto = texto:sub(1, Config.AnuncioMax)

    exports.whip_core:NotifyPlayer(-1, texto, 'warning', 10000)
    registar(src, 'anuncio', texto)
end)

-- ============================================
-- Limpeza
-- ============================================

AddEventHandler('playerDropped', function()
    local src = source
    removerCarro(src)
    posAnterior[src] = nil
    congelados[src] = nil
    god[src] = nil
end)

AddEventHandler('whip_core:player:logout', function(e)
    if GetInvokingResource() ~= 'whip_core' or not e or not e.source then return end
    removerCarro(e.source)
end)
