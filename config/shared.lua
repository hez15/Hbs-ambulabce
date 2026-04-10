return {
    checkInCost = 2000, -- Price for using the hospital check-in system
    minForCheckIn = 2, -- Minimum number of people with the ambulance job to prevent the check-in system from being used

    locations = { -- Various interaction points
        duty = {
            vec3(311.18, -599.25, 43.29),
            vec3(-254.88, 6324.5, 32.58),
        },
        vehicle = {
            vec4(294.578, -574.761, 43.179, 35.79),
            vec4(-234.28, 6329.16, 32.15, 222.5),
        },
        helicopter = {
            vec4(351.58, -587.45, 74.16, 160.5),
            vec4(-475.43, 5988.353, 31.716, 31.34),
        },
        armory = {
            {
                shopType = 'AmbulanceArmory',
                name = 'Armory',
                groups = { ambulance = 0 },
                inventory = {
                    { name = 'radio', price = 0 },
                    { name = 'bandage', price = 0 },
                    { name = 'painkiller', price = 0 },
                    { name = 'firstaidkit', price = 0 },
                    { name = 'defibrillator', price = 0 },
                    { name = 'weapon_flashlight', price = 0 },
                    { name = 'weapon_fireextinguisher', price = 0 },
                },
                -- vec4: x/y/z = position, w = box zone rotation (heading)
                locations = {
                    vec4(309.93, -602.94, 43.29, -20.0),
                    vec4(-685.6753, 337.4242, 83.0837, 83.6309),
                }
            }
        },
        roof = {
            vec3(338.54, -583.88, 74.17),
        },
        main = {
            vec3(298.62, -599.66, 43.29),
        },
        stash = {
            {
                name = 'ambulanceStash',
                label = 'Personal stash',
                weight = 100000,
                slots = 30,
                groups = { ambulance = 0 },
                owner = true, -- Set to false for group stash
                location = vec3(309.78, -596.6, 43.29)
            }
        },

        ---@class Bed
        ---@field coords vector4
        ---@field model number

        ---@type table<string, {coords: vector3, checkIn?: vector3|vector4|vector3[]|vector4[], checkInPed?: string, beds: Bed[]}>
        hospitals = {
            hbs = {
                coords = vec3(-665.0, 350.0, 83.0),
                -- vec4 w = ped heading; checkInPed triggers ped spawn instead of box zone
                checkIn = vec4(-675.2578, 330.7374, 83.0837, 173.0383),
                checkInPed = 's_f_y_nurse_01',
                beds = {
                    {coords = vec4(-662.2059, 359.8203, 83.7536, 171.3869), model = 2117668672},
                    {coords = vec4(-659.2564, 359.3978, 83.7469, 178.9528), model = 2117668672},
                    {coords = vec4(-656.0694, 359.2540, 83.7525, 173.0717), model = 2117668672},
                    {coords = vec4(-653.0889, 359.1118, 83.7573, 169.2547), model = 2117668672},
                },
            },
            pillbox = {
                coords = vec3(350, -580, 43),
                checkIn = vec3(308.19, -595.35, 43.29),
                beds = {
                    {coords = vec4(353.1, -584.6, 43.11, 152.08), model = 1631638868},
                    {coords = vec4(356.79, -585.86, 43.11, 152.08), model = 1631638868},
                    {coords = vec4(354.12, -593.12, 43.1, 336.32), model = 2117668672},
                    {coords = vec4(350.79, -591.8, 43.1, 336.32), model = 2117668672},
                    {coords = vec4(346.99, -590.48, 43.1, 336.32), model = 2117668672},
                    {coords = vec4(360.32, -587.19, 43.02, 152.08), model = -1091386327},
                    {coords = vec4(349.82, -583.33, 43.02, 152.08), model = -1091386327},
                    {coords = vec4(326.98, -576.17, 43.02, 152.08), model = -1091386327},
                },
            },
            paleto = {
                coords = vec3(-250, 6315, 32),
                checkIn = vec3(-254.54, 6331.78, 32.43),
                beds = {
                    {coords = vec4(-252.43, 6312.25, 32.34, 313.48), model = 2117668672},
                    {coords = vec4(-247.04, 6317.95, 32.34, 134.64), model = 2117668672},
                    {coords = vec4(-255.98, 6315.67, 32.34, 313.91), model = 2117668672},
                },
            },
            jail = {
                coords = vec3(1761, 2600, 46),
                beds = {
                    {coords = vec4(1761.96, 2597.74, 45.66, 270.14), model = 2117668672},
                    {coords = vec4(1761.96, 2591.51, 45.66, 269.8), model = 2117668672},
                    {coords = vec4(1771.8, 2598.02, 45.66, 89.05), model = 2117668672},
                    {coords = vec4(1771.85, 2591.85, 45.66, 91.51), model = 2117668672},
                },
            },
        },

        stations = {
            {label = 'HBS Ambulance', coords = vec4(-676.0957, 325.7325, 83.0838, 0.0)},
        }
    },
}