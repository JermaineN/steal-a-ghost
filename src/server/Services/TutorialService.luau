-- The first-time tutorial (client Tutorial walks new players through buying a ghost, collecting
-- its cash and locking their base). The server only decides who gets it (the "TutorialDone"
-- attribute, set when their data loads) and pays the reward when it's finished.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)

local TutorialService = {}

-- Called once the player's data has loaded.
function TutorialService.playerLoaded(player: Player)
	local done = DataService.isTutorialDone(player)
	if done then
		DataService.setTutorialDone(player)
	end
	player:SetAttribute("TutorialDone", done)
end

local function complete(player: Player)
	-- Once per player, and only after they've actually bought a ghost.
	if player:GetAttribute("TutorialDone") ~= false or next(DataService.getGhosts(player)) == nil then
		return
	end
	DataService.setTutorialDone(player)
	player:SetAttribute("TutorialDone", true)
	DataService.addGems(player, GameConfig.TutorialGems)
	Notify.send(player, `Tutorial complete! +{GameConfig.TutorialGems} gems`, "success")
end

function TutorialService.start()
	Remotes.TutorialComplete.OnServerEvent:Connect(complete)
end

return TutorialService
