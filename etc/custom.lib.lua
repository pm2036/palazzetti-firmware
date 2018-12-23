#!/usr/bin/lua

function getStoveTypeStr(iStoveType)
	if (iStoveType==0) then return "STOVETYPE_UNKNOWN" end

	if (iStoveType==1) then return "STOVETYPE_AIR" end

	if (iStoveType==2) then return "STOVETYPE_WATER" end

	if (iStoveType==3) then return "STOVETYPE_MULTIFIRE_AIR" end

	if (iStoveType==4) then return "STOVETYPE_MULTIFIRE_IDRO" end

	if (iStoveType==5) then return "STOVETYPE_KITCHEN_AIR" end

	if (iStoveType==6) then return "STOVETYPE_KITCHEN_IDRO" end

end

function getFAN2TypeStr(iFAN2Type)
	if (iFAN2Type==0) then return "FAN2TYPE_UNKNOWN" end

	if (iFAN2Type==1) then return "FAN2TYPE_NOFAN" end

	if (iFAN2Type==2) then return "FAN2TYPE_1FAN" end

	if (iFAN2Type==3) then return "FAN2TYPE_2FAN" end

	if (iFAN2Type==4) then return "FAN2TYPE_3FAN" end

	if (iFAN2Type==5) then return "FAN2TYPE_3FAN_MODUL" end
end

function getFluidStr(iFluidState)

	if (iFluidState==0) then return "FLUID_AIR" end

	if (iFluidState==1) then return "FLUID_WATER" end

	if (iFluidState==2) then return "WATER_STORAGE" end
end
