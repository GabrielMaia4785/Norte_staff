-- norte_staff: lado do cliente.
-- Estes eventos só chegam do servidor, que já verificou o modo de desenvolvedor.
-- O cliente volta a confirmar com HasDevTools e desliga tudo quando o modo sai.

local ativo = { noclip = false, god = false, invis = false }
local noclipEnt = nil   -- entidade que o noclip move (ped ou carro)

local NOMES = { noclip = 'Noclip', god = 'God mode', invis = 'Invisível' }

-- Teclas que o noclip lê; ficam bloqueadas para o jogo enquanto ele está ligado.
local K = {
    frente = 32, tras = 33, esquerda = 34, direita = 35,
    subir = 22, descer = 36, rapido = 21, lento = 19,
}
local BLOQUEIO = { 21, 22, 36, 19, 24, 25, 44, 45, 71, 72, 59, 63, 64, 75, 140, 141, 142 }

local function avisar(texto, tipo)
    Whip.core:Notify(texto, tipo or 'info')
end

local function devAtivo()
    local ok = Whip.core:HasDevTools()
    return ok == true
end

-- ============================================
-- God e invisível: holds do WHIP, que combinam com os de outros recursos
-- ============================================

local function aplicarGod(on)
    if not on then
        Whip.core:ReleasePlayerPed('norte_staff_god')
        return
    end
    Whip.core:HoldPlayerPed('norte_staff_god', { invincible = true })

    -- Como o God Mode do /w: vida tirada por fome, sede ou outro script volta ao máximo.
    CreateThread(function()
        while ativo.god do
            local ped = PlayerPedId()
            local max = GetEntityMaxHealth(ped)
            if GetEntityHealth(ped) < max then SetEntityHealth(ped, max) end
            Wait(250)
        end
    end)
end

local INVIS_ALPHA = 128   -- o próprio staff vê-se a meia opacidade, como no /w

local function aplicarInvis(on)
    if not on then
        Whip.core:ReleasePlayerPed('norte_staff_invis')
        ResetEntityAlpha(PlayerPedId())
        return
    end
    Whip.core:HoldPlayerPed('norte_staff_invis', { hidden = true })

    -- Loop por frame só enquanto invisível: SetEntityLocallyVisible vale um frame.
    CreateThread(function()
        while ativo.invis do
            local ped = PlayerPedId()
            SetEntityLocallyVisible(ped)
            if GetEntityAlpha(ped) ~= INVIS_ALPHA then SetEntityAlpha(ped, INVIS_ALPHA, false) end
            Wait(0)
        end
    end)
end

-- ============================================
-- Noclip
-- ============================================

local function soltarCarro(veh)
    if veh and DoesEntityExist(veh) and IsEntityAVehicle(veh) then
        FreezeEntityPosition(veh, false)
        SetEntityCollision(veh, true, true)
        SetEntityInvincible(veh, false)
    end
end

local function prenderCarro(veh)
    FreezeEntityPosition(veh, true)
    SetEntityCollision(veh, false, false)
    SetEntityInvincible(veh, true)
end

local function pararNoclip()
    ativo.noclip = false
    soltarCarro(noclipEnt)
    noclipEnt = nil
    Whip.core:ReleasePlayerPed('norte_staff_noclip')
    Whip.core:UnblockControls('norte_staff_noclip')
end

local function iniciarNoclip()
    ativo.noclip = true
    Whip.core:HoldPlayerPed('norte_staff_noclip', {
        invincible = true, hidden = true, noCollision = true, frozen = true,
    })
    Whip.core:BlockControls('norte_staff_noclip', { controls = BLOQUEIO })

    -- Loop por frame só enquanto o noclip está ligado: o movimento segue a câmara a cada frame.
    CreateThread(function()
        while ativo.noclip do
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            local ent = (veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped) and veh or ped

            if ent ~= noclipEnt then
                soltarCarro(noclipEnt)
                if ent ~= ped then prenderCarro(ent) end
                noclipEnt = ent
            end

            local rot = GetGameplayCamRot(2)
            local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
            local frente = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
            local direita = vector3(math.cos(yaw), math.sin(yaw), 0.0)

            local mov = vector3(0.0, 0.0, 0.0)
            if IsDisabledControlPressed(0, K.frente) then mov = mov + frente end
            if IsDisabledControlPressed(0, K.tras) then mov = mov - frente end
            if IsDisabledControlPressed(0, K.direita) then mov = mov + direita end
            if IsDisabledControlPressed(0, K.esquerda) then mov = mov - direita end
            if IsDisabledControlPressed(0, K.subir) then mov = mov + vector3(0.0, 0.0, 1.0) end
            if IsDisabledControlPressed(0, K.descer) then mov = mov - vector3(0.0, 0.0, 1.0) end

            local vel = Config.Noclip.normal
            if IsDisabledControlPressed(0, K.rapido) then
                vel = Config.Noclip.rapido
            elseif IsDisabledControlPressed(0, K.lento) then
                vel = Config.Noclip.lento
            end

            local pos = GetEntityCoords(ent)
            local novo = pos + mov * (vel * GetFrameTime())
            SetEntityCoordsNoOffset(ent, novo.x, novo.y, novo.z, true, true, true)
            SetEntityHeading(ent, rot.z)

            Wait(0)
        end
    end)
end

-- ============================================
-- Ligar e desligar
-- ============================================

local APLICAR = {
    noclip = function(on) if on then iniciarNoclip() else pararNoclip() end end,
    god = function(on) ativo.god = on; aplicarGod(on) end,
    invis = function(on) ativo.invis = on; aplicarInvis(on) end,
}

local function desligarTudo()
    for nome, on in pairs(ativo) do
        if on then APLICAR[nome](false) end
    end
end

RegisterNetEvent('norte_staff:toggle', function(nome, estado)
    if not APLICAR[nome] then return end
    if not devAtivo() then return avisar('Liga o modo de desenvolvedor em /w', 'error') end

    -- O /god chega com o estado do servidor, que também enche colete, fome e sede.
    local on
    if type(estado) == 'boolean' then on = estado else on = not ativo[nome] end
    if on == ativo[nome] then return end
    APLICAR[nome](on)
    avisar(('%s %s'):format(NOMES[nome], on and 'ligado' or 'desligado'), on and 'success' or 'info')
end)

AddEventHandler('whip_core:devtools:modeChanged', function(e)
    if e and e.on == false then desligarTudo() end
end)

-- ============================================
-- Teleporte
-- ============================================

local function entidadeQueMove()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then return veh end
    return ped
end

local function irPara(x, y, z, h)
    local ent = entidadeQueMove()
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ent, x, y, z, false, false, false, false)
    if h then SetEntityHeading(ent, h) end
end

RegisterNetEvent('norte_staff:teleport', function(x, y, z, h)
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return end
    irPara(x, y, z, type(h) == 'number' and h or nil)
end)

RegisterNetEvent('norte_staff:teleportMarcador', function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return avisar('Marca um ponto no mapa primeiro', 'error') end

    local alvo = GetBlipInfoIdCoord(blip)
    local ent = entidadeQueMove()

    -- Procura o chão de cima para baixo, carregando a colisão em cada altura.
    for z = 1000.0, 0.0, -50.0 do
        SetEntityCoordsNoOffset(ent, alvo.x, alvo.y, z, false, false, false)
        RequestCollisionAtCoord(alvo.x, alvo.y, z)
        Wait(50)
        local achou, chao = GetGroundZFor_3dCoord(alvo.x, alvo.y, z, false)
        if achou then
            irPara(alvo.x, alvo.y, chao + 1.0)
            return
        end
    end
    irPara(alvo.x, alvo.y, 200.0)
    avisar('Chão não encontrado, ficaste no ar', 'warning')
end)

-- ============================================
-- Veículos
-- ============================================

RegisterNetEvent('norte_staff:entrarCarro', function(netId)
    if type(netId) ~= 'number' then return end
    local limite = GetGameTimer() + 5000
    while not NetworkDoesEntityExistWithNetworkId(netId) and GetGameTimer() < limite do
        Wait(50)
    end
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end
    TaskWarpPedIntoVehicle(PlayerPedId(), NetToVeh(netId), -1)
end)

RegisterNetEvent('norte_staff:reparar', function(netId)
    if type(netId) ~= 'number' or not NetworkDoesEntityExistWithNetworkId(netId) then return end
    local veh = NetToVeh(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end

    -- Este evento vai para o dono de rede do carro, que normalmente já tem o controlo.
    if not NetworkHasControlOfEntity(veh) then
        local ok = Whip.core:TakeVehicleControl({ entity = veh })
        if not ok then return end
    end

    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
end)

-- ============================================
-- Congelar (feito pela staff a outro jogador)
-- ============================================

RegisterNetEvent('norte_staff:congelar', function(estado)
    if estado then
        Whip.core:HoldPlayerPed('norte_staff_freeze', { frozen = true })
        avisar('Foste congelado pela staff', 'warning')
    else
        Whip.core:ReleasePlayerPed('norte_staff_freeze')
        avisar('Foste descongelado', 'info')
    end
end)

-- ============================================
-- Limpeza
-- ============================================

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- Holds e bloqueios do WHIP saem sozinhos com o recurso. O carro preso no noclip não.
    soltarCarro(noclipEnt)
end)
