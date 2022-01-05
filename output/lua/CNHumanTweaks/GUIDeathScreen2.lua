Script.Load("lua/GUI/GUIObject.lua")
Script.Load("lua/GUI/GUIText.lua")
Script.Load("lua/DeathMessage_Client.lua")
Script.Load("lua/menu2/PlayerScreen/GUIMenuSkillTierIcon.lua")

local kDEBUG_ALWAYSSHOW = false

local kBackgroundTexture = PrecacheAsset("ui/deathscreen/background.dds")

local kCallingCardSize = Vector(274, 274, 0)
local kFontName = "Agency"

local kCenterSectionWidth = 310
local kSectionPadding = 35 -- Padding between text and center section
local kDesiredShowTime = 5 -- Desired seconds to show the death screen. Can be skipped.
local kBackgroundFadeDelay = 0.45
local kSubtextColor = HexToColor("8aa5ad")

local kFadeAnimationName = "ANIM_FADE"

class 'GUIDeathScreen2' (GUIObject)

local function UpdateResolutionScaling(self, newX, newY)

    local mockupRes = Vector(1920, 1080, 0)
    local screenRes = Vector(newX, newY, 0)
    local scale = screenRes / mockupRes
    scale = math.min(scale.x, scale.y)

    self:SetSize(newX, newY)
    self.background:SetScale(scale, scale)

end

function GUIDeathScreen2:Initialize(params, errorDepth)
    errorDepth = (errorDepth or 1) + 1

    GUIObject.Initialize(self, params, errorDepth)

    self.fadingObjs = {}
    self.startTime = 0
    self.hiding = false

    self:SetSize(Client.GetScreenWidth(), Client.GetScreenHeight())
    self:SetLayer(kGUILayerDeathScreen)
    self:SetColor(0,0,0,0)

    self.background = CreateGUIObject("background", GUIObject, self)
    self.background:AlignCenter()
    self.background:SetTexture(kBackgroundTexture)
    self.background:SetSizeFromTexture()
    self.background:SetColor(1,1,1)
    table.insert(self.fadingObjs, self.background)

    self.callingCard = CreateGUIObject("callingCard", GUIObject, self.background)
    self.callingCard:SetSize(kCallingCardSize)
    self.callingCard:SetColor(1,1,1)
    self.callingCard:AlignTop()
    self.callingCard:SetY(22)
    table.insert(self.fadingObjs, self.callingCard)

    local sideWidth = math.floor((self.background:GetSize().x - (kCenterSectionWidth)) / 2)
    local startLeftFromRight = -sideWidth - kCenterSectionWidth - kSectionPadding
    local startRightFromLeft = sideWidth + kCenterSectionWidth + kSectionPadding

    self.killedByLabel = CreateGUIObject("killedByLabel", GUIText, self.background)
    self.killedByLabel:AlignRight()
    self.killedByLabel:SetFont(kFontName, 44)
    self.killedByLabel:SetText(Locale.ResolveString("DEATHSCREEN_LEFTLABEL_TOP"))
    self.killedByLabel:SetPosition(startLeftFromRight, 0)
    self.killedByLabel:SetColor(HexToColor("ff5757"))
    table.insert(self.fadingObjs, self.killedByLabel)

    self.killedByLabelPrefix = CreateGUIObject("killedByLabel", GUIText, self.background)
    self.killedByLabelPrefix:AlignRight()
    self.killedByLabelPrefix:SetFont(kFontName, 44)
    self.killedByLabelPrefix:SetText(string.format("%s%s", Locale.ResolveString("DEATHSCREEN_LEFTLABEL_TOP_PREFIX"), " "))
    self.killedByLabelPrefix:SetPosition(startLeftFromRight - self.killedByLabel:GetSize().x, 0)
    self.killedByLabelPrefix:SetColor(1,1,1)
    table.insert(self.fadingObjs, self.killedByLabelPrefix)

    self.killedByLabel2 = CreateGUIObject("killedByLabel2", GUIText, self.background)
    self.killedByLabel2:AlignRight()
    self.killedByLabel2:SetFont(kFontName, 24)
    self.killedByLabel2:SetText(Locale.ResolveString("DEATHSCREEN_LEFTLABEL_BOTTOM"))
    self.killedByLabel2:SetPosition(startLeftFromRight, 40)
    self.killedByLabel2:SetColor(kSubtextColor)
    table.insert(self.fadingObjs, self.killedByLabel2)

    self.killedWithLabel = CreateGUIObject("killedWithLabel", GUIText, self.background)
    self.killedWithLabel:AlignLeft()
    self.killedWithLabel:SetFont(kFontName, 24)
    self.killedWithLabel:SetText(Locale.ResolveString("DEATHSCREEN_RIGHTLABEL_TOP"))
    self.killedWithLabel:SetPosition(startRightFromLeft, -40)
    self.killedWithLabel:SetColor(kSubtextColor)
    table.insert(self.fadingObjs, self.killedWithLabel)

    self.killedWithLabel2 = CreateGUIObject("killedWithLabel2", GUIText, self.background)
    self.killedWithLabel2:AlignLeft()
    self.killedWithLabel2:SetFont(kFontName, 44)
    self.killedWithLabel2:SetPosition(startRightFromLeft, 0)
    self.killedWithLabel2:SetColor(1,1,1)
    table.insert(self.fadingObjs, self.killedWithLabel2)

    self.killerName = CreateGUIObject("killerName", GUIText, self.background) -- TODO(Salads): Change this to a truncated text? names can get pretty long..
    self.killerName:AlignTop()
    self.killerName:SetFont(kFontName, 44)
    self.killerName:SetPosition(self.callingCard:GetSize().y + 5, 0)
    self.killerName:SetColor(1,1,1)
    self.killerName:SetPosition(0, self.callingCard:GetSize().y + 5)
    table.insert(self.fadingObjs, self.killerName)

    self.weaponIcon = CreateGUIObject("weaponIcon", GUIObject, self.killedWithLabel2)
    self.weaponIcon:AlignLeft()
    self.weaponIcon:SetTexture(kInventoryIconsTexture)
    self.weaponIcon:SetColor(1,1,1)
    self.weaponIcon:SetSize(DeathMsgUI_GetTechWidth(), DeathMsgUI_GetTechHeight())
    self.weaponIcon:SetPosition(self.killedWithLabel2:GetSize().x, 0)
    table.insert(self.fadingObjs, self.weaponIcon)

    self.skillbadge = CreateGUIObject("skillbadge", GUIMenuSkillTierIcon, self.background)
    self.skillbadge:AlignTop()
    table.insert(self.fadingObjs, self.skillbadge:GetIconObject())
    self:HookEvent(GetGlobalEventDispatcher(), "OnResolutionChanged", UpdateResolutionScaling)
    UpdateResolutionScaling(self, Client.GetScreenWidth(), Client.GetScreenHeight())

    self:HookEvent(self, "OnAnimationFinished", self.OnAnimationFinished)

    self.lastIsDead = PlayerUI_GetIsDead()
    self:SetVisible(false or kDEBUG_ALWAYSSHOW)
    self:ShowContents(false or kDEBUG_ALWAYSSHOW, true)

    self:SetUpdates(not kDEBUG_ALWAYSSHOW)

end

function GUIDeathScreen2:OnAnimationFinished(animationName)
    self.hiding = false
    self:SetVisible(false)
end

function GUIDeathScreen2:ShowContents(show, instant)

    local opacityTarget = show and 1 or 0

    if instant then
        for i = 1, #self.fadingObjs do
            local obj = self.fadingObjs[i]
            obj:SetOpacity(opacityTarget)
        end
    else
        for i = 1, #self.fadingObjs do
            local obj = self.fadingObjs[i]
            obj:ClearPropertyAnimations("Opacity")
            obj:AnimateProperty("Opacity", opacityTarget, MenuAnimations.Fade)
        end

    end

end

function GUIDeathScreen2:RemoveCinematic()

    if self.cinematic then

        if IsValid(self.cinematic) then
            self.cinematic:SetIsVisible(false)
            Client.DestroyCinematic(self.cinematic)
        end
        self.cinematic = nil

    end

end

function GUIDeathScreen2:OnUpdate(deltaTime, _)

    local isDead = PlayerUI_GetIsDead()
    local isDeadChanged = isDead ~= self.lastIsDead
    local nowTime = Shared.GetSystemTimeReal()

    if isDeadChanged then

        -- Check for the killer name as it will be nil if it hasn't been received yet.
        if isDead then

            self.startTime = nowTime

            local player = Client.GetLocalPlayer()
            if player and not self.cinematic and not PlayerUI_GetIsSpecating() then
                self.cinematic = Client.CreateCinematic(RenderScene.Zone_ViewModel)
                self.cinematic:SetCinematic(FilterCinematicName(player:GetFirstPersonDeathEffect()))
            end

            local killerInfo = GetAndClearKillerInfo()

            if not killerInfo.Name then -- Killer name not set yet
                return
            end

            -- Now we have the info ready, we can finally start updating the UI
            self.killerName:SetText(killerInfo.Name) -- Always available

            local context = killerInfo.Context
            if context == kDeathSource.Player or context == kDeathSource.Structure then -- We have information about the player who killed us (Structure = Commander)

                -- All elements should be used here.
                local cardTextureDetails = GetCallingCardTextureDetails(killerInfo.CallingCard)
                self.callingCard:SetTexture(cardTextureDetails.texture)
                self.callingCard:SetTexturePixelCoordinates(cardTextureDetails.texCoords)
                self.callingCard:SetVisible(true)

                self.killerName:SetVisible(true)

                self.skillbadge:SetSteamID64(Shared.ConvertSteamId32To64(killerInfo.SteamId))
                self.skillbadge:SetIsRookie(killerInfo.IsRookie)
                self.skillbadge:SetSkill(killerInfo.Skill)
                self.skillbadge:SetAdagradSum(killerInfo.AdagradSum)
                self.skillbadge:SetIsBot(killerInfo.SteamId == 0)
                self.skillbadge:SetVisible(true)

                -- Right Side
                self.killedWithLabel2:SetText(EnumToString(kDeathMessageIcon, killerInfo.WeaponIconIndex))

                local xOffset = DeathMsgUI_GetTechOffsetX(0)
                local yOffset = DeathMsgUI_GetTechOffsetY(killerInfo.WeaponIconIndex)
                local iconWidth = DeathMsgUI_GetTechWidth(0)
                local iconHeight = DeathMsgUI_GetTechHeight(0)

                self.weaponIcon:SetPosition(self.killedWithLabel2:GetSize().x, 0)
                self.weaponIcon:SetTexturePixelCoordinates(xOffset, yOffset, xOffset + iconWidth, yOffset + iconHeight)

                local showRightSide = killerInfo.WeaponIconIndex ~= kDeathMessageIcon.None
                self.killedWithLabel:SetVisible(showRightSide)
                self.killedWithLabel2:SetVisible(showRightSide)
                self.weaponIcon:SetVisible(showRightSide)


            else -- Hiding skill badge, and right side (StructureNoCommander, DeathTrigger, KilledSelf), but everything else is visible.

                local cardTextureDetails = GetCallingCardTextureDetails(killerInfo.CallingCard)
                self.callingCard:SetTexture(cardTextureDetails.texture)
                self.callingCard:SetTexturePixelCoordinates(cardTextureDetails.texCoords)
                self.callingCard:SetVisible(true)

                self.killerName:SetVisible(true)
                self.skillbadge:SetVisible(false)

                -- Right Side
                local showRightSide = context == kDeathSource.KilledSelf and killerInfo.WeaponIconIndex ~= kDeathMessageIcon.None
                if showRightSide then

                    local xOffset = DeathMsgUI_GetTechOffsetX(0)
                    local yOffset = DeathMsgUI_GetTechOffsetY(killerInfo.WeaponIconIndex)
                    local iconWidth = DeathMsgUI_GetTechWidth(0)
                    local iconHeight = DeathMsgUI_GetTechHeight(0)

                    self.killedWithLabel:SetVisible(true)
                    self.killedWithLabel2:SetText(EnumToString(kDeathMessageIcon, killerInfo.WeaponIconIndex))
                    self.killedWithLabel2:SetVisible(true)
                    self.weaponIcon:SetPosition(self.killedWithLabel2:GetSize().x, 0)
                    self.weaponIcon:SetTexturePixelCoordinates(xOffset, yOffset, xOffset + iconWidth, yOffset + iconHeight)
                    self.weaponIcon:SetVisible(true)

                else

                    self.killedWithLabel:SetVisible(false)
                    self.killedWithLabel2:SetVisible(false)
                    self.weaponIcon:SetVisible(false)

                end

            end

            -- If the player does not have a calling card, move the killer name and it's badge to the center, height-wise
            -- Also make sure calling card is not visible.
            if killerInfo.CallingCard == kCallingCards.None then

                self.callingCard:SetVisible(false)
                self.killerName:SetY((self.background:GetSize().y / 2) - (self.killerName:GetSize().y / 2))
                self.skillbadge:SetY(self.killerName:GetPosition().y + self.killerName:GetSize().y)

            else -- We have a calling card to display, so make sure everything is in the proper place.

                self.callingCard:SetVisible(true) -- Just in case
                self.killerName:SetPosition(0, self.callingCard:GetSize().y + 5)

                local centerBorderSize = 22
                local spaceLeftY = self.background:GetSize().y - centerBorderSize - (self.killerName:GetSize().y + self.killerName:GetPosition().y) - self.skillbadge:GetSize().y
                local paddingY = spaceLeftY / 2
                self.skillbadge:SetY(self.killerName:GetSize().y + self.killerName:GetPosition().y + paddingY - 10)

            end

            self:SetVisible(true)

            self:ShowContents(true)

        else

            self:RemoveCinematic()

            self:ShowContents(false)
            -- self:ClearPropertyAnimations("Opacity")
            -- self:AnimateProperty("Opacity", 0, MenuAnimations.Fade, kFadeAnimationName)

        end

        self.lastIsDead = isDead

    elseif isDead then

        local timeSinceShow = nowTime - self.startTime
        if not self.hiding and timeSinceShow >= kDesiredShowTime then
            self.hiding = true
            self:ShowContents(false)
            -- self:ClearPropertyAnimations("Opacity")
            -- self:AnimateProperty("Opacity", 0, MenuAnimations.Fade, kFadeAnimationName)
            self:RemoveCinematic()
        end

    end

end
