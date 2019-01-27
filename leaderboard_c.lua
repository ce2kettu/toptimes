local screenX, screenY = guiGetScreenSize()
local ratioX, ratioY = (screenX / 800), (screenY / 600)
local startX = 800 * ratioX
local startY = 200 * ratioY
local endX = nil
local endY = startY
local positionX = startX
local positionY = startY
local leaderboardWidth = 0
local toggleDelay = nil
local leaderboard = {}
local isAnimating = false
local animationStartTime = nil
local animationEndTime = nil
local tableColumns = {}
local isToggled = false
local isClientReady = false
local personalRecord = false
local isAlreadyShown = false
local TOGGLE_KEY = "F5"
local ANIMATION_NAME = "InOutQuad"
local LEADERBOARD_OFFSET = 20 * ratioY
local TOGGLE_DURATION = 5000
local ROWS_TO_SHOW = 8
local ROW_FONT_SIZE = 1
local ROW_FONT_COLOR = tocolor(200, 200, 200, 255)
local ROW_BACKGROUND_COLOR = tocolor(22, 28, 32, 225)
local ROW_PADDING_START = 0
local ROW_PADDING_END = 7.5 * ratioX
local ROW_PADDING_Y = 3 * ratioY
local ROW_FONT = dxCreateFont("fonts/Inter-UI-Regular.ttf", math.floor(8 * ratioY))
local ROW_SIZE = dxGetFontHeight(ROW_FONT_SIZE, ROW_FONT) + ROW_PADDING_Y
local COLUMN_HEIGHT_MULTIPLIER = 1.15
local COLUMN_FONT_SIZE = 1
local COLUMN_FONT = dxCreateFont("fonts/Inter-UI-Medium.ttf", math.floor(7 * ratioY))
local COLUMN_BACKGROUND_COLOR = tocolor(14, 23, 26, 240)
local COLUMN_FONT_COLOR = tocolor(255, 255, 255, 255)
local BORDER_SIZE = 3
local BORDER_LEFT_COLOR_HIGHLIGHT = tocolor(64, 196, 255, 255)
local HIGHLIGHT_IMAGE_PATH = "images/gradient_highlight.png"

function main()

	addColumn({
		title = "Rank", 
		width = dxGetTextWidth("_XX_.", ROW_FONT_SIZE, ROW_FONT),
		computed = function(row, index)
			return index and index.."." or "—"
		end,
		alignX = nil,
		alignY = nil,
		rowAlignX = "center",
		rowAlignY = nil,
		isColorCoded = nil,
		isUpperCase = nil,
		isImage = true, 
		imagePath = "images/rank.png", 
		imageSize = 12,
		isValueImage = false,
		rowImageSize = nil,
		isImageCentered = true
	})

	addColumn({
		title = "Nickname", 
		width = dxGetTextWidth("_XXXXXXXXXXXXXXX_", ROW_FONT_SIZE, ROW_FONT),
		computed = function(row)
			return row and row.nickname or "Empty"
		end
	})

	addColumn({
		title = "Time",
		width = dxGetTextWidth("_00:00:000___", ROW_FONT_SIZE, ROW_FONT),
		computed = function(row)
			return row and exports["CCS"]:export_msToTime(row.time, true) or "—"
		end
	})

	addColumn({
		title = "Date",
		width = dxGetTextWidth("_XXXX.XX.XX__", ROW_FONT_SIZE, ROW_FONT),
		computed = function(row)
			return row and convertDate(row.date) or "—"
		end
	})

	addColumn({
		title = "Country",
		width = math.floor(12 * ratioY) + (tableColumns[1].width / 2),
		computed = function(row)
			local imageName = row and row.country or "_unknown"
			return "images/flags/"..imageName..".png"
		end,
		alignX = nil,
		alignY = nil,
		rowAlignX = nil,
		rowAlignY = nil,
		isColorCoded = nil,
		isUpperCase = nil,
		isImage = true,
		imagePath = "images/country.png",
		imageSize = 12,
		isValueImage = true,
		rowImageSize = 13.5,
		isImageCentered = false
	})

	for i, column in pairs(tableColumns) do
		leaderboardWidth = leaderboardWidth + column.width
	end

	leaderboardWidth = leaderboardWidth
	endX = startX - leaderboardWidth - LEADERBOARD_OFFSET
	
end
addEventHandler("onClientResourceStart", resourceRoot, main)

function render()

	local arena = getElementParent(localPlayer)
	local map = getElementData(arena, "map")

	if not map then return end

	local currentX = positionX + ROW_PADDING_START
	local currentY = positionY

	dxDrawRectangle(currentX - ROW_PADDING_START, currentY, leaderboardWidth, ROW_SIZE * COLUMN_HEIGHT_MULTIPLIER, COLUMN_BACKGROUND_COLOR)
	
	for i, column in pairs(tableColumns) do
		local title = column.isUpperCase and column.title:upper() or column.title

		if column.isImage then
			local imageSize = math.floor(column.imageSize * ratioY)

			if column.isImageCentered then
				dxDrawImage(currentX + ((column.rowImageSize - column.imageSize) / 2) + (column.width / 2) - (column.imageSize / 2), currentY + ((ROW_SIZE * COLUMN_HEIGHT_MULTIPLIER) / 2) - (imageSize / 2), imageSize, imageSize, column.imagePath)
			else
				dxDrawImage(currentX + ((column.rowImageSize - column.imageSize) / 2), currentY + ((ROW_SIZE * COLUMN_HEIGHT_MULTIPLIER) / 2) - (imageSize / 2), imageSize, imageSize, column.imagePath)
			end
		else
			dxDrawText(title, currentX, currentY, currentX + column.width, currentY + ROW_SIZE * COLUMN_HEIGHT_MULTIPLIER, COLUMN_FONT_COLOR, COLUMN_FONT_SIZE, COLUMN_FONT, column.alignX, column.alignY, false, false, false, column.isColorCoded, false)
		end

		currentX = currentX + column.width
	end

	currentY = currentY + ROW_SIZE * COLUMN_HEIGHT_MULTIPLIER - ROW_SIZE

	for i = 1, ROWS_TO_SHOW, 1 do
		currentX = positionX
		currentY = currentY + ROW_SIZE

		if personalRecord and tonumber(personalRecord.rank) == i then
			dxDrawImage(currentX, currentY, leaderboardWidth, ROW_SIZE, HIGHLIGHT_IMAGE_PATH)
			dxDrawRectangle(currentX, currentY, BORDER_SIZE, ROW_SIZE, BORDER_LEFT_COLOR_HIGHLIGHT)
		else
			dxDrawRectangle(currentX, currentY, leaderboardWidth, ROW_SIZE, ROW_BACKGROUND_COLOR)
		end

		currentX = currentX + ROW_PADDING_START 

		for j, column in pairs(tableColumns) do
			local value = column.computed(leaderboard[i], i)			

			if column.isValueImage then
				local imageSize = math.floor(column.rowImageSize * ratioY)
				dxDrawImage(currentX, currentY + (ROW_SIZE / 2) - (imageSize / 2), imageSize, imageSize, value)
			else
				value = textOverflow(value, ROW_FONT_SIZE, ROW_FONT, column.width, true)

				if column.isImage then
					dxDrawText(value, currentX + (column.imageSize / 2), currentY, currentX + column.width, currentY + ROW_SIZE, ROW_FONT_COLOR, ROW_FONT_SIZE, ROW_FONT, column.rowAlignX, column.rowAlignY, false, false, false, true, false)
				else
					dxDrawText(value, currentX, currentY, currentX + column.width, currentY + ROW_SIZE, ROW_FONT_COLOR, ROW_FONT_SIZE, ROW_FONT, column.rowAlignX, column.rowAlignY, false, false, false, true, false)
				end
			end

			currentX = currentX + column.width
		end
	end

	currentX = positionX + ROW_PADDING_START
	currentY = currentY + ROW_SIZE

	if personalRecord and tonumber(personalRecord.rank) > 8 then
		dxDrawImage(positionX, currentY, leaderboardWidth, ROW_SIZE, HIGHLIGHT_IMAGE_PATH)
		dxDrawRectangle(positionX, currentY, BORDER_SIZE, ROW_SIZE, BORDER_LEFT_COLOR_HIGHLIGHT)

		for i, column in ipairs(tableColumns) do
			local value = column.computed(personalRecord, personalRecord.rank)

			if column.isValueImage then
				local imageSize = math.floor(column.rowImageSize * ratioY)
				dxDrawImage(currentX, currentY + (ROW_SIZE / 2) - (imageSize / 2), imageSize, imageSize, value)
			else
				if column.isImage then
					local textWidth = dxGetTextWidth(value, ROW_FONT_SIZE, ROW_FONT)
					local fontSize = textFit(value, ROW_FONT_SIZE, ROW_FONT, column.width, 10)
					dxDrawText(value, currentX + (column.imageSize / 2), currentY, currentX + column.width, currentY + ROW_SIZE, ROW_FONT_COLOR, fontSize, ROW_FONT, column.rowAlignX, column.rowAlignY, false, false, false, true, false)
				else
					value = textOverflow(value, ROW_FONT_SIZE, ROW_FONT, column.width, true)
					dxDrawText(value, currentX, currentY, currentX + column.width, currentY + ROW_SIZE, ROW_FONT_COLOR, ROW_FONT_SIZE, ROW_FONT, column.rowAlignX, column.rowAlignY, false, false, false, true, false)
				end
			end

			currentX = currentX + column.width
		end
	end
	
end

function updateLeaderboard(list, personalBest, isInitialFetch)

	local arena = getElementParent(localPlayer)
	local map = getElementData(arena, "map")
	personalRecord = false

	--[[ if isAlreadyShown and isInitialFetch then return end ]]
	if not isClientReady or not getElementData(arena, "toptimes") or not map or not list then return end

--[[ 	if isInitialFetch then 
		isAlreadyShown = true
	else
		isAlreadyShown = false
	end ]]

	if personalBest then
		personalRecord = personalBest
	end

	removeEventHandler("onClientRender", root, animationOut)
	removeEventHandler("onClientRender", root, animationIn)
	removeEventHandler("onClientRender", root, render)
	leaderboard = list
	isAnimating = false
	isToggled = false
	setTimer(function() toggle() end, 1000, 1)
	
end
addEvent("onClientTopTimesUpdate", true)
addEventHandler("onClientTopTimesUpdate", root, updateLeaderboard)


addEvent("onClientPlayerSpawn", true)
addEventHandler("onClientPlayerSpawn", root, function()
	if isClientReady then return end
	isClientReady = true
	triggerServerEvent("onPlayerRequestTopTimes", localPlayer)
end)


addEvent("onClientMapChange", true)
addEventHandler("onClientMapChange", root, function()
	isClientReady = false
end)


function toggle()
	local arena = getElementParent(localPlayer)

	if not getElementData(arena, "toptimes") or isAnimating then return end
	if isTimer(toggleDelay) then killTimer(toggleDelay) end

	animationStartTime = getTickCount()
	animationEndTime = animationStartTime + 1000

	if isToggled then
		isAnimating = true
		isToggled = false
		addEventHandler("onClientRender", root, animationOut)
	else
		isAnimating = true
		isToggled = true
		addEventHandler("onClientRender", root, animationIn)
		addEventHandler("onClientRender", root, render)
		toggleDelay = setTimer(toggle, TOGGLE_DURATION, 1)
	end
end
bindKey(TOGGLE_KEY, "down", toggle)


function animationIn()
	local now = getTickCount()
	local elapsedTime = now - animationStartTime
	local duration = animationEndTime - animationStartTime
	local progress = elapsedTime / duration

	positionX, positionY = interpolateBetween(startX, startY, 0, endX, endY, 0, progress, ANIMATION_NAME)

	if progress >= 1 then
		removeEventHandler("onClientRender", root, animationIn)
		isAnimating = false
	end
end


function animationOut()
	local now = getTickCount()
	local elapsedTime = now - animationStartTime
	local duration = animationEndTime - animationStartTime
	local progress = elapsedTime / duration

	positionX, positionY = interpolateBetween(endX, endY, 0, startX, startY, 0, progress, ANIMATION_NAME)

	if progress >= 1 then
		removeEventHandler("onClientRender", root, animationOut)
		removeEventHandler("onClientRender", root, render)
		isAnimating = false
	end
end


function reset()
	if isTimer(toggleDelay) then killTimer(toggleDelay) end

	removeEventHandler("onClientRender", root, render)
	removeEventHandler("onClientRender", root, animationIn)
	removeEventHandler("onClientRender", root, animationOut)
	isToggled = false
	isAnimating = false
end
addEvent("onClientArenaReset", true)
addEventHandler("onClientArenaReset", root, reset)


function addColumn(column)
	column.alignX = column.alignX or "left"
	column.alignY = column.alignY or "center"
	column.rowAlignX = column.rowAlignX or column.alignX
	column.rowAlignY = column.rowAlignY or column.alignY
	column.isImage = column.isImage or false
	column.isColorCoded = column.isColorCoded or true
	column.isUpperCase = column.isUpperCase or true
	column.isValueImage = column.isValueImage or false
	column.rowImageSize = column.rowImageSize or column.imageSize
	column.isImageCentered = column.isImageCentered or false

	table.insert(tableColumns, column)
end


function textFit(text, size, font, width, padding)
	local fontSize = size
	padding = padding or 10
	width = width - padding

	while dxGetTextWidth(text, fontSize, font, true) > width do
		fontSize = fontSize - 0.1
	end

	return fontSize
end


function textOverflow(text, size, font, width, ellipsis)
	local ellipsis = ellipsis or false

	while dxGetTextWidth(text, size, font, true) > width do
		if ellipsis then
			text = text:sub(1, text:len()-4).."..."
		else
			text = text:sub(1, text:len()-1)
		end
	end

	return text
end


function convertDate(date)
	if not date then return false end
    local d, m, y, h, i, s = string.match(date, "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    return string.format("%s.%s.%s", y, m, d) or false
end