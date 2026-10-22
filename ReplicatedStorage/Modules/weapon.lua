local Weapons = {}

Weapons.Melee = {}
Weapons.Ranged = {}
Weapons.Special = {}
Weapons.Other = {}

Weapons.list = {
	["Axe"] = {
		["Type"] = "Melee", -- this is so we can catagorize weapon
		["Damage"] = 12,
		["Cooldown"] = 2,
		["Cost"] = 0,
		["Description"] = "A basic Starter weapon",
	},
	["Lighter"] = {
		["Type"] = "Other",
		["Damage"] = 0,
		["Cooldown"] = 0.2,
		["Cost"] = 0,
		["Description"] = "A basic Lighter",
	},
	["Shovel"] = {
		["Type"] = "Melee",
		["Damage"] = 10,
		["Cooldown"] = 0.65,
		["Cost"] = 0,
		["Description"] = "A basic Shovel weapon",
	},
	
}

function Weapons:orgonizeWeapons()
	for weaponName, weaponData in pairs(Weapons.list) do
		local weaponType = weaponData.Type
		if weaponType == "Melee" then
			Weapons.Melee[weaponName] = weaponData
		elseif weaponType == "Ranged" then
			Weapons.Ranged[weaponName] = weaponData
		elseif weaponType == "Special" then
			Weapons.Special[weaponName] = weaponData
		elseif weaponType == "Other" then
			Weapons.Other[weaponName] = weaponData
		end
	end
end
Weapons:orgonizeWeapons() -- auto sort when initialized

function Weapons:getWeaponData(weaponName)
	return Weapons.list[weaponName]
end

function Weapons:getWeaponCost(weaponName)
	local weaponData = Weapons:getWeaponData(weaponName)
	if weaponData then
		return weaponData.Cost
	else
		return nil
	end
end




return Weapons

