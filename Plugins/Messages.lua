-------------------------------------------------------------------------------
-- Module Declaration
--

local plugin = BigWigs:NewPlugin("Messages", "LibSink-2.0")
if not plugin then return end

-------------------------------------------------------------------------------
-- Locals
--

local media = LibStub("LibSharedMedia-3.0")

local labels = {}

local seModule = nil
local colorModule = nil

local normalAnchor = nil
local emphasizeAnchor = nil
local emphasizeCountdownAnchor = nil

local BWMessageFrame = nil

local db = nil

local floor = math.floor

local L = LibStub("AceLocale-3.0"):GetLocale("Big Wigs: Plugins")

--------------------------------------------------------------------------------
-- Anchors
--

local defaultPositions = {
	BWMessageAnchor = {"CENTER"},
	BWEmphasizeMessageAnchor = {"TOP", "RaidWarningFrame", "BOTTOM", 0, 45},
	BWEmphasizeCountdownMessageAnchor = {"TOP", "RaidWarningFrame", "BOTTOM", 0, -150},
}

local function onDragStart(self) self:StartMoving() end
local function onDragStop(self)
	self:StopMovingOrSizing()
	local s = self:GetEffectiveScale()
	db[self.x] = self:GetLeft() * s
	db[self.y] = self:GetTop() * s
end

local function showAnchors()
	normalAnchor:Show()
	emphasizeAnchor:Show()
	emphasizeCountdownAnchor:Show()
	seModule.anchorEmphasizedCountdownText:Show()
end

local function hideAnchors()
	normalAnchor:Hide()
	emphasizeAnchor:Hide()
	emphasizeCountdownAnchor:Hide()
end

local function resetAnchors()
	normalAnchor:Reset()
	emphasizeAnchor:Reset()
	emphasizeCountdownAnchor:Reset()
end

--------------------------------------------------------------------------------
-- Options
--

plugin.defaultDB = {
	sink20OutputSink = "BigWigs",
	font = nil,
	monochrome = nil,
	outline = "THICKOUTLINE",
	fontSize = nil,
	usecolors = true,
	scale = 1.0,
	chat = nil,
	useicons = true,
	classcolor = true,
	emphasizedMessages = {
		sink20OutputSink = "BigWigsEmphasized",
	},
	displaytime = 3,
	fadetime = 2,
}

local fakeEmphasizeMessageAddon = {}
LibStub("LibSink-2.0"):Embed(fakeEmphasizeMessageAddon)

plugin.pluginOptions = {
	type = "group",
	name = L["Output"],
	childGroups = "tab",
	args = {
		normal = plugin:GetSinkAce3OptionsDataTable(),
		emphasized = fakeEmphasizeMessageAddon:GetSinkAce3OptionsDataTable(),
	},
}
plugin.pluginOptions.args.normal.name = L["Normal messages"]
plugin.pluginOptions.args.normal.order = 1
plugin.pluginOptions.args.emphasized.name = L["Emphasized messages"]
plugin.pluginOptions.args.emphasized.order = 2

local function updateProfile()
	db = plugin.db.profile
	if normalAnchor then
		normalAnchor:RefixPosition()
		emphasizeAnchor:RefixPosition()
		emphasizeCountdownAnchor:RefixPosition()
	end
end

-------------------------------------------------------------------------------
-- Initialization
--

function plugin:OnRegister()
	db = self.db.profile

	fakeEmphasizeMessageAddon:SetSinkStorage(db.emphasizedMessages)
	self:RegisterSink("BigWigsEmphasized", L["Big Wigs Emphasized"], L.emphasizedSinkDescription, "EmphasizedPrint")
	self:SetSinkStorage(self.db.profile)
	self:RegisterSink("BigWigs", "Big Wigs", L.sinkDescription, "Print")
	self:RegisterMessage("BigWigs_ProfileUpdate", updateProfile)

	if not db.font then
		db.font = media:GetDefault("font")
	end
	if not db.fontSize then
		local _, size = GameFontNormalHuge:GetFont()
		db.fontSize = size
	end
end

do
	local function createAnchor(frameName, title)
		local display = CreateFrame("Frame", frameName, UIParent)
		display.x, display.y = frameName .. "_x", frameName .. "_y"
		display:EnableMouse(true)
		display:SetClampedToScreen(true)
		display:SetMovable(true)
		display:RegisterForDrag("LeftButton")
		display:SetWidth((frameName == "BWEmphasizeCountdownMessageAnchor") and 40 or 200)
		display:SetHeight((frameName == "BWEmphasizeCountdownMessageAnchor") and 40 or 20)
		local bg = display:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(display)
		bg:SetBlendMode("BLEND")
		bg:SetTexture(0, 0, 0, 0.3)
		display.background = bg
		local header = display:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		header:SetText(title)
		if frameName == "BWEmphasizeCountdownMessageAnchor" then
			header:SetPoint("BOTTOM", display, "TOP", 0, 5)
			header:SetJustifyV("TOP")
			seModule.anchorEmphasizedCountdownText = display:CreateFontString(nil, "OVERLAY")
			seModule.anchorEmphasizedCountdownText:SetFont(media:Fetch("font", seModule.db.profile.font), seModule.db.profile.fontSize, seModule.db.profile.outline)
			seModule.anchorEmphasizedCountdownText:SetPoint("CENTER")
			seModule.anchorEmphasizedCountdownText:SetText("5")
			seModule.anchorEmphasizedCountdownText:SetTextColor(seModule.db.profile.fontColor.r, seModule.db.profile.fontColor.g, seModule.db.profile.fontColor.b)
		else
			header:SetAllPoints(display)
			header:SetJustifyV("MIDDLE")
		end
		header:SetJustifyH("CENTER")
		display:SetScript("OnDragStart", onDragStart)
		display:SetScript("OnDragStop", onDragStop)
		display:SetScript("OnMouseUp", function(self, button)
			if button ~= "LeftButton" then return end
			if self:GetName() == "BWEmphasizeCountdownMessageAnchor" or self:GetName() == "BWEmphasizeMessageAnchor" then
				seModule:SendMessage("BigWigs_SetConfigureTarget", seModule)
			else
				plugin:SendMessage("BigWigs_SetConfigureTarget", plugin)
			end
		end)
		display.Reset = function(self)
			db[self.x] = nil
			db[self.y] = nil
			self:RefixPosition()
		end
		display.RefixPosition = function(self)
			self:ClearAllPoints()
			if db[self.x] and db[self.y] then
				local s = self:GetEffectiveScale()
				self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db[self.x] / s, db[self.y] / s)
			else
				self:SetPoint(unpack(defaultPositions[self:GetName()]))
			end
		end
		display:RefixPosition()
		display:Hide()
		return display
	end

	local function createSlots()
		BWMessageFrame = CreateFrame("Frame", "BWMessageFrame", UIParent)
		BWMessageFrame:SetWidth(UIParent:GetWidth())
		BWMessageFrame:SetHeight(80)
		BWMessageFrame:SetPoint("TOP", normalAnchor, "BOTTOM")
		BWMessageFrame:SetScale(db.scale or 1)
		BWMessageFrame:SetFrameStrata("HIGH")
		BWMessageFrame:SetToplevel(true)
		for i = 1, 4 do
			local fs = BWMessageFrame:CreateFontString(nil, "ARTWORK")
			fs:SetWidth(0)
			fs:SetHeight(0)
			fs.elapsed = 0
			fs:Hide()

			fs.anim = fs:CreateAnimationGroup()
			fs.anim:SetScript("OnFinished", function(self)
				self:GetParent():Hide()
				if not labels[1]:IsShown() and not labels[2]:IsShown() and not labels[3]:IsShown() and not labels[4]:IsShown() then
					BWMessageFrame:Hide()
				end
			end)
			fs.animFade = fs.anim:CreateAnimation("Alpha")
			fs.animFade:SetChange(-1)
			fs.animFade:SetStartDelay(db.displaytime)
			fs.animFade:SetDuration(db.fadetime)

			local icon = BWMessageFrame:CreateTexture(nil, "ARTWORK")
			icon:SetPoint("RIGHT", fs, "LEFT")
			icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			icon:Hide()
			fs.icon = icon

			icon.anim = icon:CreateAnimationGroup()
			icon.anim:SetScript("OnFinished", function(self) self:GetParent():Hide() end)
			icon.animFade = icon.anim:CreateAnimation("Alpha")
			icon.animFade:SetChange(-1)
			icon.animFade:SetStartDelay(db.displaytime)
			icon.animFade:SetDuration(db.fadetime)

			labels[i] = fs
		end
	end

	function plugin:OnPluginEnable()
		seModule = BigWigs:GetPlugin("Super Emphasize", true)
		colorModule = BigWigs:GetPlugin("Colors", true)

		if not normalAnchor then
			normalAnchor = createAnchor("BWMessageAnchor", L["Messages"])
			emphasizeAnchor = createAnchor("BWEmphasizeMessageAnchor", L["Emphasized messages"])
			emphasizeCountdownAnchor = createAnchor("BWEmphasizeCountdownMessageAnchor", L["Emphasized countdown"])
			createSlots()
			createAnchor, createSlots = nil, nil
		end

		self:RegisterMessage("BigWigs_ProfileUpdate", updateProfile)

		self:RegisterMessage("BigWigs_ResetPositions", resetAnchors)
		self:RegisterMessage("BigWigs_SetConfigureTarget")
		self:RegisterMessage("BigWigs_Message")
		self:RegisterMessage("BigWigs_EmphasizedMessage")
		self:RegisterMessage("BigWigs_EmphasizedCountdownMessage")
		self:RegisterMessage("BigWigs_StartConfigureMode", showAnchors)
		self:RegisterMessage("BigWigs_StopConfigureMode", hideAnchors)
	end
end

function plugin:BigWigs_SetConfigureTarget(event, module)
	if module == self then
		normalAnchor.background:SetTexture(0.2, 1, 0.2, 0.3)
		emphasizeAnchor.background:SetTexture(0, 0, 0, 0.3)
		emphasizeCountdownAnchor.background:SetTexture(0, 0, 0, 0.3)
	elseif module == seModule then
		normalAnchor.background:SetTexture(0, 0, 0, 0.3)
		emphasizeAnchor.background:SetTexture(0.2, 1, 0.2, 0.3)
		emphasizeCountdownAnchor.background:SetTexture(0.2, 1, 0.2, 0.3)
	else
		normalAnchor.background:SetTexture(0, 0, 0, 0.3)
		emphasizeAnchor.background:SetTexture(0, 0, 0, 0.3)
		emphasizeCountdownAnchor.background:SetTexture(0, 0, 0, 0.3)
	end
end

do
	local updateMessageTimers = function(info, value)
		plugin.db.profile[info[#info]] = value
		for i = 1, 4 do
			local font = labels[i]
			if font then
				font.animFade:SetStartDelay(db.displaytime)
				font.icon.animFade:SetStartDelay(db.displaytime)
				font.animFade:SetDuration(db.fadetime)
				font.icon.animFade:SetStartDelay(db.displaytime)
			end
		end
	end
	local pluginOptions = nil
	function plugin:GetPluginConfig()
		if not pluginOptions then
			pluginOptions = {
				type = "group",
				get = function(info) return plugin.db.profile[info[#info]] end,
				set = function(info, value) plugin.db.profile[info[#info]] = value end,
				args = {
					font = {
						type = "select",
						name = L["Font"],
						order = 1,
						values = media:List("font"),
						--width = "half",
						--itemControl = "DDI-Font",
						get = function()
							for i, v in next, media:List("font") do
								if v == plugin.db.profile.font then return i end
							end
						end,
						set = function(info, value)
							local list = media:List("font")
							plugin.db.profile.font = list[value]
						end,
					},
					outline = {
						type = "select",
						name = L["Outline"],
						order = 2,
						values = {
							NONE = L["None"],
							OUTLINE = L["Thin"],
							THICKOUTLINE = L["Thick"],
						},
						--width = "half",
						get = function()
							return plugin.db.profile.outline or "NONE"
						end,
						set = function(info, value)
							if value == "NONE" then value = nil end
							plugin.db.profile[info[#info]] = value
						end,
					},
					fontSize = {
						type = "range",
						name = L["Font size"],
						order = 3,
						max = 40,
						min = 8,
						step = 1,
						width = "full",
					},
					usecolors = {
						type = "toggle",
						name = L["Use colors"],
						desc = L["Toggles white only messages ignoring coloring."],
						order = 5,
					},
					monochrome = {
						type = "toggle",
						name = L["Monochrome"],
						desc = L["Toggles the monochrome flag on all messages, removing any smoothing of the font edges."],
						order = 6,
					},
					classcolor = {
						type = "toggle",
						name = L["Class colors"],
						desc = L["Colors player names in messages by their class."],
						order = 7,
					},
					useicons = {
						type = "toggle",
						name = L["Use icons"],
						desc = L["Show icons next to messages, only works for Raid Warning."],
						order = 8,
					},
					newline1 = {
						type = "description",
						name = "\n",
						order = 9,
					},
					displaytime = {
						type = "range",
						name = L["Display time"],
						desc = L["How long to display a message, in seconds"],
						min=1,
						max=30,
						step=0.5,
						order=10,
						set = updateMessageTimers,
					},
					fadetime = {
						type = "range",
						name = L["Fade time"],
						desc = L["How long to fade out a message, in seconds"],
						min=1,
						max=30,
						step=0.5,
						order=11,
						set = updateMessageTimers,
					},
				},
			}
		end
		return pluginOptions
	end
end

-------------------------------------------------------------------------------
-- Event Handlers
--

do
	local scaleUpTime, scaleDownTime = 0.2, 0.4
	local function bounceAnimation(anim, elapsed)
		local self = anim:GetParent()
		self.elapsed = self.elapsed + elapsed
		local min = db.fontSize
		local max = min + 10
		if self.elapsed <= scaleUpTime then
			self:SetTextHeight(floor(min + ((max - min) * self.elapsed / scaleUpTime)))
		elseif self.elapsed <= scaleDownTime then
			self:SetTextHeight(floor(max - ((max - min) * (self.elapsed - scaleUpTime) / (scaleDownTime - scaleUpTime))))
		else
			self:SetTextHeight(min)
			anim:SetScript("OnUpdate", nil)
		end
	end

	local function getNextSlot()
		-- move 4 -> 1
		local old = labels[4]
		labels[4] = labels[3]
		labels[3] = labels[2]
		labels[2] = labels[1]
		labels[1] = old
		-- reposition
		for i = 1, 4 do
			if i == 1 then
				labels[i]:SetPoint("TOP")
			else
				labels[i]:SetPoint("TOP", labels[i - 1], "BOTTOM")
			end
		end
		-- new message at 1
		return labels[1]
	end

	function plugin:Print(addon, text, r, g, b, font, size, _, _, _, icon)
		BWMessageFrame:SetScale(db.scale or 1)
		BWMessageFrame:Show()

		local slot = getNextSlot()

		local flags = nil
		if db.monochrome and db.outline then
			flags = "MONOCHROME," .. db.outline
		elseif db.monochrome then
			flags = nil -- "MONOCHROME", XXX monochrome only is disabled for now as it causes a client crash
		elseif db.outline then
			flags = db.outline
		end
		slot:SetFont(media:Fetch("font", db.font), db.fontSize, flags)

		slot:SetText(text)
		slot:SetTextColor(r, g, b, 1)
		slot:SetHeight(slot:GetStringHeight())

		if icon then
			local h = slot:GetHeight()
			slot.icon:SetWidth(h)
			slot.icon:SetHeight(h)
			slot.icon:SetTexture(icon)
			slot.icon.anim:Stop()
			slot.icon:Show()
			slot.icon.anim:Play()
		else
			slot.icon:Hide()
		end
		slot.anim:Stop()
		slot:SetAlpha(1)
		slot.icon:SetAlpha(1)
		slot.elapsed = 0
		slot.anim:SetScript("OnUpdate", bounceAnimation)
		slot:Show()
		slot.anim:Play()
	end
end

do
	local emphasizedText, updater, frame = nil, nil, nil
	function plugin:EmphasizedPrint(addon, text, r, g, b, font, size, _, _, _, icon)
		if not updater then
			frame = CreateFrame("Frame", "BWEmphasizeMessageFrame", UIParent)
			frame:SetFrameStrata("HIGH")
			frame:SetPoint("TOP", emphasizeAnchor, "BOTTOM")
			frame:SetWidth(UIParent:GetWidth())
			frame:SetHeight(80)

			emphasizedText = frame:CreateFontString(nil, "OVERLAY", "ZoneTextFont")
			emphasizedText:SetPoint("TOP")

			updater = frame:CreateAnimationGroup()
			updater:SetScript("OnFinished", function() frame:Hide() end)

			local anim = updater:CreateAnimation("Alpha")
			anim:SetChange(-1)
			anim:SetDuration(3.5)
			anim:SetStartDelay(1.5)
		end
		emphasizedText:SetFont(media:Fetch("font", seModule.db.profile.font), seModule.db.profile.fontSize, seModule.db.profile.outline)
		emphasizedText:SetText(text)
		emphasizedText:SetTextColor(r, g, b)
		updater:Stop()
		frame:Show()
		updater:Play()
	end
	function plugin:BigWigs_EmphasizedMessage(event, ...)
		fakeEmphasizeMessageAddon:Pour(...)
	end
end

do
	local emphasizedCountdownText, updater, frame = nil, nil, nil
	function plugin:EmphasizedCountdownPrint(text)
		if not updater then
			if seModule.anchorEmphasizedCountdownText then seModule.anchorEmphasizedCountdownText:Hide() end
			frame = CreateFrame("Frame", "BWEmphasizeCountdownMessageFrame", UIParent)
			frame:SetFrameStrata("HIGH")
			frame:SetPoint("CENTER", emphasizeCountdownAnchor, "CENTER")
			frame:SetWidth(80)
			frame:SetHeight(80)

			emphasizedCountdownText = frame:CreateFontString(nil, "OVERLAY")
			emphasizedCountdownText:SetPoint("CENTER")

			updater = frame:CreateAnimationGroup()
			updater:SetScript("OnFinished", function() frame:Hide() end)

			local anim = updater:CreateAnimation("Alpha")
			anim:SetChange(-1)
			anim:SetDuration(3.5)
			anim:SetStartDelay(1.5)
		end
		emphasizedCountdownText:SetFont(media:Fetch("font", seModule.db.profile.font), seModule.db.profile.fontSize, seModule.db.profile.outline)
		emphasizedCountdownText:SetText(text)
		emphasizedCountdownText:SetTextColor(seModule.db.profile.fontColor.r, seModule.db.profile.fontColor.g, seModule.db.profile.fontColor.b)
		updater:Stop()
		frame:Show()
		updater:Play()
	end
	function plugin:BigWigs_EmphasizedCountdownMessage(event, ...)
		plugin:EmphasizedCountdownPrint(...)
	end
end

function plugin:BigWigs_Message(event, module, key, text, color, sound, icon)
	if not text then return end

	local r, g, b = 1, 1, 1 -- Default to white.
	if db.usecolors then
		if type(color) == "table" then
			if color.r and color.g and color.b then
				r, g, b = color.r, color.g, color.b
			else
				r, g, b = unpack(color)
			end
		elseif colorModule then
			r, g, b = colorModule:GetColor(color, module, key)
		end
	end

	if not db.useicons then icon = nil end

	if seModule and module and key and seModule:IsSuperEmphasized(module, key) then
		if seModule.db.profile.upper then
			text = text:upper()
		end
		fakeEmphasizeMessageAddon:Pour(text, r, g, b)
	else
		self:Pour(text, r, g, b, nil, nil, nil, nil, nil, icon)
	end
	if db.chat then
		-- http://www.wowpedia.org/UI_escape_sequences
		-- |TTexturePath:size1:size2:xoffset:yoffset:dimx:dimy:coordx1:coordx2:coordy1:coordy2:red:green:blue|t
		if icon then text = "|T"..icon..":15:15:0:0:64:64:4:60:4:60|t"..text end
		ChatFrame1:AddMessage(text, r, g, b)
	end
end

