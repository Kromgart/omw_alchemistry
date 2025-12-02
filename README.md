# omw_alchemistry (WIP)

This mod contains an alchemy window replacer with the following changes to the in-game alchemy:

## Effects discovery
In vanilla game you automatically know the effects of ingredients and potions, depending on level of alchemy skill and fWortChanceValue GMST. With default fWortChanceLevel of 15 and alchemy skill of 35 you automatically know the first 2 effects of ALL ingredients in the game (and the first 4 effects of all potions).

In this mod the knowledge of effects is discovered and stored for each ingredient type separately (somewhat similar how this was made in TES5 Skyrim). This is done primarily on the new "Experiment" tab of alchemy window, but other methods to acquire such knowledge are planned.

All effects of potions are now visible regardless of alchemy skill.

## Making potions
In vanilla game you could make potions with any ingredients without knowing anything about them, and still get a potion with all relevant effects. In the mod you can only make potions from ingredients with 'known' effects. If you don't know anything about an ingredient - it will not even show up in the ingredients list for potion making.

## LUA effects
The magic effects have been stripped from the ingredient items on the plugin level, and moved to Lua scripts for the following reasons:
  * removing the list of effects from the ingredient tooltip. I haven't found a way to override a tooltip, so without this change the ingredients would still show their effects via the vanilla tooltip, which uses alchemy-skill and fWortChanceValue formula.
  * controlling effects from Lua allows greater flexibility in mod development: we are not limited by "4 effects per ingredient" rule, can have custom effects, and randomize effects in-game.
When OpenMW allows to override item tooltips it should be possible to display known effects there. For now the effects are visible only in the new alchemy window, and are not displayed in other UIs (like it is in Daggerfall).

