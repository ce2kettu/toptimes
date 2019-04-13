Leaderboard = {}
Leaderboard.cache = {}
Leaderboard.oldCache = {}
Leaderboard.personalBestCache = {}
Leaderboard.isDeleting = {}
Leaderboard.ROWS_TO_SHOW = 8
Leaderboard.selectQuery = [[
	SELECT leaderboard.id, accounts.player_account, accounts.player_name, accounts.player_country, leaderboard.time_ms, leaderboard.recorded_at FROM ddc_toptimes AS leaderboard 
	INNER JOIN ddc_accounts AS accounts ON leaderboard.player_id = accounts.id
	INNER JOIN ddc_maps AS maps ON leaderboard.map_id = maps.id
	WHERE maps.map_resource = ?
	ORDER BY time_ms, recorded_at
	LIMIT ?;
]]

Leaderboard.insertQuery = [[
    INSERT INTO ddc_toptimes (map_id, player_id, time_ms, recorded_at)
    SELECT id, (SELECT id FROM ddc_accounts WHERE player_account = ?), ?, NOW() FROM ddc_maps WHERE map_resource = ?
    ON DUPLICATE KEY UPDATE
    recorded_at = IF(time_ms > ?, NOW(), recorded_at),
    time_ms = IF(time_ms > ?, ?, time_ms);
]]

Leaderboard.deleteQuery = [[
	DELETE FROM ddc_toptimes WHERE id = ?
]]

Leaderboard.personalBestQuery = [[
	SELECT rank, accounts.player_account, accounts.player_name, accounts.player_country, time_ms, recorded_at 
	FROM (
		SELECT *, @rownum := @rownum + 1 AS rank
		FROM ddc_toptimes AS leaderboard, (SELECT @rownum := 0) t0
		WHERE leaderboard.map_id = (SELECT id from ddc_maps where map_resource = ?)
		ORDER BY time_ms
	) t1 
	INNER JOIN ddc_accounts AS accounts ON t1.player_id = accounts.id
	WHERE accounts.player_account IN (?);
]]

function Leaderboard.updatePlayerCountry()
	local account = getElementData(source, "account")
	
	if not account then return end	
	
	local country = getElementData(source, "Country")

	if not country then return end		
	
	local connection = exports["CCS_database"]:getConnection()

	if not connection then return end	
	
	dbExec(connection, "UPDATE ddc_accounts SET player_country = ? WHERE player_account = ?;", country, account)
end
addEvent("onPlayerLoggedIn", true)
addEventHandler("onPlayerLoggedIn", root, Leaderboard.updatePlayerCountry)

function Leaderboard.addRecord(player, time)
	local arenaElement = getElementParent(player)
	local map = getElementData(arenaElement, "map")
	local account = getElementData(player, "account")

	if time == 0 or not map then return end
	
	if getElementData(player, "state") ~= "Alive" and getElementData(player, "state") ~= "Finished" then return end

	outputChatBox("#FF5050You finished at "..exports["CCS"]:export_msToTime(time, true), player, 255, 255, 255, true)

	if not getElementData(arenaElement, "toptimes") then
		return outputChatBox("#FF5050This Arena does not have top times enabled", player, 255, 255, 255, true)
	end

	if not account then
		return outputChatBox("#FF5050Guests cannot get top times", player, 255, 255, 255, true)
	end
	
	if getElementData(player, "setting:ban_toptimes") == 1 then
		return outputChatBox("#FF5050You are banned from getting top times", player, 255, 255, 255, true)
	end

	local connection = exports["CCS_database"]:getConnection()

	if not connection then return end
	
	local query = dbPrepareString(connection, Leaderboard.insertQuery, account, time, map.resource, time, time, time)
	dbExec(connection, query)

	local query2 = dbPrepareString(connection, Leaderboard.selectQuery, map.resource, Leaderboard.ROWS_TO_SHOW)
	dbQuery(Leaderboard.callback, {arenaElement, false, account, player, true}, connection, query2)
end

function Leaderboard.callback(handle, arenaElement, isInitialFetch, account, player, isUpdateRequired)
	local result = dbPoll(handle, 0)
	local map = getElementData(arenaElement, "map")

	if not result then
		return dbFree(handle)
	end

	Leaderboard.isDeleting[arenaElement] = false
	Leaderboard.oldCache[arenaElement] = Leaderboard.cache[arenaElement]
	Leaderboard.cache[arenaElement] = {}

	for i, row in ipairs(result) do
		table.insert(Leaderboard.cache[arenaElement], {
			id = row.id,
			account = row.player_account,
			nickname = row.player_name,
			country = row.player_country,
			time = row.time_ms,
			date = row.recorded_at
		})
	end

	if not map then return end

	local connection = exports["CCS_database"]:getConnection()

	if not connection then return end

	if isInitialFetch then
		return Leaderboard.fetchAllPersonalBestTimes(arenaElement)
	end
	
	-- after map change no old times exist
	if not Leaderboard.oldCache[arenaElement] then return end
	
	for i = 1, Leaderboard.ROWS_TO_SHOW, 1 do
		if not Leaderboard.oldCache[arenaElement][i] and result[i] then return end

		--someone deleted a top time
		if Leaderboard.oldCache[arenaElement][i] and not result[i] then
			Leaderboard.fetchAllPersonalBestTimes(arenaElement)

		--someone got a new top without replacing the old one
		elseif result[i] and not Leaderboard.oldCache[arenaElement][i] then
			if account and result[i].player_account == account then
				if i == 1 then
					exports["CCS"]:export_outputGlobalChat("#FF0000* #FFFFFF"..result[i].player_name:gsub("#%x%x%x%x%x%x", "").." got a new #"..i.." top time on "..map.name)
				else
					exports["CCS"]:export_outputArenaChat(arenaElement, "#FF0000* #FFFFFF"..result[i].player_name:gsub("#%x%x%x%x%x%x", "").." got a new #"..i.." top time")
				end
			end

			Leaderboard.fetchAllPersonalBestTimes(arenaElement)

		--someone got a new top time
		elseif Leaderboard.oldCache[arenaElement][i].time ~= result[i].time_ms then
			if account and result[i].player_account == account then
				if i == 1 then
					exports["CCS"]:export_outputGlobalChat("#FF0000* #FFFFFF"..result[i].player_name:gsub("#%x%x%x%x%x%x", "").." got a new #"..i.." top time on "..map.name)
				else
					exports["CCS"]:export_outputArenaChat(arenaElement, "#FF0000* #FFFFFF"..result[i].player_name:gsub("#%x%x%x%x%x%x", "").." got a new #"..i.." top time")
				end
			end

			Leaderboard.fetchAllPersonalBestTimes(arenaElement)
		elseif isElement(player) and isUpdateRequired then
			Leaderboard.fetchPersonalBestTime(player)
		end
	end
end

function Leaderboard.fetchPersonalBestTime(requestedPlayer)
	if not isElement(requestedPlayer) then return end

	local arenaElement = getElementParent(requestedPlayer)
	local map = getElementData(arenaElement, "map")

	if not map then return end

	local connection = exports["CCS_database"]:getConnection()

	if not connection then return end

	local account = getElementData(requestedPlayer, "account")
	local players = {}
	table.insert(players, requestedPlayer)

	if account then
		local query = dbPrepareString(connection, Leaderboard.personalBestQuery, map.resource, account)
		dbQuery(Leaderboard.personalBestCallback, {arenaElement, players}, connection, query)
	else
		Leaderboard.personalBestCallback(nil, arenaElement, players, true)
	end
end

function Leaderboard.arenaJoin()
	Leaderboard.fetchPersonalBestTime(source)
end
addEvent("onPlayerJoinArena", true)
addEventHandler("onPlayerJoinArena", root, Leaderboard.arenaJoin)

function Leaderboard.fetchAllPersonalBestTimes(arenaElement)
	local map = getElementData(arenaElement, "map")

	if not map then return end

	local connection = exports["CCS_database"]:getConnection()

	if not connection then return end

	local players = exports["CCS"]:export_getPlayersInArena(arenaElement)
	local accountsToFetch = {}

	for i, player in ipairs(players) do
		local account = getElementData(player, "account")

		if account then
			table.insert(accountsToFetch, "'"..account.."'")
		end	
	end

	if #accountsToFetch ~= 0 then
		local values = table.concat(accountsToFetch, ",")
		local query = [[
			SELECT rank, accounts.player_account, accounts.player_name, accounts.player_country, time_ms, recorded_at 
			FROM (
				SELECT *, @rownum := @rownum + 1 AS rank
				FROM ddc_toptimes AS leaderboard, (SELECT @rownum := 0) t0
				WHERE leaderboard.map_id = (SELECT id from ddc_maps where map_resource = ?)
				ORDER BY time_ms
			) t1 
			INNER JOIN ddc_accounts AS accounts ON t1.player_id = accounts.id
			WHERE accounts.player_account IN (]]..values..")";

		local query2 = dbPrepareString(connection, query, map.resource, values)
		dbQuery(Leaderboard.personalBestCallback, {arenaElement, players}, connection, query2)
	else
		Leaderboard.personalBestCallback(nil, arenaElement, players, true)
	end
end

function Leaderboard.personalBestCallback(handle, arenaElement, players, isManual)
	local map = getElementData(arenaElement, "map")

	if not isManual then
		local result = dbPoll(handle, 0)

		if not result then
			dbFree(handle)
		else
			Leaderboard.personalBestCache[arenaElement] = {}
		
			for i, row in ipairs(result) do
				Leaderboard.personalBestCache[arenaElement][row.player_account] = {
					rank = row.rank,
					account = row.player_account,
					nickname = row.player_name,
					country = row.player_country,
					time = row.time_ms,
					date = row.recorded_at
				}
			end
		end
	end

	if not map then return end

	for i, player in ipairs(players) do
		local account = getElementData(player, "account")
		local personalBest = Leaderboard.personalBestCache[arenaElement] and Leaderboard.personalBestCache[arenaElement][account] or false
		triggerClientEvent(player, "onClientTopTimesUpdate", player, Leaderboard.cache[arenaElement], personalBest)
	end
end

function Leaderboard.fetchLeaderboard(map)
	Leaderboard.oldCache[source] = nil
	Leaderboard.cache[source] = nil
	Leaderboard.personalBestCache[source] = nil

	local connection = exports["CCS_database"]:getConnection()

	if not connection then return end
	
	local query = dbPrepareString(connection, Leaderboard.selectQuery, map.resource, Leaderboard.ROWS_TO_SHOW)
	dbQuery(Leaderboard.callback, {source, true}, connection, query)
end
addEvent("onMapChange", true)
addEventHandler("onMapChange", root, Leaderboard.fetchLeaderboard)

function Leaderboard.clientRequest()
	local arenaElement = getElementParent(source)
	local map = getElementData(arenaElement, "map")

	if not getElementData(arenaElement, "toptimes") or not Leaderboard.cache[arenaElement] or not map then return end

	local account = getElementData(source, "account")
	local personalBest = Leaderboard.personalBestCache[arenaElement] and Leaderboard.personalBestCache[arenaElement][account] or false
	triggerClientEvent(source, "onClientTopTimesUpdate", source, Leaderboard.cache[arenaElement], personalBest)
end
addEvent("onPlayerRequestTopTimes", true)
addEventHandler("onPlayerRequestTopTimes", root, Leaderboard.clientRequest)

function Leaderboard.deleteRecord(p, c, indexToRemove)
	local arenaElement = getElementParent(p)
	local map = getElementData(arenaElement, "map")
	indexToRemove = tonumber(indexToRemove)

	if not getElementData(arenaElement, "toptimes") or not indexToRemove or not map then return end
	
	if indexToRemove > Leaderboard.ROWS_TO_SHOW or Leaderboard.isDeleting[arenaElement] or not Leaderboard.cache[arenaElement][indexToRemove] then return end

	local connection = exports["CCS_database"]:getConnection()

	if not connection then return end
	
	Leaderboard.isDeleting[arenaElement] = true
	dbExec(connection, Leaderboard.deleteQuery, Leaderboard.cache[arenaElement][indexToRemove].id)

	local query = dbPrepareString(connection, Leaderboard.selectQuery, map.resource, Leaderboard.ROWS_TO_SHOW)
	dbQuery(Leaderboard.callback, {arenaElement}, connection, query)
	
	exports["CCS"]:export_outputArenaChat(arenaElement, "#FF0000* #FFFFFF"..getPlayerName(p):gsub("#%x%x%x%x%x%x", "").." #ff5050removed top #FFFFFF#"..indexToRemove)
end
addCommandHandler("deletetime", Leaderboard.deleteRecord)

function Leaderboard.deathmatchFinish(type, model)
	if not getPedOccupiedVehicle(source) or type ~= "vehiclechange" then return end

	if model == 425 then
		local time = exports["CCS"]:export_getTimePassed(getElementParent(source))
		Leaderboard.addRecord(source, time)
	end
end
addEvent("onPlayerDerbyPickupHit", true)
addEventHandler("onPlayerDerbyPickupHit", root, Leaderboard.deathmatchFinish)

function Leaderboard.raceFinish()
	local time = exports["CCS"]:export_getTimePassed(getElementParent(source))
	Leaderboard.addRecord(source, time)
end
addEvent("onFinishRace", true)
addEventHandler("onFinishRace", root, Leaderboard.raceFinish)
