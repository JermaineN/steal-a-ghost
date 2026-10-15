-- Network events between server and client.
-- The server creates them; clients wait for them to exist.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	"Notify", -- server -> client: show a message toast (message, kind)
	"CashCollected", -- server -> the pad's owner only: they collected a collect pad (pad)
	"RareSpawn", -- server -> all clients: a Legendary/Mythic ghost spawned (ghostId)
}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENT_NAMES do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in EVENT_NAMES do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
