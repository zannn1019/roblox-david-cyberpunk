local skipModules = {
	["WeaponModule"] = true
}
for _, v in game.ReplicatedStorage.Resources.Modules.Client:GetChildren() do
	if v:IsA("ModuleScript") then
		if skipModules[v.Name] then
			continue
		end
		local success, result = pcall(require, v)
		if not success then
			error(string.format("\n[Loader Error] Failed to require module: '%s'\n Reason: %s", v.Name, tostring(result)), 2)
		end
		if type(result) == "table" and type(result.Init) == "function" then
			result:Init()
		else
			warn(string.format("Module '%s' loaded perfectly, but it doesn't have an :Init() function!", v.Name))
		end
	end
end