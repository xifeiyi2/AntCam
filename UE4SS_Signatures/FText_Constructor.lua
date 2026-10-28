-- FText_Constructor.lua  (Empires of the Undergrowth, UE 4.27.2, build ++EotU+release-1.2.1.1-CL-21512)
-- Points UE4SS at FText::FromString(FString&&) (RVA 0x163A8A0 in EotU-Win64-Shipping.exe).
-- Generated from the user's exe; the pattern matches exactly one place in .text.
-- If the game updates, this file may stop matching: just delete it or ask for a new one.

function Register()
    return "40 53 55 57 48 83 EC 50 83 7A 08 01 48 8B F9 4C 89 B4 24 80 00 00 00 C7 44 24 70 00 00 00 00 7F ?? E8 ?? ?? ?? ?? 48 8B 58 08 48 8B 08 48 89 4C 24 20 48 89 5C 24 28 48 85 DB 74 ?? F0 FF 43 08 8B 40 10 41 BE 01 00 00 00 89 44 24 30 48 8D 44 24 20 EB ?? 48 8D 4C 24 38 E8 ?? ?? ?? ?? 48 8B 5C 24 28 41 BE 02 00 00 00 48 8B 08 48 89 0F 48 8B 48 08 48 89 4F 08 48 85 C9 74 ?? F0 FF 41 08 8B 40 10 BD FF FF FF FF 89 47 10 41 F6 C6 02 74 ?? 48 89 74 24 78 41 83 E6 FD 48 8B 74 24 40 48 85 F6 74 ?? 8B C5 F0 0F C1 46 08 83 F8 01 75 ?? 48 8B 06 48 8B CE FF 10 8B C5 F0 0F C1 46 0C 83 F8 01 75 ?? 48 8B 06 BA 01 00 00 00 48 8B CE FF 50 08 48 8B 74 24 78 41 F6 C6 01 4C 8B B4 24 80 00 00 00 74 ?? 48 85 DB 74 ?? 8B C5 F0 0F C1 43 08 83 F8 01 75 ?? 48 8B 03 48 8B CB FF 10 F0 0F C1 6B 0C 83 FD 01 75 ?? 48 8B 03 8B D5 48 8B CB FF 50 08 83 4F 10 02"
end

function OnMatchFound(MatchAddress)
    return MatchAddress
end
