-- HBS Crafting — server-side validation and item dispensing

RegisterNetEvent('hbs_ambulance:server:craftItem', function(recipeId)
    local src = source
    if not HBSUtils.IsEMS(src) then return end

    local recipe = HBSConfig.Crafting[recipeId]
    if not recipe then
        TriggerClientEvent('hbs_ambulance:client:craftResult', src, false, nil, 'Unknown recipe.')
        return
    end

    -- Tier check
    local cid  = HBSUtils.GetCitizenId(src)
    local data = cid and DB.LoadEMSResearch(cid) or { tier = 1 }
    if data.tier < recipe.tier then
        TriggerClientEvent('hbs_ambulance:client:craftResult', src, false, nil,
            ('Requires Tier %d research.'):format(recipe.tier))
        return
    end

    -- Ingredient check (all-or-nothing before removing anything)
    for _, ing in ipairs(recipe.ingredients) do
        local count = exports.ox_inventory:GetItemCount(src, ing.item)
        if count < ing.amount then
            TriggerClientEvent('hbs_ambulance:client:craftResult', src, false, nil,
                ('Missing: %s ×%d'):format(ing.item, ing.amount))
            return
        end
    end

    -- Remove ingredients
    for _, ing in ipairs(recipe.ingredients) do
        exports.ox_inventory:RemoveItem(src, ing.item, ing.amount)
    end

    -- Give output
    exports.ox_inventory:AddItem(src, recipe.output.item, recipe.output.amount)

    -- Award XP (half a treat reward per craft)
    AwardXP(src, math.floor(HBSConfig.EMSResearch.xpRewards.treat / 2))

    TriggerClientEvent('hbs_ambulance:client:craftResult', src, true, recipe.label)
end)
