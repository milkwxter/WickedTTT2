if SERVER then
  AddCSLuaFile()

  resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_wck.vmt")
end

function ROLE:PreInitialize()
  self.color = Color(255, 115, 1, 255)

  self.abbr = "wck" -- abbreviation
  self.surviveBonus = 0.5 -- bonus multiplier for every survive while another player was killed
  self.scoreKillsMultiplier = 5 -- multiplier for kill of player of another team
  self.scoreTeamKillsMultiplier = -16 -- multiplier for teamkill
  self.preventFindCredits = false
  self.preventKillCredits = false
  self.preventTraitorAloneCredits = false
  
  self.isOmniscientRole = true

  self.defaultEquipment = SPECIAL_EQUIPMENT -- here you can set up your own default equipment
  self.defaultTeam = TEAM_TRAITOR

  self.conVarData = {
    pct = 0.17, -- necessary: percentage of getting this role selected (per player)
    maximum = 1, -- maximum amount of roles in a round
    minPlayers = 6, -- minimum amount of players until this role is able to get selected
    credits = 1, -- the starting credits of a specific role
    togglable = true, -- option to toggle a role for a client if possible (F1 menu)
    random = 50,
    traitorButton = 1, -- can use traitor buttons
    shopFallback = SHOP_FALLBACK_TRAITOR
  }
end

-- now link this subrole with its baserole
function ROLE:Initialize()
  roles.SetBaseRole(self, ROLE_TRAITOR)
end

local cachedTable = nil

if SERVER then
	util.AddNetworkString("TTT2WCKSpecialRole")

	local ttt2_wck_visible = CreateConVar("ttt2_wck_visible", "100", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Sets the percentage of visible player's roles")

	hook.Add("TTT2SpecialRoleSyncing", "WCKRoleFilter", function(ply)
		if not cachedTable then return end

		local plys = (IsValid(ply) and ply:IsPlayer() and ply:GetSubRole() == ROLE_WICKED) and {ply} or GetSubRoleFilter(ROLE_WICKED)

		for _, v in ipairs(plys) do
			net.Start("TTT2WCKSpecialRole")
			net.WriteUInt(#cachedTable, 8)

			for _, eidx in ipairs(cachedTable) do
				net.WriteUInt(eidx, 16) -- 16 bits
			end

			net.Send(v)
		end
	end)

	hook.Add("TTTEndRound", "TTT2WCKEndRound", function()
		cachedTable = nil
	end)

	hook.Add("TTTBeginRound", "TTT2WCKBeginRound", function()
		local plys = GetSubRoleFilter(ROLE_WICKED)
		local tmp = {}

		for _, v in ipairs(player.GetAll()) do
			if not v:IsActive() or not v:IsTerror() then continue end

			local subrole = v:GetSubRole()

			if subrole ~= ROLE_INNOCENT and v:GetTeam() ~= TEAM_TRAITOR and v:GetBaseRole() ~= ROLE_DETECTIVE and not table.HasValue(plys, v) then
				tmp[#tmp + 1] = v:EntIndex()
			end
		end

		local tmp2 = tmp

		local wckrand = ttt2_wck_visible:GetInt()
		if wckrand < 100 then
			-- now calculate amount of visible roles
			local tmpCount = #tmp
			local activeAmount = math.min(math.ceil(tmpCount * (wckrand * 0.01)), tmpCount)

			-- now randomize the new list
			if tmpCount ~= activeAmount then
				tmp2 = {}

				for i = 1, activeAmount do
					local val = math.random(1, #tmp)

					tmp2[i] = tmp[val]

					table.remove(tmp, val)
				end
			end
		end

		cachedTable = tmp2
	end)
end

if CLIENT then
	function ROLE:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "header_roles_additional")

		form:MakeSlider({
			serverConvar = "ttt2_wck_visible",
			label = "label_wck_visible",
			min = 1,
			max = 100,
			decimal = 0
		})
	end

	hook.Add("TTTScoreboardRowColorForPlayer", "TTT2WCKColoredScoreboard", function(ply)
		local client = LocalPlayer()

		if client:GetSubRole() == ROLE_WICKED
		and ply ~= client
		and not ply:GetForceSpec()
		and ply.wck_specialRole
		and not ply:IsSpecial()
		then
			return Color(255, 115, 1, 100)
		end
	end)

	net.Receive("TTT2WCKSpecialRole", function()
		-- reset
		for _, v in ipairs(player.GetAll()) do
			v.wck_specialRole = nil
		end

		local amount = net.ReadUInt(8)
		local rs = GetRoundState()

		if amount > 0 then
			for i = 1, amount do
				local ply = Entity(net.ReadUInt(16))

				if rs == ROUND_ACTIVE and IsValid(ply) and ply:IsPlayer() then
					ply.wck_specialRole = true
				end
			end
		end
	end)

	hook.Add("TTTEndRound", "TTT2WCKEndRound", function()
		for _, v in ipairs(player.GetAll()) do
			v.wck_specialRole = nil
		end
	end)
end
