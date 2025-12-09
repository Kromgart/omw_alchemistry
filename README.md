# omw_alchemistry (WIP)

This is an alchemy window replacer with the following changes to the in-game alchemy:

### Effects visibility
In vanilla game you automatically know the effects of ingredients and potions, depending on level of alchemy skill and fWortChanceValue GMST. With default fWortChanceLevel of 15 and alchemy skill of 35 you automatically know the first 2 effects of ALL ingredients in the game (and the first 4 effects of all potions).

In this mod the knowledge of effects is discovered and stored for each ingredient type separately. This happens:
 1) on the new "Experiment" tab of alchemy window
 2) when brewing a potion from exactly 2 ingredients (but they both must already have at least one known common effect to be 'mixable')

All effects of potions are now visible regardless of alchemy skill.

### Lua effects
The magic effects have been stripped from the ingredient records, and moved to Lua scripts for the following reasons:
  1) removing the list of effects from the ingredient tooltip. I haven't found a way to override a tooltip, so without this change the ingredients would still show their effects via the vanilla tooltip, which uses alchemy-skill and fWortChanceValue formula.
  2) controlling effects from Lua allows greater flexibility in mod development: not "4 effects per ingredient" rule, can have custom effects, and randomize effects in-game.

When OpenMW will allow to override item tooltips it should be possible to display known effects there. For now the effects are visible only in the new alchemy window, and are not displayed in other UIs (like it is in Daggerfall), there the tooltip shows only the name, price and weight.

The ingredients should still sold/bought normally by the same vendors. Eating them should be useless now.

### Making potions
In vanilla game you could make potions with any ingredients without knowing anything about them. In the mod:
 1) you can only make potions from ingredients with compatible 'known' effects. If you don't know anything about an ingredient - it will not even show up in the ingredients list for potion making.
 2) The ingredients list is dynamically updated according to the ingredients that you put into the slots. It will always steer you to have at least one common effect, and will try to prevent you from adding useless ingredients (according to your knowledge of effects).
 3) The expected potion effects are displayed with duration and magnitude (when applicable), according to your stats and apparatus.
 4) You can control the order of effects on the potion by adding ingredients in different order (this matters, for example if both 'paralyze' and 'cure paralysis' are present, or 'Dispel' with anything).
 5) Potions are named automatically according to all their effects.
 6) Creating potions gives less experience that discovering new effects (Experiment tab).

### Experiment tab
You discover effects of ingredients on this tab.
There is one slot for the 'main' ingredient, and a list of available ingredients below.

When you put some ingredient into the 'main' slot, the ingredients list updates to show only unstudied combinations for this main ingredient.

When the main slot is filled, clicking on ingredient in the list will perform the test, consume one item of both ingredients, reveal all common effects and train the alchemy skill. The more effects discovered during the test — the bigger skill increase.

If some ingredient has been tested with all other ingredients that you have, it will not be present on this tab at all (until you acquire some new ingredient and a new combinations become available).

### Ingredients tab
Allows you to see and look through all known ingredients with their known effects, in case you don't have one available but need that info.

### Food items
The game has some ingredients which have just one 'Restore Fatigue' effect (and some mods add a lot of these). Such ingredients have been converted to 'potion' type with a fixed restore fatigue effect (1pt for 120 seconds). They still look the same as before of course.

Most of these things are arleady 'cooked' or 'baked' or smth, so it doesn't make sense for them to clutter alchemy. Maybe some cooking/survival/needs mod could use them better.

# Compatibility
  - Incompatible with anything that relies on ingredients having effects (because we move them to Lua). But I can provide a Lua interface that could be queried, if you want to integrate with this mod.

  - Incompatible with mods which add ingredients: the mod will not start unless there is a compatibility patch. There are several patches is directory ./01_Patches, and it is generally trivial to make a patch.

  - Currently requires [this MR](https://gitlab.com/OpenMW/openmw/-/merge_requests/4533) to be merged, as it need the functionality of creating records with customized MagicEffectWithParams. Right now you will need a localy built openmw with that change merged in, otherwise the script won't be able to create potions (although everything else should still work)

    If openmw rejects that MR and implements some different way of creating parametrized magic effects, this mod will be updated accordingly.

  - Can be installed/removed in ongoing game. New game is not required.

