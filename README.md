# omw_alchemistry (WIP)

This mod overhauls the alchemy-related activities in Morrowind (OpenMW only). The alchemy window has been rewritten in lua, trying to be vanilla-friendly in look and feel. Here is the detailed list of changes:

### Effects visibility
In vanilla game you automatically know the effects of ingredients and potions, depending on level of alchemy skill and fWortChanceValue GMST. With default fWortChanceLevel of 15 and alchemy skill of 35 you automatically know the first 2 effects of ALL ingredients in the game (and the first 4 effects of all potions).

In this mod the knowledge of effects is discovered and stored for each ingredient type separately. For now this happens:
 1) on the new "Experiment" tab of alchemy window
 2) when brewing a potion from exactly 2 ingredients (but they both must already have at least one known common effect to be 'mixable')

All effects of potions are now visible regardless of alchemy skill (fWortChanceValue is 0).

### Lua effects
The magic effects have been stripped from the ingredient records, and moved to Lua scripts for the following reasons:
  1) removing the list of effects from the ingredient tooltip. I haven't found a way to override a tooltip, so without this change the ingredients would still show their effects via the vanilla tooltip, which uses alchemy-skill and fWortChanceValue formula.
  2) controlling effects from Lua allows greater flexibility in mod development: not "4 effects per ingredient" rule, can have custom effects, and randomize effects in-game.

When OpenMW will allow to override item tooltips it should be possible to display known effects there. For now the effects are visible only in the new alchemy window, and are not displayed in other UIs (like it is in Daggerfall), there the tooltip shows only the name, price and weight.

The ingredients should still sold/bought normally by the same vendors.

Eating ingredients is useless now.

### Making potions
In vanilla game you could make potions with any ingredients without knowing anything about them. In the mod:
 1) you can only make potions from ingredients with compatible 'known' effects. If you don't know anything about an ingredient - it will not even show up in the ingredients list for potion making.
 2) The ingredients list is dynamically updated according to the ingredients that you put into the slots. It will always steer you to have at least one common effect, and will try to prevent you from adding useless ingredients (according to your knowledge of effects).
 3) The expected potion effects are displayed with duration and magnitude (when applicable), according to your stats and apparatus.
 4) Potions weight is fixed (0.5). Use the ingredients which have the effects you need, don't worry about potion weighting like a brick.
 5) Potions are named automatically according to all their effects.
 6) Creating potions gives less experience (x0.5) than discovering new effects (Experiment tab).

### Experiment tab
You discover effects of ingredients on this tab.

There is one slot for the 'main' ingredient, and a list of available ingredients below.

When you put some ingredient into the 'main' slot, the ingredients list updates to show only untested combinations for this main ingredient.

When the main slot is filled, clicking on ingredient in the list will perform the test, consume one item of both ingredients, reveal all common effects and train the alchemy skill. The more effects discovered during the test — the bigger the skill increase.

If some ingredient has been tested with all other ingredients that you have, it will not be present on this tab at all (until you acquire some new ingredient and a new combinations become available).

### Ingredients tab
Allows you to see and look through all known ingredients with their known effects, in case you don't have one available but need that info. The list can be searched for a particular effect or ingredient name (exact match for now).

### Food items
The game has some ingredients which have just one 'Restore Fatigue' effect (and some mods add a lot of these). Such ingredients have been converted to 'potion' type with a fixed restore fatigue effect (1pt for 120 seconds). They still look the same as before of course.

Most of these things have already been cooked or baked or otherwise processed, so it doesn't make sense for them to clutter alchemy. Maybe some cooking/survival/needs mod could use them better.

# Installation
 - 00_Core directory contains the main mod. Enable the alchemistry.omwaddon and alchemistry.omwscripts as usual.
 - 01_Patches contains patches (.omwaddons and scripts) for some mods that add ingredients into the game. Just enable the relevant .omwaddons file in the launcher.

# Compatibility
  - Can be installed/removed in ongoing game. New game is not required.
  - Incompatible with anything that relies on ingredients having effects (because we move them to Lua). But I can provide a Lua interface that could be queried, if you want to integrate with this mod.
  - Incompatible with mods which add ingredients: the mod will not start unless there is a compatibility patch. There are several patches is directory ./01_Patches, and it is generally trivial to make a patch.
  - Currently requires [this MR](https://gitlab.com/OpenMW/openmw/-/merge_requests/4533) to be merged, as it need the functionality of creating records with customized MagicEffectWithParams. Right now you will need a localy built openmw with that change merged in, otherwise the script won't be able to create potions (although everything else should still work). If openmw rejects that MR and implements some different way of creating parametrized magic effects, this mod will be updated accordingly.


