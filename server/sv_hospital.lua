-- Hospital: NPC heal, bill payment, rehab

-- ── NPC / bed heal ────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:hospitalHeal', function()
    local src = source
    local cid = Utils.GetCitizenId(src)
    if not cid then return end

    DB.ClearInjuries(cid)
    DB.SaveStress(cid, 0)
    DB.AddBill(cid, Config.NpcHealCost, 'Hospital Treatment')

    SB.Set(src, 'injuries', {})
    SB.Set(src, 'stress',   0)

    -- Remove downed state if applicable
    if DownedPlayers[src] then
        DownedPlayers[src] = nil
        SB.Set(src, 'isDowned', false)
        TriggerEvent('hbs_ambulance:server:broadcastDownedBlips')
    end

    TriggerClientEvent('hbs_ambulance:client:hospitalHealed', src)
    TriggerClientEvent('hbs_ambulance:client:billSent', src, Config.NpcHealCost)
end)

-- ── Pay all outstanding bills ─────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:payBills', function()
    local src    = source
    local cid    = Utils.GetCitizenId(src)
    local Player = exports.qbx_core:GetPlayer(src)
    if not cid or not Player then return end

    local bills = DB.GetUnpaidBills(cid)
    if not bills or #bills == 0 then
        TriggerClientEvent('hbs_ambulance:client:notify', src, {
            msg = Locale('hospital_bill_none'), type = 'inform'
        })
        return
    end

    local total = 0
    for _, bill in ipairs(bills) do total = total + bill.amount end

    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0

    if cash + bank < total then
        TriggerClientEvent('hbs_ambulance:client:notify', src, {
            msg = Locale('hospital_bill_no_funds', total), type = 'error'
        })
        return
    end

    -- Deduct: bank first, then cash
    local remaining = total
    if bank >= remaining then
        Player.Functions.RemoveMoney('bank', remaining, 'hospital-bill')
        remaining = 0
    else
        Player.Functions.RemoveMoney('bank', bank, 'hospital-bill')
        remaining = remaining - bank
        Player.Functions.RemoveMoney('cash', remaining, 'hospital-bill')
    end

    for _, bill in ipairs(bills) do
        DB.MarkBillPaid(bill.id)
    end

    TriggerClientEvent('hbs_ambulance:client:notify', src, {
        msg = Locale('hospital_bill_paid', total), type = 'success'
    })
end)

-- ── Start rehab ───────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:startRehab', function()
    local src    = source
    local cid    = Utils.GetCitizenId(src)
    local Player = exports.qbx_core:GetPlayer(src)
    if not cid or not Player then return end

    local cost = Config.Addiction.treatment.cost
    local cash  = Player.PlayerData.money.cash or 0
    local bank  = Player.PlayerData.money.bank or 0

    if cash + bank < cost then
        TriggerClientEvent('hbs_ambulance:client:notify', src, {
            msg = Locale('hospital_bill_no_funds', cost), type = 'error'
        })
        return
    end

    -- Deduct cost
    if bank >= cost then
        Player.Functions.RemoveMoney('bank', cost, 'rehab')
    else
        Player.Functions.RemoveMoney('bank', bank, 'rehab')
        Player.Functions.RemoveMoney('cash', cost - bank, 'rehab')
    end

    -- Tell client to start rehab progress bar (very long)
    TriggerClientEvent('hbs_ambulance:client:startRehabProgress', src)
end)

-- ── Complete rehab ────────────────────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:server:completeRehab', function()
    local src = source
    local cid = Utils.GetCitizenId(src)
    if not cid then return end

    local addictions = DB.LoadAddiction(cid)
    local reduceTo   = Config.Addiction.treatment.reduceTo
    local newLevels  = {}

    for sub, data in pairs(addictions) do
        if data.level > reduceTo then
            DB.UpdateAddictionLevel(cid, sub, reduceTo)
            newLevels[sub] = reduceTo
            TriggerClientEvent('hbs_ambulance:client:addictionUpdated', src, sub, reduceTo)
        else
            newLevels[sub] = data.level
        end
    end

    SB.Set(src, 'addiction', newLevels)
    TriggerClientEvent('hbs_ambulance:client:notify', src, {
        msg = Locale('hospital_rehab_done'), type = 'success'
    })
end)

-- ── Generic client notify handler ────────────────────────────────────────

RegisterNetEvent('hbs_ambulance:client:notify', function(data)
    -- This is a dummy — client handles this via RegisterNetEvent on client side
end)
