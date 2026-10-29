# Campfire Sit

A small addon for World of Warcraft: Forever. When you're near a campfire, a **Sit by the fire** button appears. Click it and you `/sit`. The button then turns into a 60-second countdown that runs until the camp buff lands.

The button stays hidden while your Camp Benefits buff has 15 minutes or more left. It also stays hidden in combat.

## Install

Copy the `CampfireSit` folder into your WoW Forever client's `Interface\AddOns` folder, for example `World of Warcraft\_forever_\Interface\AddOns\CampfireSit`, then restart the game or `/reload`.

## Use

- Shift-drag the button to move it.
- `/campsit auras` lists your current buffs with their spell IDs.
- `/campsit reset` moves the button back to the middle of the screen.

## If the button never shows

The buff IDs and names at the top of `CampfireSit.lua` (Campfire Nearby, Welcoming Campfire, Camp Benefits) come from beta-era guides. Stand next to a fire, sit for a minute, run `/campsit auras`, and correct the values if they changed.

If the addon is listed as out of date, get the client's interface number with `/run print((select(4, GetBuildInfo())))` and put it on the `## Interface:` line in `CampfireSit.toc`.
