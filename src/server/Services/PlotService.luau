-- Gives each player a base (plot), and answers "whose base is this / am I inside it?".
local PlotService = {}

local plots = {}
local plotByPlayer: { [Player]: any } = {}

local function teleportToPlot(character: Model, plot)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and plot.owner then
		character:PivotTo(plot.spawnCFrame)
	end
end

function PlotService.start(builtPlots)
	plots = builtPlots
end

function PlotService.playerAdded(player: Player)
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plotByPlayer[player] = plot
			plot.signLabel.Text = player.DisplayName .. "'s Base"
			-- Lets the player's device find its own base (workspace.GeneratedMap.Plot<n>).
			player:SetAttribute("PlotIndex", plot.index)

			player.CharacterAdded:Connect(function(character)
				teleportToPlot(character, plot)
			end)
			if player.Character then
				task.spawn(teleportToPlot, player.Character, plot)
			end
			return plot
		end
	end
	warn("[PlotService] No free plot for", player.Name, "- make Max Players match GameConfig.PlotCount")
	return nil
end

function PlotService.playerRemoving(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	plot.owner = nil
	plot.lockedUntil = 0
	plot.lockCooldownUntil = 0
	plot.signLabel.Text = "Empty Base"
end

function PlotService.getPlot(player: Player)
	return plotByPlayer[player]
end

function PlotService.isInside(plot, position: Vector3): boolean
	local localPosition = plot.cframe:PointToObjectSpace(position)
	local half = plot.size / 2
	return math.abs(localPosition.X) <= half
		and math.abs(localPosition.Z) <= half
		and localPosition.Y > -5
		and localPosition.Y < 30
end

function PlotService.isLocked(plot): boolean
	return os.clock() < plot.lockedUntil
end

return PlotService
