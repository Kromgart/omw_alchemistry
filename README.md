# omw_alchemistry (WIP)

This mod contains an alchemy window replacer with the following changes to the in-game alchemy:

### Effects discovery
In vanilla game you automatically know the effects of ingredients and potions, depending on level of alchemy skill and fWortChanceValue GMST. With default fWortChanceLevel of 15 and alchemy skill of 35 you automatically know the first 2 effects of ALL ingredients in the game (and the first 4 effects of all potions).

In this mod the knowledge of effects is discovered and stored for each ingredient type separately. This happens:
 1) on the new "Experiment" tab of alchemy window
 2) when brewing a potion from exactly 2 ingredients (but they both must already have at least one known common effect to be 'mixable')3
 3) TODO: learning this knowledge from books or alchemists' notes

All effects of potions are now visible regardless of alchemy skill.

### Making potions
In vanilla game you could make potions with any ingredients without knowing anything about them. In the mod:
 1) you can only make potions from ingredients with compatible 'known' effects. If you don't know anything about an ingredient - it will not even show up in the ingredients list for potion making.
 2) The ingredients list is dynamically updated according to the ingredients that you put into the slots. It will always steer you to have at least one common effect, and will try to prevent you from adding useless ingredients (according to your knowledge of effects).
 3) The expected potion effects are displayed with duration and magnitude (when applicable), according to your stats and apparatus.
 4) You can control the order of effects on the potion by adding ingredients in different order (this matters, for example if both 'paralyze' and 'cure paralysis' are present)
 5) Potions are named automatically according to all their effects

### Lua effects
The magic effects have been stripped from the ingredient items on the plugin level, and moved to Lua scripts for the following reasons:
  1) removing the list of effects from the ingredient tooltip. I haven't found a way to override a tooltip, so without this change the ingredients would still show their effects via the vanilla tooltip, which uses alchemy-skill and fWortChanceValue formula.
  2) controlling effects from Lua allows greater flexibility in mod development: we are not limited by "4 effects per ingredient" rule, can have custom effects, and randomize effects in-game.

When OpenMW allows to override item tooltips it should be possible to display known effects there. For now the effects are visible only in the new alchemy window, and are not displayed in other UIs (like it is in Daggerfall).

### Experiment tab
You discover effects of ingredients on this tab.
There is one slot for the 'main' ingredient, and a list of available ingredients below.

When you put some ingredient into the 'main' slot, the ingredients list updates to show only unstudied combinations for this main ingredient.

When the main slot is filled, clicking on ingredient in the list will perform the test, consume one item of both ingredients and reveal all common effects.

If some ingredient has been tested with all other ingredients that you have, it will not be present on this tab at all (until you acquire some new ingredient and a new combinations become available).

# Compatibility
Will be incompatible with anything that relies on ingredients having effects. But I can provide a Lua interface that could be queried, if you want to integrate with this mod.

Requires [this MR](https://gitlab.com/OpenMW/openmw/-/merge_requests/4533) to be merged, as it need the functionality of creating records with customized MagicEffectWithParams. Until then you will need a localy built openmw with that change merged in.

Can be installed/removed in ongoing game. New game is not required.
