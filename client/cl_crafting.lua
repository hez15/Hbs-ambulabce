-- HBS Crafting — EMS research-gated medical item crafting

local isCrafting = false

-- ── Build ox_lib context menu options for current tier ────────────────────────

local function BuildCraftMenu()
    local myTier = HBSState.emsTier or 1
    local options = {}

    for recipeId, recipe in pairs(HBSConfig.Crafting) do
        local locked  = myTier < recipe.tier
        local tierCfg = HBSConfig.EMSResearch.tiers[recipe.tier]
        local tierLabel = tierCfg and tierCfg.label or ('Tier ' .. recipe.tier)

        -- Build ingredient description
        local ingList = {}
        for _, ing in ipairs(recipe.ingredients) do
            ingList[#ingList + 1] = ('  • %s x%d'):format(ing.item, ing.amount)
        end
        local desc = table.concat(ingList, '\n')
        if locked then
            desc = ('Requires %s\n'):format(tierLabel) .. desc
        end

        options[#options + 1] = {
            title    = ('%s  ×%d'):format(recipe.label, recipe.output.amount),
            description = desc,
            disabled = locked,
            onSelect = not locked and function()
                CraftItem(recipeId, recipe)
            end or nil,
            metadata = locked and { { label = 'Locked', value = tierLabel } } or nil,
        }
    end

    -- Sort: available first, then locked
    table.sort(options, function(a, b)
        if a.disabled == b.disabled then return a.title < b.title end
        return not a.disabled
    end)

    return options
end

-- ── Craft an item ─────────────────────────────────────────────────────────────

function CraftItem(recipeId, recipe)
    if isCrafting then
        HBSNotify('error', 'Already crafting.')
        return
    end
    isCrafting = true

    -- Build animation dict/clip from a generic crafting look
    local dict  = 'mini@crate_search@std@ps'
    local clip  = 'crate_search_ps_std'
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 30 do
        Wait(100); timeout = timeout + 1
    end

    local completed = lib.progressCircle({
        duration   = (recipe.craftTime or 15) * 1000,
        label      = ('Crafting: %s'):format(recipe.label),
        useWhileDead = false,
        canCancel  = true,
        disable    = { move = true, car = true, combat = true },
        anim       = { dict = dict, clip = clip, flag = 49 },
    })

    isCrafting = false

    if completed then
        TriggerServerEvent('hbs_ambulance:server:craftItem', recipeId)
    else
        HBSNotify('error', 'Crafting cancelled.')
    end
end

-- ── Open crafting menu ────────────────────────────────────────────────────────

local function OpenCraftingMenu()
    if not HBSIsEMS() then
        HBSNotify('error', 'EMS only.')
        return
    end

    local options = BuildCraftMenu()
    if #options == 0 then
        HBSNotify('error', 'No recipes available.')
        return
    end

    lib.registerContext({
        id      = 'hbs_crafting_menu',
        title   = 'Medical Crafting',
        options = options,
    })
    lib.showContext('hbs_crafting_menu')
end

-- ── Crafting table ox_target ──────────────────────────────────────────────────

CreateThread(function()
    -- Wait for world to load
    Wait(5000)
    if not HBSConfig.CraftingTable then return end

    exports.ox_target:addSphereZone({
        coords  = HBSConfig.CraftingTable.coords,
        radius  = HBSConfig.CraftingTable.radius,
        options = {
            {
                name   = 'hbs_craft',
                icon   = 'fa-solid fa-syringe',
                label  = HBSConfig.CraftingTable.label,
                onSelect = function()
                    CreateThread(OpenCraftingMenu)
                end,
            },
        },
    })
end)

-- ── Server response ───────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:craftResult', function(success, itemLabel, reason)
    if success then
        HBSNotify('success', ('Crafted: %s'):format(itemLabel))
    else
        HBSNotify('error', reason or 'Crafting failed.')
    end
end)

-- ── Research update — refresh tier so menu reflects new unlocks ───────────────

RegisterNetEvent('hbs_ambulance:client:emsResearchUpdate', function(data)
    HBSState.emsTier   = data.tier
    HBSState.emsXP     = data.xp
    HBSState.emsUnlocks = data.unlocks or {}
    TriggerEvent('hbs:client:hudUpdate')
end)
