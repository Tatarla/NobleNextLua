local test_gift_item = 128768 -- конфета
local test_zone = 4395 -- Dalaran (North)
local test_faction = 69 -- Darnassus
local test_map = 571 -- нордскол

local function countMoneyBonus(player)
    player:ModifyMoney(5);
    local guild = player:GetGuild();
    if (guild ~= nil) then
        player:ModifyMoney(-2);
        guild:DepositBankMoney(player, 4)
    end
end

-- пример начисления предмета и отправки почты
local function countGiftBonus(player)
    local added = player:AddItem(test_gift_item);
	if (added == nil) then
		SendMail("Конфетка", "Конфетка не влезла в ваши карманы и была выслана на почту.", GetGUIDEntry(player:GetGUID()), 0, 61, 20, 0, 0, test_gift_item, 1)
		player:SendBroadcastMessage("|cff629404[-X-] |cff8bad4cКонфетка не влезла в ваши карманы и была выслана на почту.")
	else
		player:SendBroadcastMessage("|cff629404[-X-] |cff8bad4cВы получаете конфетку за активную игру.")
	end
	player:PlayDirectSound(120, player)
end

-- работа с глобальниым потом и WORLD state
local function calculateGlobalBonuses()
    local onlinePlayers = GetPlayersInWorld(2); -- 2-neutral, both horde and aliance
    for _, player in ipairs(onlinePlayers) do
        if player:IsAFK() then return end
		--	Добавление денег
		countMoneyBonus(player)
		--	Бонусы за онлайн
		countGiftBonus(player)
    end
end

-- работа с потоком и объектом карты
local function calculateTestMapBonuses()
    local testMapPlayers = GetPlayersOnMap(2) -- 2-neutral, both horde and aliance
    for _, player in ipairs(testMapPlayers) do
		local zone = player:GetZoneId()
		if zone ~= test_zone then return end
		if player:IsAFK() then return end
			
		local rep = 10
		player:SetReputation(test_faction, player:GetReputation(test_faction) + rep)
    end
end

---------------------------------------------
-- РАСПРЕДЕЛЕНИЕ ТАЙМЕРОВ ПО ПОТОКАМ
---------------------------------------------

local currentState = GetStateMapId()

if currentState == -1 then -- глобальный поток WORLD
    CreateLuaEvent(calculateGlobalBonuses, 600000, 0) -- 600000 это 10 минут
	print("[Eluna] Global online bonuses registered in WORLD state.")
end

if currentState == test_map then -- отдельный поток нордскола (для теста)
    CreateLuaEvent(calculateTestMapBonuses, 600000, 0)
	print("[Eluna] Local map online bonuses registered in MAP state: " .. test_map)
end