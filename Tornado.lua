local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local animateScript = character:FindFirstChild("Animate")
	if animateScript then
		animateScript.Disabled = true
	end

	local myAnimation = Instance.new("Animation")
	--這裡放動畫id--
	myAnimation.AnimationId = "rbxassetid://135373056067761"
	--
	local myTrack = animator:LoadAnimation(myAnimation)
	myTrack.Priority = Enum.AnimationPriority.Action4
	myTrack.Looped = true
	local function forcePlay()
		for _, track in pairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0)
		end
		myTrack:Play()
	end

	task.defer(function()
		forcePlay()
	end)

	animator.AnimationPlayed:Connect(function(track)
		if track.Animation.AnimationId ~= myAnimation.AnimationId then
			track:Stop(0)
			if not myTrack.IsPlaying then
				myTrack:Play()
			end
		end
	end)

	humanoid.StateChanged:Connect(function()
		if not myTrack.IsPlaying and humanoid.Health > 0 then
			myTrack:Play()
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)

if player.Character then
	onCharacterAdded(player.Character)
end