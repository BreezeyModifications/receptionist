local receptionists = {}
local playerCooldown = 0

-- Load Model
local function LoadModel(model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end
    return hash
end

-- Apply EUP (props + components format)
local function ApplyEUP(ped, eup)
    if not eup then return end

    -- Components
    if eup.components then
        for _, comp in ipairs(eup.components) do
            local componentId = comp[1]
            local drawable = comp[2]
            local texture = comp[3]
            SetPedComponentVariation(ped, componentId, drawable, texture, 0)
        end
    end

    -- Props (Hats, Glasses, etc.)
    if eup.props then
        for _, prop in ipairs(eup.props) do
            local propId = prop[1]
            local drawable = prop[2]
            local texture = prop[3]

            if drawable == -1 then
                ClearPedProp(ped, propId)
            else
                SetPedPropIndex(ped, propId, drawable, texture, true)
            end
        end
    end
end

-- Styled Chat Message (Bold + Dark Green Tag + White Text)
local function SendReceptionistChat(deskName)
    TriggerEvent('chat:addMessage', {
        template = '<div style="font-weight:bold; color:#FFFFFF;"><span style="color:#1f7a1f;">[RECEPTIONIST]</span> Somebody is at ' .. deskName .. ' requesting assistance.</div>',
        args = {}
    })
end

-- GTA Help Notification (Top Left Black Box)
local function ShowHelpNotification(msg)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- GTA Feed Notification
local function ShowNotification(msg)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end

-- Spawn Receptionists
CreateThread(function()
    for _, data in pairs(Config.Receptionists) do
        local modelHash = LoadModel(data.Model)

        local ped = CreatePed(
            4,
            modelHash,
            data.Coords.x,
            data.Coords.y,
            data.Coords.z - 1.0,
            data.Coords.w,
            false,
            true
        )

        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)

        -- Apply EUP Outfit
        ApplyEUP(ped, data.EUP)

        -- Clipboard Animation (Receptionist Style)
        RequestAnimDict("amb@world_human_clipboard@male@idle_a")
        while not HasAnimDictLoaded("amb@world_human_clipboard@male@idle_a") do
            Wait(0)
        end
        TaskPlayAnim(
            ped,
            "amb@world_human_clipboard@male@idle_a",
            "idle_c",
            8.0,
            0.0,
            -1,
            1,
            0,
            false,
            false,
            false
        )

        table.insert(receptionists, {
            ped = ped,
            deskName = data.DeskName,
            coords = vector3(data.Coords.x, data.Coords.y, data.Coords.z)
        })
    end
end)

-- Main Interaction Loop
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local currentTime = GetGameTimer()

        for _, receptionist in pairs(receptionists) do
            local distance = #(playerCoords - receptionist.coords)

            if distance < Config.InteractionDistance then
                sleep = 0
                ShowHelpNotification("Press ~INPUT_CONTEXT~ to request assistance")

                if IsControlJustPressed(0, 38) then -- E Key
                    if currentTime >= playerCooldown then

                        -- Send properly styled chat message
                        SendReceptionistChat(receptionist.deskName)

                        -- Start 10 minute cooldown
                        playerCooldown = currentTime + (Config.Cooldown * 1000)

                        -- 15 second confirmation notification
                        ShowNotification("A request for assistance has been sent. Please wait for a member of our team to greet you.")
                    else
                        local remaining = math.ceil((playerCooldown - currentTime) / 1000)
                        ShowNotification("You must wait " .. remaining .. " seconds before requesting assistance again.")
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
