-----------------------------------------------------------------------------------
-- АВТОМАУНТ: выдача маунтов при входе в игру
-----------------------------------------------------------------------------------
-- Multistate Eluna: ON_LOGIN / ON_LOGOUT регистрируются только в WORLD-потоке
-- (GetStateMapId() == -1). Очередь выдачи обрабатывается глобальным таймером
-- CreateLuaEvent — по аналогии с tickers_by_threads_example.lua.
--
-- Player events (см. RegisterPlayerEvent в Eluna API):
--   3  ON_LOGIN   — WORLD — (event, player)
--   4  ON_LOGOUT  — WORLD — (event, player)
--
-- Потоки:
--   WORLD (-1)  — регистрация хуков, глобальная очередь, GetPlayerByGUID
--   MAP  (>0)   — скрипт загружается, но хуки здесь не вешаем (иначе дубли / мимо)

local PLAYER_EVENT_ON_LOGIN  = 3
local PLAYER_EVENT_ON_LOGOUT = 4

local BATCH_SIZE     = 15  -- маунтов на игрока за один тик очереди
local BATCH_DELAY_MS = 1   -- пауза между тиками, мс

local MOUNTS = {
    458, -- Brown Horse
    459, -- Gray Wolf
}

-- [guidLow] = { index = number, guid = ObjectGuid }
local pending = {}
local queueScheduled = false

local function playerGuidLow(player)
    return tonumber(tostring(player:GetGUIDLow()))
end

local function processMountQueue()
    for guidLow, state in pairs(pending) do
        local player = GetPlayerByGUID(state.guid)
        if not player or not player:IsInWorld() then
            pending[guidLow] = nil
        else
            local last = math.min(state.index + BATCH_SIZE - 1, #MOUNTS)
            for i = state.index, last do
                local spellId = MOUNTS[i]
                if not player:HasSpell(spellId) then
                    player:LearnSpell(spellId)
                end
            end

            state.index = last + 1
            if state.index > #MOUNTS then
                pending[guidLow] = nil
            end
        end
    end

    if next(pending) then
        CreateLuaEvent(processMountQueue, BATCH_DELAY_MS, 1)
    else
        queueScheduled = false
    end
end

local function scheduleMountQueue()
    if queueScheduled then
        return
    end
    queueScheduled = true
    CreateLuaEvent(processMountQueue, BATCH_DELAY_MS, 1)
end

local function OnLogin(_, player)
    local guidLow = playerGuidLow(player)
    pending[guidLow] = {
        index = 1,
        guid = player:GetGUID(),
    }
    scheduleMountQueue()
end

local function OnLogout(_, player)
    pending[playerGuidLow(player)] = nil
    if not next(pending) then
        queueScheduled = false
    end
end

---------------------------------------------
-- РЕГИСТРАЦИЯ ТОЛЬКО В WORLD-ПОТОКЕ
---------------------------------------------

if GetStateMapId() == -1 then
    RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)
    RegisterPlayerEvent(PLAYER_EVENT_ON_LOGOUT, OnLogout)
    print(string.format(
        "[Eluna] AutoMount: ON_LOGIN (%d) / ON_LOGOUT (%d) registered in WORLD state; %d mounts, batch %d.",
        PLAYER_EVENT_ON_LOGIN,
        PLAYER_EVENT_ON_LOGOUT,
        #MOUNTS,
        BATCH_SIZE
    ))
end