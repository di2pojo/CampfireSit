# Campfire Sit

A small addon for World of Warcraft: Forever. When you're near a campfire, a **Sit by the fire** button appears. Click it and you `/sit`. The button then turns into a 60-second countdown that runs until the camp buff lands.

The button stays hidden while your Camp Benefits buff has 15 minutes or more left (you can change this), and during combat.

## Install

Copy the `CampfireSit` folder into your WoW Forever client's `Interface\AddOns` folder, for example `World of Warcraft\_forever_\Interface\AddOns\CampfireSit`, then restart the game or `/reload`.

## Use

Open the options with `/campsit` or from Options → AddOns → Campfire Sit:

- **Lock button position.** Untick it and the button stays on screen (reading "Drag me" when no fire is near) so you can drag it into place. Tick it again to lock it there.
- **Refresh window slider (0–60 min).** The button comes back when Camp Benefits has less than this much time left. At 0 it only comes back once the buff has run out.
- **Reset position** moves the button back to the middle of the screen.

Slash commands:

- `/campsit lock` / `/campsit unlock`
- `/campsit minutes <0-60>`
- `/campsit reset`
- `/campsit auras` lists your current buffs with their spell IDs.

## If the button never shows

The buff IDs and names at the top of `CampfireSit.lua` (Campfire Nearby, Welcoming Campfire, Camp Benefits) come from beta-era guides. Stand next to a fire, sit for a minute, run `/campsit auras`, and correct the values if they changed.

If the addon is listed as out of date, get the client's interface number with `/run print((select(4, GetBuildInfo())))` and put it on the `## Interface:` line in `CampfireSit.toc`.
