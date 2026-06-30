local skipModules = {
	["WeaponModule"] = true
}
for _, v in game.ReplicatedStorage.Resources.Modules.Client:GetChildren() do
	if v:IsA("ModuleScript") then
		if skipModules[v.Name] then
			continue
		end
		local module = require(v)
		module:Init()
	end
end