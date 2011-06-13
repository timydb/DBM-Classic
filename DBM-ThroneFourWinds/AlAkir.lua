local mod	= DBM:NewMod("AlAkir", "DBM-ThroneFourWinds")
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision$"):sub(12, -3))
mod:SetCreatureID(46753)
mod:SetModelID(35248)
mod:SetZone()
mod:SetUsedIcons(8)

mod:RegisterCombat("combat")

mod:RegisterEvents(
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"SPELL_AURA_REMOVED",
	"SPELL_CAST_START",
	"SPELL_DAMAGE",
	"SPELL_MISSED",
	"SPELL_PERIODIC_DAMAGE",
	"CHAT_MSG_MONSTER_YELL"
)

local isDeathKnight = select(2, UnitClass("player")) == "DEATHKNIGHT"

local warnWindBurst			= mod:NewSpellAnnounce(87770, 3)
local warnAdd				= mod:NewAnnounce("WarnAdd", 2, 87856)
local warnPhase2			= mod:NewPhaseAnnounce(2)
local warnAcidRain			= mod:NewCountAnnounce(93281, 2, nil, false)
local warnFeedback			= mod:NewStackAnnounce(87904, 2)
local warnPhase3			= mod:NewPhaseAnnounce(3)
local warnCloud				= mod:NewSpellAnnounce(89588, 3)
local warnLightingRod		= mod:NewTargetAnnounce(89668, 4)

local specWarnWindBurst		= mod:NewSpecialWarningSpell(87770, nil, nil, nil, true)
local specWarnIceStorm		= mod:NewSpecialWarningMove(91020)
local specWarnCloud			= mod:NewSpecialWarningMove(89588)
local specWarnLightningRod	= mod:NewSpecialWarningYou(89668)
local yellLightningRod		= mod:NewYell(89668)

local timerWindBurst		= mod:NewCastTimer(5, 87770)
local timerWindBurstCD		= mod:NewCDTimer(25, 87770)		-- 25-30 Variation
local timerAddCD			= mod:NewTimer(20, "TimerAddCD", 87856)
local timerFeedback			= mod:NewTimer(20, "TimerFeedback", 87904)
local timerAcidRainStack	= mod:NewNextTimer(15, 93281, nil, isDeathKnight)
local timerLightningRod		= mod:NewTargetTimer(5, 89668)
local timerLightningRodCD	= mod:NewNextTimer(15, 89668)
local timerLightningCloudCD	= mod:NewNextTimer(15, 89588)
local timerLightningStrikeCD= mod:NewNextTimer(10, 93257)

local berserkTimer			= mod:NewBerserkTimer(600)

mod:AddBoolOption("LightningRodIcon")

local lastWindburst = 0
local phase2Started = false
local spamIce = 0
local spamCloud = 0
local spamStrike = 0
--local strikedest = {}

function mod:CloudRepeat()
	warnCloud:Show()
	if mod:IsDifficulty("heroic10", "heroic25") then
		timerLightningCloudCD:Start(10)
		self:ScheduleMethod(10, "CloudRepeat")
	else
		timerLightningCloudCD:Start()
		self:ScheduleMethod(15, "CloudRepeat")
	end
end

--local function ClearLightingStrikes()
--	table.wipe(strikedest)
--end

function mod:OnCombatStart(delay)
	timerWindBurstCD:Start(20-delay)
	lastWindburst = 0
	phase2Started = false
	spamIce = 0
	spamCloud = 0
	spamStrike = 0
	berserkTimer:Start(-delay)
	timerLightningStrikeCD:Start(-delay)
--	table.wipe(strikedest)
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(87904) then
		warnFeedback:Show(args.destName, args.amount or 1)
		timerFeedback:Cancel()--prevent multiple timers spawning with diff args.
		if tonumber((select(4, GetBuildInfo()))) >= 40200 then--since only one spell id in game at all, assume the nerf affects all modes for now until we find out if blizz added a new spellid for normal to be longer than heroic.
			timerFeedback:Start(30, args.amount or 1)
		else
			timerFeedback:Start(20, args.amount or 1)
		end
	elseif args:IsSpellID(88301, 93279, 93280, 93281) then--Acid Rain (phase 2 debuff)
		if tonumber((select(4, GetBuildInfo()))) >= 40200 and mod:IsDifficulty("normal10", "normal25") then
			timerAcidRainStack:Start(20)
		else
			timerAcidRainStack:Start()
		end
		if args.amount and args.amount > 1 and args:IsPlayer() then
			warnAcidRain:Show(args.amount)
		end
		if not phase2Started then
			phase2Started = true
			warnPhase2:Show()
			timerWindBurstCD:Cancel()
			timerLightningStrikeCD:Cancel()
		end
	elseif args:IsSpellID(89668) then
		warnLightingRod:Show(args.destName)
		timerLightningRod:Show(args.destName)
		timerLightningRodCD:Start()
		if args:IsPlayer() then
			specWarnLightningRod:Show()
			yellLightningRod:Yell()
		end
		if self.Options.LightningRodIcon then
			self:SetIcon(args.destName, 8)
		end
	end
end

mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(89668) then
		timerLightningRod:Cancel(args.destName)
		if self.Options.LightningRodIcon then
			self:SetIcon(args.destName, 0)
		end
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(87770, 93261, 93262, 93263) then--Phase 1 wind burst
		warnWindBurst:Show()
		specWarnWindBurst:Show()
		timerWindBurstCD:Start()
		if mod:IsDifficulty("heroic10", "heroic25") then
			timerWindBurst:Start(4)--4 second cast on heroic according to wowhead.
		else
			timerWindBurst:Start()
		end
	end
end

function mod:SPELL_DAMAGE(args)
	if args:IsSpellID(88858, 93286, 93287, 93288) and GetTime() - lastWindburst > 5 then--Phase 3 wind burst, does not use cast success :(
		warnWindBurst:Show()
		timerWindBurstCD:Start(20)
		lastWindburst = GetTime()
	elseif args:IsSpellID(89588, 93299, 93298, 93297) and GetTime() - spamCloud >= 4 and args:IsPlayer() then
		specWarnCloud:Show()
		spamCloud = GetTime()
--will try simple approach first before messing with filtering.
	elseif args:IsSpellID(88214, 93255, 93256, 93257) then--Lighting strike, only CLEU event for it is spell_damage or spell_miss :(
--		if not strikedest[args.destName] then--Lets check ignored names and filter them before we do anything.
--			strikedest[args.destName] = true--Lets add names to an ignore table for heroic mode, so they can be ignored for 15 seconds.
			if GetTime() - spamStrike > 9.5 then--Completely ignore damage for 9 seconds to anyone. Hopefully filter people who run into a strike from a diff section while it's going off.
				spamStrike = GetTime()
				timerLightningStrikeCD:Start()--Start 10 second timer for next lighthing strike.
--				self:Schedule(15, ClearLightingStrikes)--Schedule a table wipe when that 15 seconds as expired.
			end
--		end
	end
end

mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:SPELL_PERIODIC_DAMAGE(args)
	if args:IsSpellID(91020, 93258, 93259, 93260) and GetTime() - spamIce >= 4 and args:IsPlayer() then
		specWarnIceStorm:Show()
		spamIce = GetTime()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.summonSquall or msg:find(L.summonSquall) then--Adds being summoned
		warnAdd:Show()
		timerAddCD:Start()
	elseif msg == L.phase3 or msg:find(L.phase3) then
		warnPhase3:Show()
		timerLightningCloudCD:Start(15.5)
		self:ScheduleMethod(15.5, "CloudRepeat")
		timerWindBurstCD:Start(25)
		timerLightningRodCD:Start(20)
		timerAddCD:Cancel()
		timerAcidRainStack:Cancel()
	end
end