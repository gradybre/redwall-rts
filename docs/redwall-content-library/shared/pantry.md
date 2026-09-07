# Shared pantry and recipe dependencies

Status: **COMPLETE_AVAILABLE_CORPUS_AGGREGATION**. All game candidates remain **NOT_RUNTIME_ACTIVE**.

| Measure | Count |
|---|---:|
| books available | 12 |
| books expected | 12 |
| recipes | 1755 |
| production candidates | 1707 |
| excluded production rows | 48 |
| source terms | 723 |
| source occurrences | 4225 |
| distinct normalized game inputs | 371 |
| components total | 331 |
| book component variants | 137 |
| shared authored components | 194 |
| leaf inputs used | 159 |
| opaque unknown terms | 0 |
| dependency cycles | 0 |
| owner issue records | 0 |

Missing packages: None..

## Evidence and use

The canonical term index preserves every supplied recipe ingredient entry and ingredient-catalog record. Supplied ranges can group repetitions, and the two indexing layers can repeat evidence; these counts are not a census of every lexical mention in the novels. Contexts include medicines, wildlife foods, rejected meals, comic references and incomplete dish names. Its count is an indexing count, not a claim that every mention is an edible resource or an independent observed meal. Semantic merges apply only to the game pantry.

Book-local component recipes retain their own ingredients. Oat cream made with sunflower oil and oat cream made with hazelnut paste are different authored variants; neither becomes proof about the original novel. The dependency resolver uses the local formula, then a shared authored default, then a declared leaf. Unknown terms remain blocked and cycles are reported.

Join a normalized shared recipe by `(book_key, local_id) == (pantry book, book_recipe_id)`, or match its ID to the pantry row’s `shared_recipe_id`. The pantry’s own `id` remains a separate qualified key. Prefer each `game_inputs.target_kind` and `target_id`, which already incorporates the explicit game-only normalization map. Preserve `book_term` as the original proposed input; never perform fuzzy source-name matching.

`production_candidate: false` excludes a row from the recipe-production candidate set even if its book file preserves optional authored ingredients. Those inputs remain research proposals. No row is runtime active, including rows whose production-candidate flag is true.

Outcast’s specific greensap evidence must remain tied to its record and location. It does not establish the origin of every cheese, cream or milk in the series. The shared oat-based greensap candidate is a selected game recipe.

| Requirement | EARS rule |
|---|---|
| PANTRY-001 | WHEN a coding agent selects a dish, it SHALL preserve its book-qualified source ID, source ingredients and separate game additions. |
| PANTRY-002 | WHEN a component has book-local and shared formulas, the author SHALL select the applicable variant explicitly before assigning production values. |
| PANTRY-003 | IF a dependency is unknown or cyclic, the pipeline SHALL block runtime activation and report its exact term and recipe references. |
| PANTRY-004 | WHEN source food conflicts with the game diet, the author SHALL preserve the source and use an explicitly renamed game alternative. |
| PANTRY-005 | WHILE yields, work, quantities and unlocks are unspecified, these candidates SHALL remain inactive research data. |

## Component formulas

Every formula below is a game authoring choice. Ingredient order is a dependency list, not a quantity ratio. Source recipes retain their original evidence in the book dossiers.

| Component ID | Scope / label | Constituents | Ordered preparation |
|---|---|---|---|
| `COMPONENT_long_patrol_bread` | long_patrol / bread | wheat flour, water, bread starter, salt | Mix wheat flour, water, starter and salt into dough; represent proofing, shaping and baking as ordered game steps. |
| `COMPONENT_long_patrol_greensap_milk` | long_patrol / greensap milk | oats, water | For this separately authored game variant, soften oats in water, grind and strain. Preserve greensap as the literary source label; this does not claim canonical grass-stem/tuber identities. |
| `COMPONENT_long_patrol_maple` | long_patrol / maple | maple syrup | Use prepared maple syrup as the game form of the unspecified literary maple flavor; this does not define tree-tapping yield. |
| `COMPONENT_long_patrol_mushroom_stock` | long_patrol / mushroom stock | mushroom, onion, water | Simmer mushroom and onion in water, then strain to a clear game cooking liquid. |
| `COMPONENT_long_patrol_oat_and_seed_cheese` | long_patrol / oat and seed cheese | oats, sunflower seed, water, apple vinegar, salt | Soften oats and sunflower seeds in water, grind, add apple vinegar and salt, then drain and press into a firm game cheese. |
| `COMPONENT_long_patrol_oat_and_seed_curd` | long_patrol / oat and seed curd | oats, sunflower seed, water, apple vinegar | Soften oats and sunflower seeds in water, grind, add apple vinegar and drain to a soft spoonable game curd. |
| `COMPONENT_long_patrol_oat_cream` | long_patrol / oat cream | oats, water, sunflower oil | Soften oats in water, grind with sunflower oil, strain and thicken to a spoonable game cream. This is an authored plant preparation. |
| `COMPONENT_long_patrol_roasted_almonds` | long_patrol / roasted almonds | almond | Shell the almonds and represent dry roasting, cooling and chopping as ordered preparation states. |
| `COMPONENT_outcast_almond_oat_cream` | outcast / almond oat cream | almond, oat drink, honey | Grind almonds with oat drink and honey. |
| `COMPONENT_outcast_almond_paste` | outcast / almond paste | almond, honey, water | Grind almonds with honey and water into paste. |
| `COMPONENT_outcast_apple_cordial` | outcast / apple cordial | apple, water, honey | Press fruit, strain, dilute and sweeten. |
| `COMPONENT_outcast_apple_turnover` | outcast / apple turnover | oat pastry, apple, honey | Enclose chopped apple and honey in folded pastry, seal and bake. |
| `COMPONENT_outcast_apple_vinegar` | outcast / apple vinegar | apple, fermentation culture, vinegar culture | Ferment pressed apple juice, then use the game vinegar culture process. |
| `COMPONENT_outcast_arrowroot_shortbread` | outcast / arrowroot shortbread | arrowroot starch, oat flour, hazelnut oil, honey | Rub oil into flours, add honey, press into a dish and bake. |
| `COMPONENT_outcast_black_treacle` | outcast / black treacle | sugar syrup | Reduce the authored sugar syrup into dark treacle. |
| `COMPONENT_outcast_blackberry_jam` | outcast / blackberry jam | blackberry, honey, apple pectin | Cook and mash fruit, sweeten and set with game pectin. |
| `COMPONENT_outcast_blackberry_oat_cream` | outcast / blackberry oat cream | blackberry, oat cream | Crush blackberries and whisk into oat cream. |
| `COMPONENT_outcast_blackberry_tart` | outcast / blackberry tart | oat pastry, blackberry, honey | Fill a shallow pastry case with berries and honey and bake. |
| `COMPONENT_outcast_candied_apple` | outcast / candied apple | apple, honey | Glaze prepared fruit slices in honey syrup and dry. |
| `COMPONENT_outcast_candied_chestnut` | outcast / candied chestnut | prepared sweet chestnut, honey | Glaze prepared nuts in honey syrup and dry. |
| `COMPONENT_outcast_candied_plum` | outcast / candied plum | pitted plum, honey | Glaze prepared fruit in honey syrup and dry. |
| `COMPONENT_outcast_cherry_conserve` | outcast / cherry conserve | pitted cherry, honey | Cook fruit with honey to a spread. |
| `COMPONENT_outcast_crystallized_young_maple_leaves` | outcast / crystallized young maple leaves | cultivated game maple leaf, sugar, water | Coat the fictional cultivated maple leaf ingredient in syrup and cool; source species chemistry not inferred. |
| `COMPONENT_outcast_cultured_almond_cheese` | outcast / cultured almond cheese | almond, water, food culture, salt | Grind almonds with water and salt, culture and drain. |
| `COMPONENT_outcast_cultured_hazelnut_cheese` | outcast / cultured hazelnut cheese | hazelnut, water, food culture, salt | Grind hazelnuts with water and salt, culture and drain. |
| `COMPONENT_outcast_cultured_oat_cheese` | outcast / cultured oat cheese | oats, water, food culture, salt | Grind oats with water and salt, culture and drain. |
| `COMPONENT_outcast_cultured_oat_cream` | outcast / cultured oat cream | oat cream, food culture | Culture oat cream in a game food vessel. |
| `COMPONENT_outcast_cultured_pumpkin_seed_cheese` | outcast / cultured pumpkin-seed cheese | pumpkin seed, water, food culture, salt | Grind pumpkin seeds with water and salt, culture and drain. |
| `COMPONENT_outcast_damson_oat_cream` | outcast / damson oat cream | damson, oat cream | Cook and sieve damsons, cool and whisk into oat cream. |
| `COMPONENT_outcast_damson_preserve` | outcast / damson preserve | pitted damson, honey | Cook fruit with honey to a spread. |
| `COMPONENT_outcast_dried_mussel` | outcast / dried mussel | prepared mussel | Dry prepared permitted seafood in game preservation station. |
| `COMPONENT_outcast_dried_plum` | outcast / dried plum | plum | Prepare plums and use the game drying-rack process. |
| `COMPONENT_outcast_elderberry_jam` | outcast / elderberry jam | elderberry, sugar, apple pectin | Cook prepared elderberries with sugar and pectin into preserve. |
| `COMPONENT_outcast_flaked_almond` | outcast / flaked almond | almond | Slice prepared almonds into thin flakes. |
| `COMPONENT_outcast_fruit_oat_cream` | outcast / fruit oat cream | apple, plum, oat cream | Cook and puree apple and plum, cool and fold into oat cream. |
| `COMPONENT_outcast_game_cornflower_hazelnut_spread` | outcast / game cornflower hazelnut spread | cultivated game cornflower petals, hazelnut paste, hazelnut oil | Blend the authored cultivated edible petals into nut paste and oil. |
| `COMPONENT_outcast_glazed_maple_shoots` | outcast / glazed maple shoots | cultivated game maple shoot, honey, water | Coat the fictional cultivated shoots with honey syrup. |
| `COMPONENT_outcast_gooseberry_jelly` | outcast / gooseberry jelly | gooseberry, honey, apple pectin | Cook and strain fruit, sweeten, set with game pectin. |
| `COMPONENT_outcast_hazelnut_barley_beer` | outcast / hazelnut barley beer | hazelnut, malted barley, water, fermentation culture | Mash barley, strain, add nut flavoring and ferment in the game vessel. |
| `COMPONENT_outcast_hazelnut_cream` | outcast / hazelnut cream | hazelnut paste, oat drink, honey | Blend hazelnut paste, oat drink and honey. |
| `COMPONENT_outcast_hazelnut_paste` | outcast / hazelnut paste | hazelnut, water | Grind prepared hazelnuts with water into paste. |
| `COMPONENT_outcast_hazelnut_truffle` | outcast / hazelnut truffle | hazelnut paste, oat flour, honey | Mix nut paste, toasted oat flour and honey; shape small balls. Chocolate is not assumed. |
| `COMPONENT_outcast_honey_flan` | outcast / honey flan | oat pastry, oat custard, honey | Bake pastry case, fill with honey oat custard and cool. |
| `COMPONENT_outcast_honey_oat_cream` | outcast / honey oat cream | honey, oat cream | Whisk honey into oat cream. |
| `COMPONENT_outcast_maple_oat_cream` | outcast / maple oat cream | maple syrup, oat cream | Whisk maple syrup into oat cream. |
| `COMPONENT_outcast_maple_syrup` | outcast / maple syrup | cultivated game maple sap | Reduce the authored maple sap ingredient into syrup. |
| `COMPONENT_outcast_mint_oat_cream` | outcast / mint oat cream | mint, oat cream | Steep mint in warm oat cream, strain and cool. |
| `COMPONENT_outcast_mushroom_gravy` | outcast / mushroom gravy | mushroom, hazelnut oil, oat flour, water | Cook mushrooms in oil, add flour and water, simmer while stirring. |
| `COMPONENT_outcast_oat_bread` | outcast / oat bread | oat flour, water, salt, bread starter | Mix, knead, raise, shape and bake the dough. |
| `COMPONENT_outcast_oat_cake` | outcast / oat cake | oat flour, oat drink, hazelnut oil, honey | Mix batter and bake in a pan. |
| `COMPONENT_outcast_oat_cream` | outcast / oat cream | oat drink, hazelnut paste | Blend oat drink and hazelnut paste until smooth. |
| `COMPONENT_outcast_oat_custard` | outcast / oat custard | oat drink, arrowroot starch, honey | Disperse starch in cold drink, heat while stirring and sweeten. |
| `COMPONENT_outcast_oat_drink` | outcast / oat drink | oats, water | Soak, grind and strain oats in water. |
| `COMPONENT_outcast_oat_dumpling` | outcast / oat dumpling | oat flour, water, salt | Mix firm dough, form balls and simmer in the stew. |
| `COMPONENT_outcast_oat_farl` | outcast / oat farl | oat flour, water, salt | Mix firm dough, flatten, cut wedges and griddle. |
| `COMPONENT_outcast_oat_fruitcake` | outcast / oat fruitcake | oat flour, oat drink, hazelnut oil, honey, yeast, dried apple, dried plum | Mix batter with dried fruit, bake and cool. |
| `COMPONENT_outcast_oat_pastry` | outcast / oat pastry | oat flour, hazelnut oil, water | Mix, knead briefly and roll into pastry sheets. |
| `COMPONENT_outcast_oat_scone` | outcast / oat scone | oat flour, oat drink, hazelnut oil, honey, yeast | Mix, shape and bake. |
| `COMPONENT_outcast_oat_sponge_cake` | outcast / oat sponge cake | oat flour, oat drink, hazelnut oil, honey, yeast | Mix batter with game leavening and bake into a light cake. |
| `COMPONENT_outcast_parsley_wine` | outcast / parsley wine | parsley, grape juice, fermentation culture | Flavor prepared grape juice with cultivated parsley and ferment in game vessel. |
| `COMPONENT_outcast_porridge` | outcast / porridge | oats, water | Simmer oats in water while stirring. |
| `COMPONENT_outcast_prepared_beechnut_paste` | outcast / prepared beechnut paste | prepared beechnut, water | Grind supplied prepared culinary nuts with water. |
| `COMPONENT_outcast_red_grape_wine` | outcast / red grape wine | red grape, fermentation culture | Crush red grapes and ferment; grape selection is authored because source says only red wine. |
| `COMPONENT_outcast_redcurrant_preserve` | outcast / redcurrant preserve | redcurrant, honey, apple pectin | Cook and strain fruit, sweeten and set with game pectin. |
| `COMPONENT_outcast_rose_oat_cream` | outcast / rose oat cream | rose syrup, oat cream | Whisk rose syrup into oat cream. |
| `COMPONENT_outcast_rose_syrup` | outcast / rose syrup | cultivated game rose petals, sugar, water | Steep petals, strain and dissolve sugar into liquid. |
| `COMPONENT_outcast_rosehip_syrup` | outcast / rosehip syrup | rosehip, sugar, water | Cook and strain rosehips, then sweeten the strained liquid. |
| `COMPONENT_outcast_rosewater` | outcast / rosewater | cultivated game rose petals, water | Steep petals and strain into a beverage ingredient; washing-water contexts remain separate. |
| `COMPONENT_outcast_saffron_oat_cream` | outcast / saffron oat cream | saffron, oat cream | Steep saffron in warm oat cream, then cool. |
| `COMPONENT_outcast_saffron_oat_fondant` | outcast / saffron oat fondant | saffron, sugar, water, oat drink | Heat sugar and water into syrup, beat with oat drink and saffron. |
| `COMPONENT_outcast_strawberry_jam` | outcast / strawberry jam | strawberry, sugar, apple pectin | Cook strawberries with sugar and pectin into preserve. |
| `COMPONENT_outcast_sugar_preserved_maple_sprig` | outcast / sugar-preserved maple sprig | cultivated game maple sprig, sugar, water | Coat fictional cultivated sprig in syrup and cool. |
| `COMPONENT_outcast_sweet_arrowroot_oat_sauce` | outcast / sweet arrowroot oat sauce | arrowroot starch, oat drink, honey | Disperse starch in cold drink, heat while stirring and sweeten. |
| `COMPONENT_outcast_toasted_pumpkin_seed` | outcast / toasted pumpkin seed | pumpkin seed | Toast the prepared seeds. |
| `COMPONENT_outcast_toasted_sunflower_seed` | outcast / toasted sunflower seed | sunflower seed | Toast the prepared seeds. |
| `COMPONENT_outcast_unsweetened_oat_custard` | outcast / unsweetened oat custard | oat drink, arrowroot starch | Disperse starch in cold oat drink and heat while stirring. |
| `COMPONENT_outcast_vegetable_flan` | outcast / vegetable flan | oat pastry, carrot, leek, turnip, unsweetened oat custard | Line a dish with pastry, fill with chopped cooked vegetables and unsweetened authored oat custard, then bake. |
| `COMPONENT_outcast_wholegrain_oat_bread` | outcast / wholegrain oat bread | wholegrain oat flour, water, salt, bread starter | Mix, knead, raise, shape and bake the wholegrain dough. |
| `COMPONENT_redwall_fruit_spirit` | redwall / fruit spirit | apple, water, fermentation culture | Represent apple juice fermentation followed by an abstract spirit-production and maturation job. No real distillation procedure, alcohol strength or dose is provided. |
| `COMPONENT_redwall_oat_cream` | redwall / oat cream | oats, water, sunflower oil | Soften oats in water, grind with sunflower oil, strain and thicken to a spoonable game cream. This is an authored plant preparation. |
| `COMPONENT_redwall_oat_drink` | redwall / oat drink | oats, water | Soften oats in water, grind and strain into a pourable game drink. |
| `COMPONENT_redwall_processed_acorn_puree` | redwall / processed acorn puree | processed acorn meal, water | Mix preprocessed edible acorn meal with water and heat to a smooth game puree; raw acorn processing is not specified or endorsed. |
| `COMPONENT_redwall_white_gooseberry_wine` | redwall / white gooseberry wine | white gooseberry, water, honey, fermentation culture | Crush white gooseberries into juice, mix with water and honey and represent culture fermentation and cellar conditioning as abstract ordered game jobs. |
| `COMPONENT_salamandastron_almond_oat_cream` | salamandastron / almond oat cream | almond, oat drink, honey | Grind almonds with oat drink and honey. |
| `COMPONENT_salamandastron_almond_paste` | salamandastron / almond paste | almond, honey, water | Grind almonds with honey and water into paste. |
| `COMPONENT_salamandastron_apple_turnover` | salamandastron / apple turnover | oat pastry, apple, honey | Enclose chopped apple and honey in folded pastry, seal and bake. |
| `COMPONENT_salamandastron_apple_vinegar` | salamandastron / apple vinegar | apple, fermentation culture, vinegar culture | Ferment pressed apple juice, then use the game vinegar culture process. |
| `COMPONENT_salamandastron_arrowroot_shortbread` | salamandastron / arrowroot shortbread | arrowroot starch, oat flour, hazelnut oil, honey | Rub oil into flours, add honey, press into a dish and bake. |
| `COMPONENT_salamandastron_black_treacle` | salamandastron / black treacle | sugar syrup | Reduce the authored sugar syrup into dark treacle. |
| `COMPONENT_salamandastron_blackberry_oat_cream` | salamandastron / blackberry oat cream | blackberry, oat cream | Crush blackberries and whisk into oat cream. |
| `COMPONENT_salamandastron_blackberry_tart` | salamandastron / blackberry tart | oat pastry, blackberry, honey | Fill a shallow pastry case with berries and honey and bake. |
| `COMPONENT_salamandastron_candied_chestnut` | salamandastron / candied chestnut | chestnut, honey, water | Coat prepared chestnuts with heated honey syrup and cool. |
| `COMPONENT_salamandastron_crystallized_young_maple_leaves` | salamandastron / crystallized young maple leaves | cultivated game maple leaf, sugar, water | Coat the fictional cultivated maple leaf ingredient in syrup and cool; source species chemistry not inferred. |
| `COMPONENT_salamandastron_cultured_almond_cheese` | salamandastron / cultured almond cheese | almond, water, food culture, salt | Grind almonds with water and salt, culture and drain. |
| `COMPONENT_salamandastron_cultured_hazelnut_cheese` | salamandastron / cultured hazelnut cheese | hazelnut, water, food culture, salt | Grind hazelnuts with water and salt, culture and drain. |
| `COMPONENT_salamandastron_cultured_oat_cheese` | salamandastron / cultured oat cheese | oats, water, food culture, salt | Grind oats with water and salt, culture and drain. |
| `COMPONENT_salamandastron_cultured_oat_cream` | salamandastron / cultured oat cream | oat cream, food culture | Culture oat cream in a game food vessel. |
| `COMPONENT_salamandastron_cultured_pumpkin_seed_cheese` | salamandastron / cultured pumpkin-seed cheese | pumpkin seed, water, food culture, salt | Grind pumpkin seeds with water and salt, culture and drain. |
| `COMPONENT_salamandastron_damson_oat_cream` | salamandastron / damson oat cream | damson, oat cream | Cook and sieve damsons, cool and whisk into oat cream. |
| `COMPONENT_salamandastron_dried_plum` | salamandastron / dried plum | plum | Prepare plums and use the game drying-rack process. |
| `COMPONENT_salamandastron_elderberry_jam` | salamandastron / elderberry jam | elderberry, sugar, apple pectin | Cook prepared elderberries with sugar and pectin into preserve. |
| `COMPONENT_salamandastron_flaked_almond` | salamandastron / flaked almond | almond | Slice prepared almonds into thin flakes. |
| `COMPONENT_salamandastron_fruit_oat_cream` | salamandastron / fruit oat cream | apple, plum, oat cream | Cook and puree apple and plum, cool and fold into oat cream. |
| `COMPONENT_salamandastron_game_cornflower_hazelnut_spread` | salamandastron / game cornflower hazelnut spread | cultivated game cornflower petals, hazelnut paste, hazelnut oil | Blend the authored cultivated edible petals into nut paste and oil. |
| `COMPONENT_salamandastron_glazed_maple_shoots` | salamandastron / glazed maple shoots | cultivated game maple shoot, honey, water | Coat the fictional cultivated shoots with honey syrup. |
| `COMPONENT_salamandastron_hazelnut_barley_beer` | salamandastron / hazelnut barley beer | hazelnut, malted barley, water, fermentation culture | Mash barley, strain, add nut flavoring and ferment in the game vessel. |
| `COMPONENT_salamandastron_hazelnut_cream` | salamandastron / hazelnut cream | hazelnut paste, oat drink, honey | Blend hazelnut paste, oat drink and honey. |
| `COMPONENT_salamandastron_hazelnut_paste` | salamandastron / hazelnut paste | hazelnut, water | Grind prepared hazelnuts with water into paste. |
| `COMPONENT_salamandastron_hazelnut_truffle` | salamandastron / hazelnut truffle | hazelnut paste, oat flour, honey | Mix nut paste, toasted oat flour and honey; shape small balls. Chocolate is not assumed. |
| `COMPONENT_salamandastron_honey_flan` | salamandastron / honey flan | oat pastry, oat custard, honey | Bake pastry case, fill with honey oat custard and cool. |
| `COMPONENT_salamandastron_honey_oat_cream` | salamandastron / honey oat cream | honey, oat cream | Whisk honey into oat cream. |
| `COMPONENT_salamandastron_maple_oat_cream` | salamandastron / maple oat cream | maple syrup, oat cream | Whisk maple syrup into oat cream. |
| `COMPONENT_salamandastron_maple_syrup` | salamandastron / maple syrup | cultivated game maple sap | Reduce the authored maple sap ingredient into syrup. |
| `COMPONENT_salamandastron_mint_oat_cream` | salamandastron / mint oat cream | mint, oat cream | Steep mint in warm oat cream, strain and cool. |
| `COMPONENT_salamandastron_oat_bread` | salamandastron / oat bread | oat flour, water, salt, bread starter | Mix, knead, raise, shape and bake the dough. |
| `COMPONENT_salamandastron_oat_cake` | salamandastron / oat cake | oat flour, oat drink, hazelnut oil, honey | Mix batter and bake in a pan. |
| `COMPONENT_salamandastron_oat_cream` | salamandastron / oat cream | oat drink, hazelnut paste | Blend oat drink and hazelnut paste until smooth. |
| `COMPONENT_salamandastron_oat_custard` | salamandastron / oat custard | oat drink, arrowroot starch, honey | Disperse starch in cold drink, heat while stirring and sweeten. |
| `COMPONENT_salamandastron_oat_drink` | salamandastron / oat drink | oats, water | Soak, grind and strain oats in water. |
| `COMPONENT_salamandastron_oat_dumpling` | salamandastron / oat dumpling | oat flour, water, salt | Mix firm dough, form balls and simmer in the stew. |
| `COMPONENT_salamandastron_oat_pastry` | salamandastron / oat pastry | oat flour, hazelnut oil, water | Mix, knead briefly and roll into pastry sheets. |
| `COMPONENT_salamandastron_oat_sponge_cake` | salamandastron / oat sponge cake | oat flour, oat drink, hazelnut oil, honey, yeast | Mix batter with game leavening and bake into a light cake. |
| `COMPONENT_salamandastron_porridge` | salamandastron / porridge | oats, water | Simmer oats in water while stirring. |
| `COMPONENT_salamandastron_red_grape_wine` | salamandastron / red grape wine | red grape, fermentation culture | Crush red grapes and ferment; grape selection is authored because source says only red wine. |
| `COMPONENT_salamandastron_rose_oat_cream` | salamandastron / rose oat cream | rose syrup, oat cream | Whisk rose syrup into oat cream. |
| `COMPONENT_salamandastron_rose_syrup` | salamandastron / rose syrup | cultivated game rose petals, sugar, water | Steep petals, strain and dissolve sugar into liquid. |
| `COMPONENT_salamandastron_rosehip_syrup` | salamandastron / rosehip syrup | rosehip, sugar, water | Cook and strain rosehips, then sweeten the strained liquid. |
| `COMPONENT_salamandastron_rosewater` | salamandastron / rosewater | cultivated game rose petals, water | Steep petals and strain into a beverage ingredient; washing-water contexts remain separate. |
| `COMPONENT_salamandastron_saffron_oat_cream` | salamandastron / saffron oat cream | saffron, oat cream | Steep saffron in warm oat cream, then cool. |
| `COMPONENT_salamandastron_saffron_oat_fondant` | salamandastron / saffron oat fondant | saffron, sugar, water, oat drink | Heat sugar and water into syrup, beat with oat drink and saffron. |
| `COMPONENT_salamandastron_strawberry_jam` | salamandastron / strawberry jam | strawberry, sugar, apple pectin | Cook strawberries with sugar and pectin into preserve. |
| `COMPONENT_salamandastron_sugar_preserved_maple_sprig` | salamandastron / sugar-preserved maple sprig | cultivated game maple sprig, sugar, water | Coat fictional cultivated sprig in syrup and cool. |
| `COMPONENT_salamandastron_toasted_pumpkin_seed` | salamandastron / toasted pumpkin seed | pumpkin seed | Toast the prepared seeds. |
| `COMPONENT_salamandastron_toasted_sunflower_seed` | salamandastron / toasted sunflower seed | sunflower seed | Toast the prepared seeds. |
| `COMPONENT_salamandastron_unsweetened_oat_custard` | salamandastron / unsweetened oat custard | oat drink, arrowroot starch | Disperse starch in cold oat drink and heat while stirring. |
| `COMPONENT_salamandastron_vegetable_flan` | salamandastron / vegetable flan | oat pastry, carrot, leek, turnip, unsweetened oat custard | Line a dish with pastry, fill with chopped cooked vegetables and unsweetened authored oat custard, then bake. |
| `COMPONENT_salamandastron_wholegrain_oat_bread` | salamandastron / wholegrain oat bread | wholegrain oat flour, water, salt, bread starter | Mix, knead, raise, shape and bake the wholegrain dough. |
| `COMPONENT_shared_ale` | shared / ale | malted barley, water, fermentation culture | Mash malted barley, strain and apply abstract fermentation and cellar-conditioning jobs. |
| `COMPONENT_shared_almond_flour` | shared / almond flour | almond | Clean the game almond, dry if needed and mill into flour. |
| `COMPONENT_shared_almond_icing` | shared / almond icing | almond flour, honey, water | Mix finely ground almond flour with honey and water into a smooth icing; spread it or shape it into the declared decoration. The formula is a game completion. |
| `COMPONENT_shared_almond_oil` | shared / almond oil | almond | Press prepared almond kernels and separate the oil as a game ingredient; extraction yield is unassigned. |
| `COMPONENT_shared_almond_paste` | shared / almond paste | almond, honey, water | Grind almonds with water and honey into a sweet paste. |
| `COMPONENT_shared_apple_and_blackberry` | shared / apple and blackberry | apple, blackberry | Prepare each listed game ingredient separately, then combine as the named mixture. |
| `COMPONENT_shared_apple_and_mint` | shared / apple and mint | apple, mint | Prepare each listed game ingredient separately, then combine as the named mixture. |
| `COMPONENT_shared_apple_and_pear` | shared / apple and pear | apple, pear | Prepare each listed game ingredient separately, then combine as the named mixture. |
| `COMPONENT_shared_apple_juice` | shared / apple juice | apple, water | Prepare, crush or steep the game apple, then strain with water into juice. Botanical identity is the selected game ingredient. |
| `COMPONENT_shared_apple_preserve` | shared / apple preserve | apple, honey, water, apple pectin | Core the apples, chop the edible fruit and cook with water and honey; add apple pectin to represent a game preserve, with no real storage claim. |
| `COMPONENT_shared_apple_vinegar` | shared / apple vinegar | apple, fermentation culture, vinegar culture | Press apples, ferment the juice and apply a separate vinegar-culture game job. |
| `COMPONENT_shared_barley_bread` | shared / barley bread | barley flour, water, bread starter, salt | Mix barley dough with starter, proof, shape and bake. |
| `COMPONENT_shared_barley_flour` | shared / barley flour | barley | Clean the game barley, dry if needed and mill into flour. |
| `COMPONENT_shared_barley_meal` | shared / barley meal | barley | Clean barley and grind coarsely into meal. |
| `COMPONENT_shared_barley_pearls` | shared / barley pearls | barley | Clean barley and abrade the grain into pearled kernels. |
| `COMPONENT_shared_barley_sponge` | shared / barley sponge | barley flour, oat drink, hazelnut oil, honey, yeast | Mix sweet barley batter, proof with game yeast and bake into sponge. |
| `COMPONENT_shared_barley_toast` | shared / barley toast | barley bread | Slice prepared barley bread and toast. |
| `COMPONENT_shared_beet_sugar` | shared / beet sugar | sugar beet | Represent washing, slicing, juice extraction, clarification and crystallization of sugar beet as abstract game processing states. |
| `COMPONENT_shared_berry_compote` | shared / berry compote | selected berry mix, honey, water | Cook the selected berry mix with honey and water into a soft game fruit topping. |
| `COMPONENT_shared_black_treacle` | shared / black treacle | beet sugar, water | Represent darkening and reduction of beet-sugar syrup into a game treacle. |
| `COMPONENT_shared_blackberry_jam` | shared / blackberry jam | blackberry, honey, water, apple pectin | Cook the prepared blackberry with honey, water and apple pectin into a game preserve; no real canning or shelf-life claim. |
| `COMPONENT_shared_blackberry_jelly` | shared / blackberry jelly | blackberry, honey, water, apple pectin | Crush and strain blackberries, sweeten and thicken the strained juice into a game jelly. |
| `COMPONENT_shared_blackberry_preserve` | shared / blackberry preserve | blackberry, honey, water, apple pectin | Cook the prepared blackberry with honey, water and apple pectin into a game preserve; no real canning or shelf-life claim. |
| `COMPONENT_shared_blackberry_wine` | shared / blackberry wine | blackberry, water, honey, fermentation culture | Prepare the selected blackberry base, strain with water, add honey and use abstract game fermentation and cellar-conditioning jobs. |
| `COMPONENT_shared_bread` | shared / bread | wheat flour, water, bread starter, salt | Mix dough, proof, shape and bake a game loaf. |
| `COMPONENT_shared_bread_starter` | shared / bread starter | wheat flour, water, yeast | Mix flour, water and the seed yeast stock; represent proofing to an active dough starter. Seed stock replenishment is outside this acyclic ingredient graph. |
| `COMPONENT_shared_broken_biscuit` | shared / broken biscuit | ship's biscuit | Break prepared game ship biscuit into small pieces for thickening or topping. |
| `COMPONENT_shared_cabbage_fennel_bake` | shared / cabbage-fennel bake | cabbage, fennel, oat cream, oat flour | Layer chopped cabbage and fennel with oat cream, scatter oat flour over the top and bake. |
| `COMPONENT_shared_candied_apple_flakes` | shared / candied apple flakes | apple, honey, water | Slice apple thinly, coat in honey syrup and cool into game fruit flakes. |
| `COMPONENT_shared_candied_chestnut` | shared / candied chestnut | chestnut, honey, water | Coat the prepared game chestnut in thickened honey syrup and cool; a fictional food state with no preservation-life assertion. |
| `COMPONENT_shared_candied_mint_leaves` | shared / candied mint leaves | mint, honey, water | Coat the prepared game mint in thickened honey syrup and cool; a fictional food state with no preservation-life assertion. |
| `COMPONENT_shared_candied_pear_flakes` | shared / candied pear flakes | pear, honey, water | Slice pear thinly, coat in honey syrup and cool into game fruit flakes. |
| `COMPONENT_shared_candied_strawberry` | shared / candied strawberry | strawberry, honey, water | Coat the prepared game strawberry in thickened honey syrup and cool; a fictional food state with no preservation-life assertion. |
| `COMPONENT_shared_carrot_and_leek` | shared / carrot and leek | carrot, leek | Prepare each listed game ingredient separately, then combine as the named mixture. |
| `COMPONENT_shared_carrot_and_turnip` | shared / carrot and turnip | carrot, turnip | Prepare each listed game ingredient separately, then combine as the named mixture. |
| `COMPONENT_shared_carrot_juice` | shared / carrot juice | carrot, water | Prepare, crush or steep the game carrot, then strain with water into juice. Botanical identity is the selected game ingredient. |
| `COMPONENT_shared_cherry_juice` | shared / cherry juice | cherry, water | Prepare, crush or steep the game cherry, then strain with water into juice. Botanical identity is the selected game ingredient. |
| `COMPONENT_shared_cherry_preserve` | shared / cherry preserve | cherry, honey, water, apple pectin | Cook the prepared cherry with honey, water and apple pectin into a game preserve; no real canning or shelf-life claim. |
| `COMPONENT_shared_chestnut_flour` | shared / chestnut flour | chestnut | Clean the game chestnut, dry if needed and mill into flour. |
| `COMPONENT_shared_chestnut_sauce` | shared / chestnut sauce | chestnut, oat drink, honey | Cook and puree prepared chestnuts, blend with oat drink and honey, then warm into a smooth game sauce. |
| `COMPONENT_shared_chickpea_dumpling` | shared / chickpea dumpling | chickpea flour, water, hazelnut oil, salt | Mix firm pulse dough, shape balls and simmer as a game dumpling. |
| `COMPONENT_shared_chickpea_flour` | shared / chickpea flour | chickpea | Clean the game chickpea, dry if needed and mill into flour. |
| `COMPONENT_shared_chilled_oat_cream` | shared / chilled oat cream | oat cream | Chill the prepared game oat cream; preserve ingredient identity and serving state separately. |
| `COMPONENT_shared_chopped_blackberry` | shared / chopped blackberry | blackberry | Prepare and chop the game blackberries, retaining their juice with the pieces. |
| `COMPONENT_shared_chopped_chestnut` | shared / chopped chestnut | chestnut | Shell prepared edible chestnuts and chop into pieces. |
| `COMPONENT_shared_chopped_raspberry` | shared / chopped raspberry | raspberry | Prepare and chop the game raspberries, retaining their juice with the pieces. |
| `COMPONENT_shared_chopped_selected_berry_mix` | shared / chopped selected berry mix | selected berry mix | Chop the berries in the explicitly selected game berry mixture. |
| `COMPONENT_shared_cooked_apple` | shared / cooked apple | apple, water | Remove the apple core, cut the edible fruit and cook with water until softened; retain as prepared game fruit. |
| `COMPONENT_shared_crumble` | shared / crumble | oat flour, hazelnut oil, honey | Rub oat flour, oil and honey into loose crumbs and bake as a topping. |
| `COMPONENT_shared_crystallized_fruit` | shared / crystallized fruit | apple, plum, honey, water | Choose apple and plum as the game fruit mixture, coat prepared pieces in honey syrup and cool. |
| `COMPONENT_shared_crystallized_plum` | shared / crystallized plum | plum, honey, water | Coat the prepared game plum in thickened honey syrup and cool; a fictional food state with no preservation-life assertion. |
| `COMPONENT_shared_cultured_hazelnut_cheese` | shared / cultured hazelnut cheese | hazelnut, water, food culture, salt | Grind hazelnuts with water, add food culture, drain and press with salt into a firm game cheese. |
| `COMPONENT_shared_cultured_hazelnut_cream` | shared / cultured hazelnut cream | hazelnut paste, oat drink, food culture | Blend hazelnut paste and oat drink, then apply the abstract food-culture job to make a game cream. |
| `COMPONENT_shared_cultured_hazelnut_spread` | shared / cultured hazelnut spread | cultured hazelnut cheese, hazelnut oil | Blend the game hazelnut cheese with hazelnut oil into a spread. |
| `COMPONENT_shared_cultured_oat_curd` | shared / cultured oat curd | oat drink, food culture | Represent oat drink culturing and draining as ordered food-vessel jobs; the result is a soft game curd. |
| `COMPONENT_shared_cultured_oat_spread` | shared / cultured oat spread | cultured oat curd, hazelnut oil | Blend cultured oat curd with hazelnut oil into a spread. |
| `COMPONENT_shared_damson_jam` | shared / damson jam | damson, honey, water, apple pectin | Cook the prepared damson with honey, water and apple pectin into a game preserve; no real canning or shelf-life claim. |
| `COMPONENT_shared_damson_juice` | shared / damson juice | damson, water | Prepare, crush or steep the game damson, then strain with water into juice. Botanical identity is the selected game ingredient. |
| `COMPONENT_shared_damson_preserve` | shared / damson preserve | damson, honey, water, apple pectin | Cook the prepared damson with honey, water and apple pectin into a game preserve; no real canning or shelf-life claim. |
| `COMPONENT_shared_dandelion_and_burdock_cordial` | shared / dandelion and burdock cordial | dandelion petals, burdock, water, honey | Steep the game dandelion and burdock flavor ingredients in water, strain and sweeten with honey; no medicinal effect or real botanical-dose claim. |
| `COMPONENT_shared_dandelion_cordial` | shared / dandelion cordial | dandelion petals, water, honey | Infuse cultivated game dandelion petals in water, strain and sweeten with honey; this is an unfermented cordial with no medical effect. |
| `COMPONENT_shared_dandelion_fizz` | shared / dandelion fizz | dandelion petals, water, honey, food carbonation | Steep and strain game dandelion flavor, sweeten with honey and apply the abstract beverage-carbonation job. |
| `COMPONENT_shared_dandelion_juice` | shared / dandelion juice | dandelion petals, water | Prepare, crush or steep the game dandelion petals, then strain with water into juice. Botanical identity is the selected game ingredient. |
| `COMPONENT_shared_dandelion_wine` | shared / dandelion wine | dandelion petals, water, honey, fermentation culture | Prepare the selected dandelion petals base, strain with water, add honey and use abstract game fermentation and cellar-conditioning jobs. |
| `COMPONENT_shared_dried_apple` | shared / dried apple | apple | Prepare the apple and use the game drying-rack job; no real-world food preservation parameters are asserted. |
| `COMPONENT_shared_dried_culinary_rosehip` | shared / dried culinary rosehip | rosehip | Prepare the rosehip and use the game drying-rack job; no real-world food preservation parameters are asserted. |
| `COMPONENT_shared_dried_fruit` | shared / dried fruit | apple, plum | Prepare apple and plum pieces and dry them through the game preservation job; species selection is authored. |
| `COMPONENT_shared_dried_mint` | shared / dried mint | mint | Prepare the mint and use the game drying-rack job; no real-world food preservation parameters are asserted. |
| `COMPONENT_shared_dried_mussel` | shared / dried mussel | mussel | Prepare the mussel and use the game drying-rack job; no real-world food preservation parameters are asserted. |
| `COMPONENT_shared_dried_plum` | shared / dried plum | plum | Prepare the plum and use the game drying-rack job; no real-world food preservation parameters are asserted. |
| `COMPONENT_shared_dried_trout` | shared / dried trout | trout | Prepare the trout and use the game drying-rack job; no real-world food preservation parameters are asserted. |
| `COMPONENT_shared_elderberry_jam` | shared / elderberry jam | elderberry, honey, water, apple pectin | Cook the prepared elderberry with honey, water and apple pectin into a game preserve; no real canning or shelf-life claim. |
| `COMPONENT_shared_elderberry_wine` | shared / elderberry wine | elderberry, water, honey, fermentation culture | Prepare the selected elderberry base, strain with water, add honey and use abstract game fermentation and cellar-conditioning jobs. |
| `COMPONENT_shared_flaked_almond` | shared / flaked almond | almond | Shell and thinly slice almonds into flakes. |
| `COMPONENT_shared_fruit_spirit` | shared / fruit spirit | apple, water, fermentation culture | Represent apple fermentation, abstract spirit conversion and maturation as game jobs; no real distillation procedure or dose. |
| `COMPONENT_shared_game_hodgepodge_pie` | shared / game hodgepodge pie | hazelnut, leek, cabbage, turnip, radish, chestnut, dandelion, ramsons, mushroom, beetroot, watercress, plant-oil pastry, water | Cook the selected chopped nuts and vegetables in water; cover with game pastry and bake. The literary cooking-song evidence remains in Marlfox, separate from these authored compound ingredients. |
| `COMPONENT_shared_gooseberry_preserve` | shared / gooseberry preserve | gooseberry, honey, water, apple pectin | Cook the prepared gooseberry with honey, water and apple pectin into a game preserve; no real canning or shelf-life claim. |
| `COMPONENT_shared_grape_juice` | shared / grape juice | grape | Crush and press game grapes, then strain the juice. |
| `COMPONENT_shared_grated_carrot` | shared / grated carrot | carrot | Trim and grate the game carrot. |
| `COMPONENT_shared_greengage_preserve` | shared / greengage preserve | greengage, honey, water, apple pectin | Remove greengage pits, cook the fruit with water and honey, then add apple pectin to represent a game preserve; no real storage claim. |
| `COMPONENT_shared_greensap_milk` | shared / greensap milk | oats, water | For this expressly authored oat variant, soak, grind and strain oats in water. This is not the source greensap grass-stem/tuber formula. |
| `COMPONENT_shared_hazelnut_flour` | shared / hazelnut flour | hazelnut | Clean the game hazelnut, dry if needed and mill into flour. |
| `COMPONENT_shared_hazelnut_meal` | shared / hazelnut meal | hazelnut | Shell hazelnuts and grind coarsely into meal. |
| `COMPONENT_shared_hazelnut_oil` | shared / hazelnut oil | hazelnut | Shell and press game hazelnuts, then strain the separated oil. |
| `COMPONENT_shared_hazelnut_paste` | shared / hazelnut paste | hazelnut, water | Grind shelled hazelnuts with water into a smooth paste. |
| `COMPONENT_shared_honey_candied_apple` | shared / honey-candied apple | apple, honey, water | Coat the prepared game apple in thickened honey syrup and cool; a fictional food state with no preservation-life assertion. |
| `COMPONENT_shared_honey_candied_hazelnuts` | shared / honey-candied hazelnuts | hazelnut, honey, water | Coat the prepared game hazelnut in thickened honey syrup and cool; a fictional food state with no preservation-life assertion. |
| `COMPONENT_shared_honey_preserved_rose_petals` | shared / honey-preserved rose petals | cultivated game rose petals, honey, water | Coat the prepared game cultivated game rose petals in thickened honey syrup and cool; a fictional food state with no preservation-life assertion. |
| `COMPONENT_shared_hot_mint_tea` | shared / hot mint tea | mint, water | Infuse mint in hot water and strain as a game drink. |
| `COMPONENT_shared_hotroot_soup` | shared / hotroot soup | mussel, water, onion, fictional hotroot spice | Cook mussel and onion in water and add the explicitly fictional game spice; no botanical identity is asserted. |
| `COMPONENT_shared_leek_and_pea` | shared / leek and pea | leek, pea | Prepare each listed game ingredient separately, then combine as the named mixture. |
| `COMPONENT_shared_lemon_juice` | shared / lemon juice | lemon, water | Prepare, crush or steep the game lemon, then strain with water into juice. Botanical identity is the selected game ingredient. |
| `COMPONENT_shared_lettuce_and_cucumber` | shared / lettuce and cucumber | lettuce, cucumber | Prepare each listed game ingredient separately, then combine as the named mixture. |
| `COMPONENT_shared_maize_flour` | shared / maize flour | maize | Clean the game maize, dry if needed and mill into flour. |
| `COMPONENT_shared_malted_barley` | shared / malted barley | barley, water | Represent controlled grain sprouting, drying and cracking as abstract malting jobs; no real brewing specification. |
| `COMPONENT_shared_maple` | shared / maple | maple syrup | Use prepared maple syrup as the game interpretation of unspecified maple flavor. |
| `COMPONENT_shared_maple_oat_cream` | shared / maple oat cream | maple syrup, oat cream | Whisk prepared maple syrup into oat cream and cool. |
| `COMPONENT_shared_maple_sauce` | shared / maple sauce | maple syrup, oat cream | Warm maple syrup with oat cream and stir into a pourable dessert sauce. |
| `COMPONENT_shared_maple_sponge` | shared / maple sponge | wheat flour, oat drink, hazelnut oil, maple syrup, yeast | Mix maple-sweetened batter, proof with game yeast and bake into sponge. |
| `COMPONENT_shared_maple_syrup` | shared / maple syrup | cultivated game maple sap | Reduce the fictional cultivated maple-sap ingredient into game syrup. |
| `COMPONENT_shared_marchpane` | shared / marchpane | almond flour, honeycomb, chestnut flour | Mix almond flour, stiff comb honey and chestnut flour; press into a sheet or shape small balls. This shared ingredient preparation is game-authoring interpretation of the separate source-led variants. |
| `COMPONENT_shared_mashed_turnip` | shared / mashed turnip | turnip, water | Cook turnip in water, drain and mash. |
| `COMPONENT_shared_melon_and_peach` | shared / melon and peach | melon, peach | Prepare each listed game ingredient separately, then combine as the named mixture. |
| `COMPONENT_shared_mint_oat_cream` | shared / mint oat cream | mint, oat cream | Steep mint in warm oat cream, strain and cool. |
| `COMPONENT_shared_mint_tea` | shared / mint tea | mint, water | Infuse mint in water and strain; serving temperature is a separate food state. |
| `COMPONENT_shared_mushroom_stock` | shared / mushroom stock | mushroom, onion, water | Simmer mushroom and onion in water, then strain into cooking stock. |
| `COMPONENT_shared_oat_and_seed_cheese` | shared / oat and seed cheese | oats, sunflower seed, water, apple vinegar, salt | Grind softened oats and seeds, add vinegar and salt, then drain and press into game cheese. |
| `COMPONENT_shared_oat_and_seed_curd` | shared / oat and seed curd | oats, sunflower seed, water, apple vinegar | Grind softened oats and seeds, add vinegar, then drain into a soft game curd. |
| `COMPONENT_shared_oat_bread` | shared / oat bread | oat flour, water, bread starter, salt | Mix oat dough with starter, proof, shape and bake. |
| `COMPONENT_shared_oat_cake` | shared / oat cake | oat flour, water, hazelnut oil, salt | Mix a stiff oat dough, shape thin rounds and griddle. |
| `COMPONENT_shared_oat_cream` | shared / oat cream | oat drink, hazelnut paste | Blend oat drink with hazelnut paste into a spoonable game cream. |
| `COMPONENT_shared_oat_custard` | shared / oat custard | oat drink, arrowroot starch, honey | Disperse arrowroot starch in cold oat drink, heat while stirring and add honey; cool to a spoonable game custard. |
| `COMPONENT_shared_oat_drink` | shared / oat drink | oats, water | Soak oats in water, grind and strain into a pourable game drink. |
| `COMPONENT_shared_oat_flour` | shared / oat flour | oats | Clean the game oats, dry if needed and mill into flour. |
| `COMPONENT_shared_oat_vanilla_sauce` | shared / oat-vanilla sauce | oat drink, arrowroot starch, honey, vanilla | Heat oat drink with vanilla and honey, thicken lightly with arrowroot and strain. |
| `COMPONENT_shared_oatmeal` | shared / oatmeal | oats | Clean and roll or coarsely mill oats into the selected game oatmeal state. |
| `COMPONENT_shared_oatmeal_scone` | shared / oatmeal scone | oat flour, oat drink, hazelnut oil, honey, bread starter | Mix soft oat dough, form small rounds, proof and bake. |
| `COMPONENT_shared_october_ale` | shared / october ale | malted barley, water, fermentation culture | Mash game malted barley, strain and apply abstract fermentation and cellar-conditioning jobs. This default does not silently inherit every ingredient from another book’s specific brewing song. |
| `COMPONENT_shared_old_cider` | shared / old cider | apple, fermentation culture | Press and ferment apple juice, then apply cellar conditioning to the old-cider game state. No narrative age becomes a production time. |
| `COMPONENT_shared_onion_gravy` | shared / onion gravy | onion, mushroom stock, barley flour, hazelnut oil | Soften onion in hazelnut oil, add stock, stir in barley flour and heat into thick gravy. |
| `COMPONENT_shared_onion_sauce` | shared / onion sauce | onion, mushroom stock, barley flour | Cook onion in stock, thicken with barley flour and strain into a game sauce. |
| `COMPONENT_shared_pale_cider` | shared / pale cider | apple, fermentation culture | Press apples, strain the juice and apply the abstract game fermentation job. |
| `COMPONENT_shared_pancake` | shared / pancake | wheat flour, oat drink, hazelnut oil | Mix a pourable batter and cook thin rounds on a griddle. |
| `COMPONENT_shared_pitted_cherry` | shared / pitted cherry | cherry | Prepare the game cherry and remove the pit; retain edible fruit as a separate ingredient state. |
| `COMPONENT_shared_pitted_damson` | shared / pitted damson | damson | Prepare the game damson and remove the pit; retain edible fruit as a separate ingredient state. |
| `COMPONENT_shared_pitted_greengage` | shared / pitted greengage | greengage | Prepare the game greengage and remove the pit; retain edible fruit as a separate ingredient state. |
| `COMPONENT_shared_pitted_plum` | shared / pitted plum | plum | Prepare the game plum and remove the pit; retain edible fruit as a separate ingredient state. |
| `COMPONENT_shared_plant_oil_dumpling_dough` | shared / plant-oil dumpling dough | wheat flour, oat drink, hazelnut oil | Mix flour, oat drink and oil into soft dumpling dough. |
| `COMPONENT_shared_plant_oil_honey_sponge` | shared / plant-oil honey sponge | wheat sponge, honey | Brush prepared game wheat sponge with honey and let it absorb. |
| `COMPONENT_shared_plant_oil_pastry` | shared / plant-oil pastry | wheat flour, water, hazelnut oil, salt | Rub oil into flour and salt, add water, knead briefly and roll into a pastry sheet. |
| `COMPONENT_shared_plum_preserve` | shared / plum preserve | plum, honey, water, apple pectin | Cook prepared plums with honey, water and apple pectin into a game preserve; no real storage claim. |
| `COMPONENT_shared_prepared_beechnut` | shared / prepared beechnut | beechnut | Use the shelled, preprocessed culinary game nut state; real-world processing or safety parameters are not specified. |
| `COMPONENT_shared_prepared_cabbage_leaf` | shared / prepared cabbage leaf | cabbage, water | Separate whole edible cabbage leaves, soften them in water and drain for wrapping a game filling. |
| `COMPONENT_shared_prepared_cultivated_burdock_root` | shared / prepared cultivated burdock root | burdock | Use the trimmed and prepared root form of the cultivated game burdock asset; this does not identify a source wild root. |
| `COMPONENT_shared_prepared_hazelnut` | shared / prepared hazelnut | hazelnut | Remove the hazelnut shell and separate the edible game kernel as a prepared input. |
| `COMPONENT_shared_prepared_mussel` | shared / prepared mussel | mussel | Use the cleaned and portioned edible game mussel state, separated from shell material; no real preservation parameters. |
| `COMPONENT_shared_prepared_onion_layer` | shared / prepared onion layer | onion | Remove the dry outer onion covering and separate intact edible onion layers as game wrappers. This authored state interprets the source skin phrase without asserting that dry skins are an edible wrapper. |
| `COMPONENT_shared_prepared_rosehip` | shared / prepared rosehip | rosehip | Prepare game rosehip pulp separately from its nonfood seed and hair fractions. |
| `COMPONENT_shared_prepared_sweet_chestnut` | shared / prepared sweet chestnut | sweet chestnut | Prepare the edible game sweet-chestnut kernels separately from shells; never substitute horse chestnuts. |
| `COMPONENT_shared_processed_acorn_puree` | shared / processed acorn puree | processed acorn meal, water | Mix already processed edible game acorn meal with water and heat to a smooth puree; no raw-acorn detoxification procedure is specified. |
| `COMPONENT_shared_quince_jam` | shared / quince jam | quince, honey, water, apple pectin | Cook the prepared quince with honey, water and apple pectin into a game preserve; no real canning or shelf-life claim. |
| `COMPONENT_shared_raisin` | shared / raisin | grape | Prepare grapes and use the game drying-rack job to make raisins. |
| `COMPONENT_shared_raspberry_preserve` | shared / raspberry preserve | raspberry, honey, water, apple pectin | Cook the prepared raspberry with honey, water and apple pectin into a game preserve; no real canning or shelf-life claim. |
| `COMPONENT_shared_red_grape_wine` | shared / red grape wine | red grape, water, honey, fermentation culture | Prepare the selected red grape base, strain with water, add honey and use abstract game fermentation and cellar-conditioning jobs. |
| `COMPONENT_shared_rhubarb_juice` | shared / rhubarb juice | rhubarb, water | Prepare, crush or steep the game rhubarb, then strain with water into juice. Botanical identity is the selected game ingredient. |
| `COMPONENT_shared_roasted_almonds` | shared / roasted almonds | almond | Dry-roast shelled almonds and cool. |
| `COMPONENT_shared_roasted_chestnut` | shared / roasted chestnut | chestnut | Roast prepared edible chestnuts and remove shells. |
| `COMPONENT_shared_roasted_malted_barley` | shared / roasted malted barley | malted barley | Roast prepared game malt into a darker grain state. |
| `COMPONENT_shared_roasted_woodland_mushrooms` | shared / roasted woodland mushrooms | mushroom, hazelnut oil | Coat cultivated game mushrooms in oil and roast. |
| `COMPONENT_shared_rose_oat_cream` | shared / rose oat cream | cultivated game rose petals, oat cream, honey | Steep the fictional cultivated rose petals in warm oat cream, strain, sweeten with honey and cool. |
| `COMPONENT_shared_rosehip_vinegar` | shared / rosehip vinegar | prepared rosehip, water, honey, fermentation culture, vinegar culture | Press prepared rosehip pulp with water, add honey and the fermentation culture, then run a separate vinegar-culture game job; strain the finished game vinegar. No durations or acidity values are asserted. |
| `COMPONENT_shared_rye_bread` | shared / rye bread | rye flour, water, bread starter, salt | Mix rye dough with starter, proof, shape and bake. |
| `COMPONENT_shared_rye_flour` | shared / rye flour | rye | Clean the game rye, dry if needed and mill into flour. |
| `COMPONENT_shared_savory_herb_sauce` | shared / savory herb sauce | mushroom stock, thyme, parsley, barley flour | Heat stock with thyme and parsley, thicken with barley flour and strain. |
| `COMPONENT_shared_scone` | shared / scone | wheat flour, oat drink, hazelnut oil, honey, bread starter | Mix soft dough, form small rounds, proof and bake. |
| `COMPONENT_shared_selected_berry_mix` | shared / selected berry mix | blackberry, raspberry | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_selected_cultivated_greens` | shared / selected cultivated greens | lettuce, watercress | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_selected_flour` | shared / selected flour | wheat flour | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_selected_fruit_mix` | shared / selected fruit mix | apple, plum | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_selected_grain_mix` | shared / selected grain mix | oats, barley | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_selected_herb_mix` | shared / selected herb mix | thyme, mint | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_selected_nut_meal` | shared / selected nut meal | hazelnut meal, almond flour | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_selected_nut_mix` | shared / selected nut mix | hazelnut, almond | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_selected_root_mix` | shared / selected root mix | carrot, turnip | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_selected_seed_mix` | shared / selected seed mix | sunflower seed, pumpkin seed | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_selected_spice_mix` | shared / selected spice mix | cinnamon, clove | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_selected_vegetable_mix` | shared / selected vegetable mix | carrot, turnip, leek | Use exactly these selected game ingredients to replace the unresolved literary category. The named choices are AI-authored; the source category remains unexpanded in canonical evidence. |
| `COMPONENT_shared_ship_s_biscuit` | shared / ship's biscuit | wheat flour, water, salt | Mix stiff dough, flatten, pierce and bake into a dry game ship biscuit; no storage-life claim. |
| `COMPONENT_shared_shortbread_biscuit` | shared / shortbread biscuit | wheat flour, hazelnut oil, honey | Rub oil into flour, add honey, form small flat biscuits and bake. |
| `COMPONENT_shared_shrewbread` | shared / shrewbread | wholemeal wheat flour, water, bread starter, salt, hazelnut | Mix wholemeal dough with hazelnuts, proof, shape and bake; nut choice is authored. |
| `COMPONENT_shared_soured_oat_drink` | shared / soured oat drink | oat drink, apple vinegar | Stir the authored apple vinegar into oat drink to represent a sour plant drink. |
| `COMPONENT_shared_stale_bread` | shared / stale bread | bread | Represent a stored firm bread state for reuse in game recipes; no real spoilage or safety claim. |
| `COMPONENT_shared_stale_rye_bread` | shared / stale rye bread | rye bread | Represent a stored firm rye-bread state for reuse in game recipes; no real spoilage or safety claim. |
| `COMPONENT_shared_strawberry_jam` | shared / strawberry jam | strawberry, honey, water, apple pectin | Cook the prepared strawberry with honey, water and apple pectin into a game preserve; no real canning or shelf-life claim. |
| `COMPONENT_shared_strawberry_preserve` | shared / strawberry preserve | strawberry, honey, water, apple pectin | Cook the prepared strawberry with honey, water and apple pectin into a game preserve; no real canning or shelf-life claim. |
| `COMPONENT_shared_sugar` | shared / sugar | sugar beet | Represent washing, slicing, juice extraction, clarification and crystallization of sugar beet as abstract game processing states. |
| `COMPONENT_shared_sugar_syrup` | shared / sugar syrup | beet sugar, water | Dissolve beet sugar in water and represent a thickened game syrup. |
| `COMPONENT_shared_sunflower_oil` | shared / sunflower oil | sunflower seed | Clean and press game sunflower seeds, then strain the oil. |
| `COMPONENT_shared_sweet_arrowroot_sauce` | shared / sweet arrowroot sauce | oat drink, arrowroot starch, honey, water | Stir diluted arrowroot into oat drink and honey, then heat into a pourable game dessert sauce. |
| `COMPONENT_shared_thick_oat_cream` | shared / thick oat cream | oat cream | Concentrate the prepared game oat cream to a thicker spoonable state. |
| `COMPONENT_shared_trout_fry` | shared / trout fry | trout | Use small approved game trout as this explicitly authored ingredient state; population age and catch policy remain separate specifications. |
| `COMPONENT_shared_trout_pieces` | shared / trout pieces | trout | Prepare an approved game trout and cut into portions. |
| `COMPONENT_shared_unsweetened_oat_custard` | shared / unsweetened oat custard | oat drink, arrowroot starch | Disperse arrowroot starch in oat drink and heat while stirring to a savory binding cream. |
| `COMPONENT_shared_vegetable_oil` | shared / vegetable oil | sunflower oil | Select sunflower oil as the explicitly authored crop source for generic vegetable oil. |
| `COMPONENT_shared_vegetable_sausage` | shared / vegetable sausage | barley, oats, carrot, mushroom, prepared onion layer | Grind barley and oats, finely chop carrot and mushroom and combine them into a moist filling. Enclose the filling in prepared edible onion layers and bake the parcels. This game component follows the declared Didjety game selection; grain form and edible onion-layer interpretation are authored choices. |
| `COMPONENT_shared_violet_flavoured_sugar` | shared / violet-flavoured sugar | cultivated game violet petals, beet sugar | Represent game violet-petal flavor infused into beet sugar; the cultivated game asset supplies identity. |
| `COMPONENT_shared_wheat_cake` | shared / wheat cake | wheat flour, oat drink, hazelnut oil, honey, bread starter | Mix wheat flour, oat drink, hazelnut oil, honey and the selected starter into a sweet batter, allow its game proofing stage, bake and cool before cutting into trifle pieces. |
| `COMPONENT_shared_wheat_flour` | shared / wheat flour | wheat | Clean the game wheat, dry if needed and mill into flour. |
| `COMPONENT_shared_wheat_sponge` | shared / wheat sponge | wheat flour, oat drink, hazelnut oil, honey, yeast | Mix sweet batter with the game yeast leavening, proof briefly and bake into sponge. |
| `COMPONENT_shared_white_gooseberry_wine` | shared / white gooseberry wine | white gooseberry, water, honey, fermentation culture | Prepare the selected white gooseberry base, strain with water, add honey and use abstract game fermentation and cellar-conditioning jobs. |
| `COMPONENT_shared_wholegrain_oat_flour` | shared / wholegrain oat flour | oats | Mill whole oat grain into flour without separating its game bran fraction. |
| `COMPONENT_shared_wholemeal_bread` | shared / wholemeal bread | wholemeal wheat flour, water, bread starter, salt | Mix wholemeal dough, proof, shape and bake. |
| `COMPONENT_shared_wholemeal_wheat_flour` | shared / wholemeal wheat flour | wheat | Mill whole wheat grain into wholemeal flour without separating bran. |
| `COMPONENT_shared_withered_field_mushrooms` | shared / withered field mushrooms | mushroom | Use deliberately dried cultivated game mushrooms; the shared game version changes the source condition rather than endorsing spoiled food. |

## Owner correction register

The shared game resolution is explicit; the original book data remains unchanged until its owner corrects it. Entries can concern terminology or preparation consistency without changing any canonical evidence.

| Issue | Book / reference | Finding | Shared game resolution |
|---|---|---|---|

## Local greensap plant-origin evidence

These book-qualified records support the specific Outcast preparation, not a universal origin for all milk or cheese. Unknown grass and tuber identities are not converted into real edible species.

| Record | Source blocks | Local claim |
|---|---|---|
| `outcast:OUT_food_lully_and_skarlath_s_plant_cheese` | 434–437 | Source food/discourse reference. Form: plant_cheese. Occurrence: PREPARATION_DESCRIBED. Explicit named components: greensap milk, grass stem, special tubers, hazelnut, almond, chestnut. |
| `outcast:OUT_ingredient_fat_white_grass_stem` | 434–437 | Component of Greensap milk from white grass stems and tubers. Occurrence: PREPARATION_DESCRIBED |
| `outcast:OUT_ingredient_special_tubers` | 434–437 | Component of Greensap milk from white grass stems and tubers. Occurrence: PREPARATION_DESCRIBED |
| `outcast:OUT_system_plant_cheese_production` | 434–437 | Canon explicitly provides plant milk, tubers and nut cheese; prevents unsupported inference every cheese implies dairy livestock. |
| `outcast:OUT_note_02_food_ingredients_prep` | 199–442 | Dandelion-burdock cordial dark/sweet/cool in pottery jug (246), later Blunn brew stored submerged stream flagons (431). Young onion-leek soup; hot brown bread with beechnut paste; woodland salad; apple-greengage crumble with honey (258). Bowfleg actually eats roasted thrush (302). Gift wine explicitly elderberry/plum dark sweet old southland wine, age claimed by Swartt; Wurgg/Bowfleg consume but POISON ON CUP, not wine (322–398). Garden leek,onion,potato,turnip,peas,cabbage; plum/apple/pear trees, horse chestnuts nearby; later redcurrant/blackberry/raspberry/strawberry expected; button mushrooms (412–420). Horse chestnut presence does NOT prove edible chestnut identity. Apple-blackberry pie; summer salad,new cheese,oatfarls (427–439). IMPORTANT cheese434 explicitly plant-derived greensap milk from pounded fat white grass stems and unspecified special tubers, plus hazel/almond/chestnut; autumn gathering, winter maturation, damp crack-willow bark protective wrap, no rind,pale yellow,almond scent; greased twine cuts oval slices (434–438). No exact species for grass/tubers or quantities; don't replace this with unsupported dairy claim. |
| `outcast:OUT_note_02_ecology` | 199–442 | Lilac leaves repurposed signal; bird relay communication claimed across land. Food garden uses existing fruit canopy,removed rocks/bush,straight furrows and shaded mushroom niche. Explicit horse chestnuts distinct from nuts gathered for cheese; source doesn't identify gathered chestnuts botanically. Cheese grass/tubers unknown plants, not milk-producing livestock. Stream cooling seasonally available. Seasons advance from rescue spring through autumn and another spring/summer; maturation measured relative seasons, not days. |
| `outcast:OUT_note_02_occupation_knowledge` | 199–442 | Family teaches farming,growing,cheesemaking,cordial brewing,oven building,storage and music. Skarlath contributes tireless stem/tuber pounding and nut gathering, undermining predator-only worker assignment (434). Lully cuts cheese using tensioned twine and braced feet, skilled process suitable animation. Elder Blunn productive brewer, Ummer musician/baker. Signal literacy allows households to request help, though range claim uncertain. Swartt exploits investigation's incorrect wine assumption and performative authority rather than genuine magic. |
| `outcast:OUT_note_02_uncertainty_adaptation` | 199–442 | Source gives false supernatural coup explicitly; don't mislabel all Nightshade forecasts as fact. Poison container distinct from safe wine; no poison recipe included. Cheese plant origin is certain here, exact grass/tuber species unresolved. Horse chestnut should remain ecological nonfood record unless explicit edible use elsewhere. Dream ancestry and anagram song unresolved. Captive humiliation,child food deprivation and physical punishment conflict with user boundary. No numeric recipe/maturation/range balance inferred. |

## Searchable source ingredient index

Full occurrence evidence and book-qualified references are in `pantry.json`. This compact directory preserves original source terms without declaring botanical or recipe equivalence.

| Source term | Occurrences | Books |
|---|---:|---|
| acorn | 18 | martin_warrior, mossflower, outcast, pearls_lutra, redwall, salamandastron |
| acorn puree | 1 | redwall |
| acorns | 1 | triss |
| ale | 8 | outcast, taggerung |
| almond | 32 | long_patrol, lord_brocktree, marlfox, outcast, pearls_lutra, rakkety_tam, taggerung, triss |
| almond flour | 2 | long_patrol |
| almond flower | 2 | taggerung |
| almond icing | 2 | rakkety_tam |
| almond oil | 2 | rakkety_tam |
| almond paste | 2 | salamandastron |
| almonds | 3 | pearls_lutra |
| angelica leaves | 2 | pearls_lutra |
| apple | 118 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| apple orchard fruit | 1 | taggerung |
| apple turnover | 2 | salamandastron |
| arrowhead | 2 | mossflower |
| arrowroot | 11 | lord_brocktree, outcast, rakkety_tam, salamandastron |
| arrowroot custard | 2 | marlfox |
| arrowroot flour | 2 | salamandastron |
| arrowroot sauce | 2 | marlfox |
| arrowroot shortbread | 2 | salamandastron |
| bankvole | 2 | outcast |
| barbel | 2 | marlfox |
| barley | 39 | long_patrol, lord_brocktree, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, taggerung, triss |
| barley bread | 2 | taggerung |
| barley flour | 4 | marlfox, triss |
| barley meal | 2 | long_patrol |
| barley pearls | 1 | redwall |
| barley toast | 2 | taggerung |
| barleymeal | 2 | pearls_lutra |
| barnacles | 2 | pearls_lutra |
| basil thyme | 2 | lord_brocktree |
| bean | 4 | martin_warrior, mossflower |
| beans and winter greens | 1 | triss |
| bee | 2 | salamandastron |
| beech nut | 2 | taggerung |
| beech nuts | 2 | lord_brocktree |
| beechnut | 16 | marlfox, martin_warrior, mossflower, outcast, redwall, salamandastron |
| beechnut paste | 2 | outcast |
| beechnuts | 3 | pearls_lutra, redwall |
| beeswax tallow | 2 | triss |
| beet | 2 | long_patrol |
| beetle | 1 | long_patrol |
| beetroot | 29 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, salamandastron, taggerung, triss |
| beige cheese | 2 | salamandastron |
| berries | 17 | long_patrol, lord_brocktree, marlfox, martin_warrior, redwall, taggerung |
| berries unspecified | 2 | mossflower |
| berry | 3 | rakkety_tam |
| bilberry | 15 | lord_brocktree, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung |
| bilberry seasonal reference | 1 | taggerung |
| bindweed flower | 2 | taggerung |
| bird | 6 | marlfox, pearls_lutra, rakkety_tam |
| bird egg | 4 | rakkety_tam, taggerung |
| bird wing | 2 | pearls_lutra |
| birds | 2 | long_patrol |
| bitter saxifrage | 1 | lord_brocktree |
| black treacle | 2 | salamandastron |
| blackberries | 2 | pearls_lutra |
| blackberry | 58 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| blackberry cream | 2 | salamandastron |
| blackberry fruit | 1 | taggerung |
| blackberry jam | 4 | marlfox, outcast |
| blackberry jelly | 2 | marlfox |
| blackberry preserve | 2 | triss |
| blackberry tart | 2 | salamandastron |
| blackberry wine | 2 | taggerung |
| blackcurrant | 25 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, pearls_lutra, redwall, salamandastron, triss |
| blossom petals | 2 | martin_warrior |
| blueberry | 7 | marlfox, triss |
| borage | 2 | outcast |
| brackish water | 2 | outcast |
| bread | 24 | long_patrol, lord_brocktree, marlfox, mossflower, outcast, salamandastron, taggerung |
| bream | 2 | mossflower |
| broken biscuit | 2 | mossflower |
| brooklime | 2 | pearls_lutra |
| brown bread | 4 | outcast, salamandastron |
| brown onion gravy | 2 | martin_warrior |
| bulrush | 10 | lord_brocktree, martin_warrior, mossflower, salamandastron |
| bulrush tips | 2 | marlfox |
| burbot | 2 | taggerung |
| burdock | 24 | long_patrol, lord_brocktree, marlfox, martin_warrior, outcast, pearls_lutra, salamandastron, taggerung, triss |
| burdock stalks | 2 | marlfox |
| butter | 5 | mossflower |
| buttercream | 2 | salamandastron |
| buttercup | 7 | long_patrol, lord_brocktree, martin_warrior |
| buttercup cream | 3 | salamandastron |
| buttercup fondant | 2 | salamandastron |
| buttercup spread | 2 | martin_warrior |
| butterfish | 2 | martin_warrior |
| buttermilk | 2 | mossflower |
| butterwort | 2 | lord_brocktree |
| button mushroom | 9 | long_patrol, martin_warrior, outcast, taggerung |
| cabbage | 16 | marlfox, martin_warrior, outcast, rakkety_tam, redwall, salamandastron, taggerung, triss |
| cabbage stalk | 1 | redwall |
| cabbage-fennel bake | 2 | taggerung |
| caddisworm | 2 | outcast |
| cake | 2 | long_patrol |
| candied angelica leaves | 2 | pearls_lutra |
| candied chestnut | 11 | outcast, salamandastron, triss |
| candied chestnuts | 2 | pearls_lutra |
| candied fruit | 4 | marlfox, outcast |
| candied mintleaves | 2 | martin_warrior |
| candied nuts | 2 | martin_warrior |
| candied strawberry | 2 | taggerung |
| caravan lettuce crop | 1 | triss |
| carrot | 57 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| carrot juice | 2 | taggerung |
| cauliflower | 3 | rakkety_tam |
| caveshrimp | 2 | outcast |
| celery | 45 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, pearls_lutra, rakkety_tam, salamandastron, taggerung, triss |
| chamomile | 2 | outcast |
| charlock | 2 | lord_brocktree |
| charlock pod | 2 | rakkety_tam |
| cheese | 78 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| cheese; underlying dairy input not specified | 1 | mossflower |
| cherry | 14 | long_patrol, lord_brocktree, martin_warrior, rakkety_tam, salamandastron |
| cherry conserve | 2 | outcast |
| cherry juice | 2 | taggerung |
| cherry preserve | 2 | pearls_lutra |
| chestnut | 64 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| chestnut sauce | 3 | lord_brocktree |
| chestnuts | 4 | pearls_lutra |
| chicory | 2 | lord_brocktree |
| chive | 4 | pearls_lutra, taggerung |
| chopped berries | 2 | taggerung |
| chopped chestnut | 3 | marlfox |
| chub | 2 | outcast |
| cider | 6 | lord_brocktree, outcast |
| clear honey | 4 | pearls_lutra, triss |
| clotted meadowcream | 3 | marlfox |
| cloud | 2 | outcast |
| clover | 2 | mossflower |
| clover honey | 2 | taggerung |
| cockle | 4 | martin_warrior, pearls_lutra |
| cockleshell | 2 | pearls_lutra |
| cold water | 4 | outcast, triss |
| coltsfoot | 4 | pearls_lutra, rakkety_tam |
| coltsfoot root | 2 | triss |
| comb honey | 3 | salamandastron |
| comfrey | 15 | long_patrol, lord_brocktree, marlfox, rakkety_tam, taggerung, triss |
| comfrey root | 2 | taggerung |
| cooked apple | 2 | rakkety_tam |
| coot egg | 2 | triss |
| cordial | 2 | outcast |
| corn | 4 | long_patrol, lord_brocktree |
| corn flour | 2 | triss |
| cornflour | 2 | lord_brocktree |
| cornflower butter | 2 | salamandastron |
| cornmeal | 2 | taggerung |
| cornsalad | 1 | taggerung |
| cosmetic rosewater | 1 | rakkety_tam |
| cow parsley | 2 | mossflower |
| cowslip | 6 | lord_brocktree, outcast, salamandastron |
| crabapple | 4 | martin_warrior, triss |
| cranberry | 5 | lord_brocktree |
| cream | 42 | long_patrol, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| cress | 9 | marlfox, mossflower, pearls_lutra, redwall, taggerung |
| crow | 4 | outcast, rakkety_tam |
| crowberry | 2 | lord_brocktree |
| crumble | 2 | triss |
| crushed oats | 2 | lord_brocktree |
| crystallized fruit | 4 | outcast, pearls_lutra |
| crystallized plum | 2 | marlfox |
| crystallized young maple leaves | 2 | salamandastron |
| cuckoo-flower petals | 2 | lord_brocktree |
| cucumber | 5 | martin_warrior, taggerung, triss |
| curds | 2 | long_patrol |
| curled dock leaf medicinal reference | 1 | rakkety_tam |
| curlew | 2 | rakkety_tam |
| currant | 2 | mossflower |
| custard | 6 | lord_brocktree, martin_warrior, salamandastron |
| dace | 6 | lord_brocktree, outcast, taggerung |
| daisy | 4 | martin_warrior, outcast |
| daisy balm of the monologue | 1 | rakkety_tam |
| daisy bud | 2 | rakkety_tam |
| damson | 56 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| damson cream | 2 | salamandastron |
| damson fruit | 1 | taggerung |
| damson jam | 2 | marlfox |
| damson juice | 4 | pearls_lutra, triss |
| damson preserve | 2 | outcast |
| damson wine | 2 | marlfox |
| damsons | 2 | pearls_lutra |
| dandelion | 56 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, redwall, salamandastron, taggerung, triss |
| dandelion and burdock cordial | 2 | outcast |
| dandelion bud | 2 | rakkety_tam |
| dandelion buds | 4 | marlfox, redwall, taggerung |
| dandelion fizz | 3 | outcast |
| dandelion flower | 2 | long_patrol |
| dandelion juice | 2 | taggerung |
| dandelion leaf | 2 | taggerung |
| dandelion leaves | 1 | redwall |
| dandelion petals | 2 | martin_warrior |
| dandelion root | 6 | rakkety_tam, salamandastron, taggerung |
| dandelion roots | 2 | lord_brocktree |
| dandelion shoots | 2 | lord_brocktree |
| dandelion stalks | 2 | marlfox |
| dandelion tuber | 2 | salamandastron |
| dandelion wine | 2 | taggerung |
| dannyline | 2 | marlfox |
| dark elderberry wine | 2 | pearls_lutra |
| dark gravy | 2 | outcast |
| dead frog | 2 | outcast |
| dead grass | 2 | outcast |
| ditchnettle pepper | 2 | mossflower |
| ditchwater | 2 | outcast |
| dock | 2 | taggerung |
| dock leaf | 2 | rakkety_tam |
| dock leaves | 1 | long_patrol |
| dove | 4 | rakkety_tam, taggerung |
| dove egg | 2 | taggerung |
| dragonfly | 4 | lord_brocktree, salamandastron |
| dried apple rings | 4 | outcast, pearls_lutra |
| dried burnet rose hips | 2 | marlfox |
| dried fish | 2 | pearls_lutra |
| dried fruit | 7 | lord_brocktree, outcast, taggerung |
| dried mint | 2 | pearls_lutra |
| dried plum | 2 | salamandastron |
| dried plums | 2 | pearls_lutra |
| dried shrimp | 2 | mossflower |
| dried watershrimp | 8 | marlfox, outcast, pearls_lutra |
| drop-water parsley | 2 | triss |
| duck | 2 | outcast |
| dumpling | 2 | salamandastron |
| dumplings | 2 | long_patrol |
| early plum | 2 | triss |
| edible roots | 2 | outcast |
| egg | 2 | redwall |
| elder bark | 2 | triss |
| elderberry | 36 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| elderberry jam | 2 | salamandastron |
| elderberry wine | 2 | marlfox |
| elderflower | 8 | long_patrol, lord_brocktree, marlfox |
| elver | 6 | taggerung |
| fat white grass stem | 2 | outcast |
| fawn cake | 2 | outcast |
| fennel | 13 | mossflower, outcast, redwall, salamandastron, taggerung, triss |
| fennel leaf | 1 | salamandastron |
| feverfew | 2 | triss |
| fish | 21 | long_patrol, lord_brocktree, marlfox, martin_warrior, pearls_lutra, rakkety_tam, taggerung, triss |
| fish and vegetable beacon oil | 1 | triss |
| fish guts | 2 | pearls_lutra |
| fish unspecified | 3 | mossflower |
| flaked almond | 5 | salamandastron, taggerung |
| flaked almonds | 2 | pearls_lutra |
| flour | 9 | mossflower, pearls_lutra, salamandastron, taggerung, triss |
| flower syrup | 2 | salamandastron |
| fresh flowers | 1 | redwall |
| fresh spring water | 1 | mossflower |
| fresh springwater | 1 | salamandastron |
| freshwater mussel | 1 | long_patrol |
| freshwater shrimp | 5 | long_patrol, mossflower, taggerung |
| frog | 9 | marlfox, outcast, salamandastron, taggerung |
| frogspawn | 3 | long_patrol |
| fruit | 66 | long_patrol, lord_brocktree, marlfox, martin_warrior, outcast, pearls_lutra, rakkety_tam, redwall, taggerung, triss |
| fruit cordial | 2 | outcast |
| fruit juice | 2 | rakkety_tam |
| fruit unspecified | 6 | mossflower |
| fruitcake | 2 | outcast |
| fruitcream | 2 | salamandastron |
| gentian root | 2 | rakkety_tam |
| gentian stems | 1 | long_patrol |
| glazed maple shoots | 2 | salamandastron |
| gnat | 2 | salamandastron |
| goat milk | 4 | redwall |
| golden honey | 1 | mossflower |
| gooseberries | 1 | triss |
| gooseberry | 19 | long_patrol, lord_brocktree, marlfox, outcast, pearls_lutra, rakkety_tam, salamandastron |
| gooseberry jelly | 2 | outcast |
| gooseberry preserve | 2 | martin_warrior |
| grain | 3 | triss |
| grain flour | 1 | mossflower |
| grape | 3 | marlfox |
| grass | 4 | marlfox, outcast |
| grass stem | 2 | outcast |
| gravy | 13 | long_patrol, marlfox, outcast, pearls_lutra, taggerung |
| grayling | 8 | lord_brocktree, marlfox, pearls_lutra, redwall |
| green acorn | 2 | martin_warrior |
| green apple | 4 | outcast, salamandastron |
| green hazelnut | 2 | triss |
| green nettle | 2 | martin_warrior |
| green sap | 2 | taggerung |
| green sap milk | 2 | triss |
| green twigs | 2 | outcast |
| greengage | 12 | lord_brocktree, marlfox, martin_warrior, outcast, pearls_lutra |
| greengage preserve | 2 | rakkety_tam |
| greensap | 1 | long_patrol |
| greensap cream | 2 | salamandastron |
| greensap milk | 16 | long_patrol, marlfox, outcast, pearls_lutra, salamandastron |
| grog | 3 | long_patrol |
| ground almonds | 2 | pearls_lutra |
| ground corn | 2 | taggerung |
| grubs | 2 | pearls_lutra |
| gudgeon | 2 | long_patrol |
| gull | 2 | martin_warrior |
| guosim cheese | 2 | rakkety_tam |
| hard cheese | 2 | marlfox |
| harebell | 2 | lord_brocktree |
| hazelnut | 72 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| hazelnut forage | 1 | taggerung |
| hazelnut truffle | 2 | salamandastron |
| hazelnuts | 2 | pearls_lutra |
| heather honey | 2 | taggerung |
| hedge mustard | 2 | rakkety_tam |
| hedge parsley | 2 | lord_brocktree |
| herb | 3 | rakkety_tam |
| herb gravy | 2 | long_patrol |
| herbs | 18 | long_patrol, marlfox, martin_warrior, outcast, pearls_lutra, redwall, taggerung |
| herbs unspecified | 2 | mossflower |
| herring | 5 | martin_warrior, triss |
| hodgepodge pie | 2 | marlfox |
| honey | 128 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| honey flan | 2 | salamandastron |
| honey sponge | 2 | marlfox |
| honey-preserved damson | 2 | triss |
| honey-preserved rose petals | 3 | pearls_lutra |
| honeycomb | 7 | outcast, taggerung, triss |
| honeycream | 4 | outcast, salamandastron |
| hops | 2 | long_patrol |
| horse chestnut | 4 | long_patrol, outcast |
| hot bread | 2 | taggerung |
| hot mint tea | 2 | taggerung |
| hot root unspecified | 2 | mossflower |
| hotroot | 25 | long_patrol, lord_brocktree, martin_warrior, outcast, pearls_lutra, salamandastron, taggerung, triss |
| hotroot optional sea-stew seasoning | 1 | triss |
| hotroot pepper | 13 | marlfox, martin_warrior, outcast, rakkety_tam, taggerung |
| hotroot soup | 2 | taggerung |
| insects | 2 | outcast |
| juniper | 2 | triss |
| kelp | 2 | martin_warrior |
| kingcup cream | 2 | salamandastron |
| lamb's lettuce | 2 | lord_brocktree |
| lavender | 3 | martin_warrior |
| leek | 58 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, salamandastron, taggerung, triss |
| lettuce | 11 | lord_brocktree, marlfox, pearls_lutra, redwall, taggerung, triss |
| lightning | 2 | outcast |
| lilac | 2 | salamandastron |
| lilac buds | 2 | lord_brocktree |
| limpet | 4 | mossflower, salamandastron |
| lizard | 2 | taggerung |
| loaf | 2 | lord_brocktree |
| lobster | 6 | lord_brocktree, martin_warrior, pearls_lutra |
| mackerel | 10 | lord_brocktree, martin_warrior, outcast, taggerung |
| magpie | 2 | rakkety_tam |
| maize | 3 | marlfox |
| maize flour | 2 | marlfox |
| maple | 18 | long_patrol, lord_brocktree, martin_warrior, pearls_lutra, salamandastron, taggerung |
| maple sap | 1 | triss |
| maple sauce | 2 | lord_brocktree |
| maple smoke | 1 | long_patrol |
| maple sponge | 2 | triss |
| maple syrup | 5 | marlfox, outcast |
| maple tips | 2 | outcast |
| maple tree product unspecified | 1 | mossflower |
| maplecream | 4 | martin_warrior, salamandastron |
| marchpane | 3 | pearls_lutra |
| marrow | 1 | redwall |
| mashed turnip | 2 | martin_warrior |
| mature cheese | 2 | rakkety_tam |
| mayfly | 2 | salamandastron |
| meadowcream | 52 | long_patrol, lord_brocktree, marlfox, martin_warrior, outcast, pearls_lutra, rakkety_tam, salamandastron, taggerung, triss |
| melon | 3 | pearls_lutra |
| milk | 7 | mossflower, redwall |
| milk-vetch leaves | 1 | taggerung |
| milkweed | 2 | taggerung |
| milky grass sap | 1 | taggerung |
| minnow | 1 | long_patrol |
| mint | 65 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| mint leaves | 4 | marlfox, martin_warrior |
| mint tea | 4 | marlfox, outcast |
| mintcream | 5 | martin_warrior, salamandastron |
| mixed berry | 2 | triss |
| mixed fruit | 2 | martin_warrior |
| moldy flour | 2 | lord_brocktree |
| moss | 2 | pearls_lutra |
| moth | 2 | salamandastron |
| motherwort | 4 | rakkety_tam, taggerung |
| motherwort (suspected) | 2 | marlfox |
| mountain cheese | 2 | salamandastron |
| mountain pear | 2 | salamandastron |
| muddy water | 2 | salamandastron |
| mulberry | 2 | redwall |
| mushroom | 79 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, salamandastron, taggerung, triss |
| mushrooms | 3 | pearls_lutra, salamandastron |
| mussel | 6 | lord_brocktree, pearls_lutra, salamandastron |
| mustard | 2 | redwall |
| nettle | 13 | lord_brocktree, outcast, pearls_lutra, rakkety_tam, taggerung, triss |
| nightjar | 2 | rakkety_tam |
| nut | 5 | triss |
| nutbeer | 2 | salamandastron |
| nutmeal | 2 | taggerung |
| nutmeg | 6 | mossflower, rakkety_tam, redwall |
| nuts | 32 | long_patrol, marlfox, martin_warrior, outcast, pearls_lutra, redwall, taggerung |
| nuts unspecified | 5 | mossflower |
| oat | 24 | outcast, pearls_lutra, rakkety_tam, taggerung, triss |
| oat bread | 2 | outcast |
| oat flour | 3 | marlfox |
| oat powder | 2 | outcast |
| oatbread | 2 | pearls_lutra |
| oatcake | 8 | marlfox, outcast, rakkety_tam, salamandastron |
| oatfarl | 2 | outcast |
| oatmeal | 24 | long_patrol, marlfox, martin_warrior, pearls_lutra, rakkety_tam, salamandastron, taggerung, triss |
| oatmeal scone | 2 | taggerung |
| oats | 36 | long_patrol, lord_brocktree, martin_warrior, mossflower, pearls_lutra, redwall, salamandastron |
| october ale | 6 | pearls_lutra, rakkety_tam |
| offal | 2 | rakkety_tam |
| old cider | 2 | outcast |
| onion | 37 | long_patrol, lord_brocktree, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| onion gravy | 2 | taggerung |
| onion sauce | 2 | lord_brocktree |
| onion skin | 2 | rakkety_tam |
| pale cider | 3 | taggerung |
| pancake | 2 | taggerung |
| pancakes | 3 | long_patrol |
| parsley | 11 | marlfox, martin_warrior, mossflower, taggerung |
| parsley wine | 2 | outcast |
| parsnip | 5 | long_patrol, pearls_lutra |
| pastry | 24 | long_patrol, lord_brocktree, marlfox, martin_warrior, outcast, pearls_lutra, rakkety_tam, salamandastron, taggerung |
| pea | 7 | long_patrol, martin_warrior, outcast, redwall |
| peach | 6 | pearls_lutra, redwall, salamandastron |
| pear | 51 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| pear orchard fruit | 1 | taggerung |
| pennycloud | 16 | long_patrol, lord_brocktree, marlfox, outcast, pearls_lutra, rakkety_tam, taggerung |
| pennycress | 8 | martin_warrior, taggerung, triss |
| pennywort | 2 | taggerung |
| pepper | 9 | martin_warrior, mossflower, salamandastron, taggerung |
| pepperwort | 3 | lord_brocktree, taggerung |
| perch | 4 | long_patrol, outcast |
| periwinkle | 2 | lord_brocktree |
| piecrust | 2 | marlfox |
| pike | 6 | marlfox, outcast, rakkety_tam |
| pink rose petals | 2 | pearls_lutra |
| plum | 68 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| plum flowers | 2 | long_patrol |
| plum orchard fruit | 1 | taggerung |
| plum preserve | 2 | lord_brocktree |
| pollen flour | 2 | salamandastron |
| pondweed | 2 | long_patrol |
| porridge | 2 | salamandastron |
| porridge grain | 2 | long_patrol |
| potato | 38 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, salamandastron, taggerung, triss |
| preserved berries | 1 | redwall |
| preserved damson | 2 | rakkety_tam |
| preserved damsons | 2 | pearls_lutra |
| preserved fruit | 3 | rakkety_tam |
| preserved plum | 2 | rakkety_tam |
| purple plum | 3 | salamandastron |
| quail | 2 | long_patrol |
| quince | 8 | mossflower, redwall, taggerung |
| quince jam | 2 | taggerung |
| rabbit | 2 | pearls_lutra |
| radish | 14 | lord_brocktree, marlfox, martin_warrior, mossflower, pearls_lutra, rakkety_tam, taggerung |
| rainwater | 2 | pearls_lutra |
| raisin | 4 | marlfox, taggerung |
| ramson | 2 | outcast |
| ramsons | 2 | lord_brocktree |
| ransom | 4 | marlfox, rakkety_tam |
| ransom wild garlic | 1 | rakkety_tam |
| ransoms | 2 | marlfox |
| raspberry | 29 | lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, redwall, salamandastron, taggerung, triss |
| raspberry preserve | 5 | martin_warrior, pearls_lutra |
| rawhide | 2 | outcast |
| red berries | 2 | long_patrol |
| red clover | 2 | pearls_lutra |
| red firebrand pepper | 1 | triss |
| red hotroot | 2 | outcast |
| red wine | 2 | salamandastron |
| redcurrant | 36 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| redcurrant hedge | 1 | taggerung |
| redcurrant preserve | 2 | outcast |
| rhubarb | 18 | long_patrol, lord_brocktree, pearls_lutra, rakkety_tam, triss |
| rhubarb juice | 2 | pearls_lutra |
| ripe yellow cheese | 2 | rakkety_tam |
| river shrimp | 2 | mossflower |
| rivershrimp | 2 | outcast |
| roasted almonds | 2 | long_patrol |
| roasted chestnut | 2 | taggerung |
| roasted trout scavenging | 1 | taggerung |
| rock salt | 2 | rakkety_tam |
| rock-pool vegetation unspecified | 2 | mossflower |
| rocks | 2 | outcast |
| rook | 2 | rakkety_tam |
| root | 5 | rakkety_tam, triss |
| roots | 10 | long_patrol, marlfox, outcast, taggerung |
| roots unspecified | 2 | mossflower |
| rose | 6 | lord_brocktree, martin_warrior, salamandastron |
| rose hips | 2 | marlfox |
| rose leaves | 2 | redwall |
| rose petals | 4 | long_patrol, lord_brocktree |
| rosecream | 2 | salamandastron |
| rosehip | 22 | long_patrol, lord_brocktree, outcast, pearls_lutra, rakkety_tam, taggerung |
| rosehip lotion of the monologue | 1 | rakkety_tam |
| rosehip syrup | 2 | salamandastron |
| rosehip vinegar | 2 | rakkety_tam |
| roseleaf | 2 | martin_warrior |
| rosemary | 2 | redwall |
| rosewater | 2 | salamandastron |
| rotten apple | 2 | salamandastron |
| rowan berries | 1 | triss |
| royal fern essence | 2 | lord_brocktree |
| rudd | 2 | triss |
| russet apple | 14 | long_patrol, marlfox, mossflower, outcast, rakkety_tam, salamandastron, taggerung |
| rye | 16 | long_patrol, lord_brocktree, mossflower, outcast, rakkety_tam, salamandastron, taggerung |
| rye bread | 2 | outcast |
| sage | 14 | long_patrol, lord_brocktree, marlfox, martin_warrior, outcast, salamandastron, taggerung |
| salad greens | 7 | long_patrol, lord_brocktree, outcast |
| salad plants unspecified | 3 | mossflower |
| salad vegetables | 6 | outcast |
| salt | 8 | long_patrol, mossflower, outcast, taggerung |
| saltwater fish | 2 | lord_brocktree |
| sanicle leaf medicinal reference | 1 | rakkety_tam |
| savory herb sauce | 2 | taggerung |
| scallion | 9 | lord_brocktree, rakkety_tam, salamandastron, taggerung |
| scallion crop | 1 | taggerung |
| scallions | 1 | triss |
| scallop | 3 | taggerung |
| scone | 9 | long_patrol, marlfox, outcast |
| sea salt | 4 | mossflower, taggerung |
| seabird | 6 | long_patrol, martin_warrior, taggerung |
| seafood | 3 | pearls_lutra |
| seafood unspecified | 2 | mossflower |
| seasoning | 2 | outcast |
| seaweed | 18 | lord_brocktree, martin_warrior, mossflower, pearls_lutra, triss |
| seed | 2 | triss |
| seeds unspecified | 3 | mossflower |
| shallot | 2 | martin_warrior |
| shanny | 2 | martin_warrior |
| shellfish | 10 | martin_warrior, pearls_lutra, taggerung, triss |
| ship's biscuit | 2 | pearls_lutra |
| shortbread biscuit | 2 | lord_brocktree |
| shortcrust pastry | 2 | marlfox |
| shredded carrot | 2 | marlfox |
| shrewbeer | 2 | outcast |
| shrewbread | 4 | pearls_lutra, salamandastron |
| shrimp | 24 | long_patrol, lord_brocktree, martin_warrior, rakkety_tam, redwall, salamandastron, triss |
| smelt | 2 | martin_warrior |
| snow | 3 | outcast |
| snowcream | 2 | martin_warrior |
| soft cheese | 2 | taggerung |
| soft white cheese | 5 | taggerung, triss |
| sole | 2 | taggerung |
| song thrush | 2 | rakkety_tam |
| sorrel | 1 | taggerung |
| soup | 3 | long_patrol |
| sour cream | 2 | salamandastron |
| south beans | 2 | outcast |
| special spices | 2 | marlfox |
| special tubers | 3 | outcast |
| spices | 4 | long_patrol, taggerung |
| spices unspecified | 2 | mossflower |
| spider | 2 | salamandastron |
| spongy pastry | 3 | marlfox |
| sprat | 2 | triss |
| spring onion | 4 | long_patrol, martin_warrior |
| spring vegetables | 6 | martin_warrior, outcast, pearls_lutra |
| spring vegetables unspecified | 2 | mossflower |
| springwater | 2 | salamandastron |
| sprout | 1 | redwall |
| stale bread | 2 | marlfox |
| stale rye bread | 2 | marlfox |
| starling | 2 | rakkety_tam |
| stickleback | 2 | long_patrol, redwall |
| stiff comb honey | 4 | pearls_lutra, salamandastron |
| stoat paw | 2 | salamandastron |
| stonecrop | 2 | lord_brocktree |
| strawberry | 65 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| strawberry fruit | 1 | taggerung |
| strawberry jam | 2 | salamandastron |
| strawberry preserve | 5 | lord_brocktree, martin_warrior |
| stream moss medicinal reference | 1 | rakkety_tam |
| stream vegetation | 3 | long_patrol |
| sugar | 10 | martin_warrior, mossflower, outcast, salamandastron |
| sugar syrup | 2 | outcast |
| sugar-preserved maple sprig | 2 | salamandastron |
| summer fruit | 2 | martin_warrior |
| summer vegetables | 4 | marlfox, pearls_lutra |
| summercream | 2 | martin_warrior |
| sweet arrowroot | 3 | marlfox |
| sweet chestnut | 2 | mossflower |
| sweet ground arrowroot | 3 | marlfox |
| sweet violet | 2 | lord_brocktree |
| sweet white arrowroot sauce | 2 | outcast |
| sweet woodruff | 2 | triss |
| sweet woodruff petal | 2 | rakkety_tam |
| sweet-chestnut flour | 2 | pearls_lutra |
| tadpole | 4 | marlfox, outcast |
| tallowfat | 2 | pearls_lutra |
| tea | 2 | rakkety_tam |
| tea rose | 2 | taggerung |
| tench | 2 | long_patrol |
| tender shoots | 1 | redwall |
| thrush | 2 | marlfox |
| thunder | 2 | outcast |
| thyme | 4 | martin_warrior, redwall |
| toad | 2 | salamandastron |
| toffee unspecified | 2 | mossflower |
| tomato | 3 | mossflower, redwall |
| tripe | 2 | rakkety_tam |
| tropical fruit | 2 | pearls_lutra |
| trout | 10 | lord_brocktree, marlfox, mossflower, rakkety_tam, redwall |
| trout fry | 2 | salamandastron |
| truffle | 2 | redwall |
| tuber | 1 | redwall |
| tubers | 2 | outcast |
| tubers unspecified | 2 | mossflower |
| turnip | 48 | long_patrol, lord_brocktree, marlfox, martin_warrior, mossflower, outcast, pearls_lutra, rakkety_tam, redwall, salamandastron, taggerung, triss |
| tutsan | 2 | lord_brocktree |
| unidentified herbs | 2 | marlfox |
| unidentified poison or herbs | 2 | marlfox |
| unidentified roots | 1 | redwall |
| unidentified vegetables | 2 | marlfox |
| unknown cavern delicacies | 2 | outcast |
| unknown lilac-colored liquid | 2 | outcast |
| unknown liquid | 2 | outcast |
| unresolved cow-wine spelling | 2 | outcast |
| unspecified abbeycream | 2 | salamandastron |
| unspecified ale ingredients | 2 | salamandastron |
| unspecified beer ingredients | 2 | salamandastron |
| unspecified berries | 3 | salamandastron |
| unspecified bird | 2 | salamandastron |
| unspecified breakfast | 2 | outcast |
| unspecified filling | 6 | outcast |
| unspecified fish | 2 | salamandastron |
| unspecified food | 3 | outcast |
| unspecified fruit | 4 | salamandastron |
| unspecified fruit and cream | 2 | outcast |
| unspecified fruit or herb | 2 | outcast |
| unspecified grain | 4 | outcast |
| unspecified herbs | 2 | salamandastron |
| unspecified meadowcream | 2 | salamandastron |
| unspecified meat | 2 | salamandastron |
| unspecified nuts | 5 | salamandastron |
| unspecified roots | 3 | salamandastron |
| unspecified salad greens | 4 | salamandastron |
| unspecified salad ingredients | 2 | salamandastron |
| unspecified sea fish | 2 | salamandastron |
| unspecified soup ingredients | 2 | salamandastron |
| unspecified spices | 3 | salamandastron |
| unspecified summer fruit | 2 | salamandastron |
| unspecified summer greens | 2 | salamandastron |
| unspecified vegetables | 7 | outcast, salamandastron |
| unspecified woodland filling | 2 | salamandastron |
| unspecified woodland fruit | 2 | salamandastron |
| unspecified woodland greens | 2 | salamandastron |
| valerian (suspected) | 2 | marlfox |
| vanilla | 2 | taggerung |
| vegetable | 4 | rakkety_tam, triss |
| vegetable flan | 2 | salamandastron |
| vegetable oil | 3 | long_patrol, redwall |
| vegetable sausage | 3 | rakkety_tam |
| vegetables | 26 | long_patrol, lord_brocktree, marlfox, martin_warrior, outcast, pearls_lutra, redwall, taggerung |
| vegetation | 2 | taggerung |
| vendace | 2 | taggerung |
| verbena medicinal reference | 1 | rakkety_tam |
| violet | 7 | martin_warrior, salamandastron, taggerung |
| wasp | 2 | salamandastron |
| water | 40 | long_patrol, lord_brocktree, marlfox, mossflower, outcast, pearls_lutra, rakkety_tam, salamandastron, taggerung, triss |
| water shrimp | 2 | long_patrol |
| watercress | 24 | long_patrol, lord_brocktree, marlfox, martin_warrior, outcast, rakkety_tam, redwall, salamandastron |
| watercress forage | 1 | taggerung |
| watercress root | 2 | salamandastron |
| waterfowl | 2 | marlfox |
| waterfowl eggs | 2 | long_patrol |
| watershrimp | 24 | lord_brocktree, marlfox, martin_warrior, outcast, pearls_lutra, rakkety_tam, taggerung, triss |
| waterweed unspecified | 2 | mossflower |
| whale | 2 | pearls_lutra |
| wheat | 14 | martin_warrior, outcast, rakkety_tam, redwall, salamandastron |
| wheat flour | 5 | martin_warrior, triss |
| whelk | 6 | lord_brocktree, martin_warrior, salamandastron |
| white button mushroom | 2 | marlfox |
| white cabbage | 2 | long_patrol |
| white cave mushroom | 2 | outcast |
| white cheese | 13 | outcast, salamandastron, taggerung |
| white gooseberry | 1 | redwall |
| white gooseberry wine | 2 | redwall |
| white sauce | 2 | taggerung |
| white turnip | 8 | long_patrol, outcast, pearls_lutra, redwall |
| whiterose cream | 2 | martin_warrior |
| whitlow | 2 | taggerung |
| whortleberry | 6 | triss |
| wild beetroot | 2 | triss |
| wild berries | 2 | martin_warrior |
| wild berry | 2 | triss |
| wild celery | 6 | martin_warrior, pearls_lutra, taggerung |
| wild cherry | 16 | long_patrol, lord_brocktree, martin_warrior, outcast, rakkety_tam, triss |
| wild damson | 2 | taggerung |
| wild garlic | 2 | marlfox |
| wild grape | 4 | pearls_lutra, redwall |
| wild mushroom | 2 | rakkety_tam |
| wild oat | 4 | outcast, taggerung |
| wild oats | 10 | long_patrol, martin_warrior, salamandastron |
| wild onion | 11 | lord_brocktree, martin_warrior, outcast, taggerung, triss |
| wild plum | 7 | marlfox, martin_warrior |
| wild radish | 2 | rakkety_tam |
| wild ramsons | 1 | taggerung |
| wild strawberry | 6 | marlfox, outcast, taggerung |
| willowherb | 2 | mossflower |
| wine | 3 | outcast |
| winter cabbage | 2 | long_patrol |
| winter rosehip | 2 | outcast |
| withered field mushrooms | 2 | marlfox |
| wood pigeon | 2 | redwall |
| woodcock | 2 | rakkety_tam |
| woodcock egg | 2 | rakkety_tam |
| woodland trifle | 3 | outcast |
| woodland vegetables unspecified | 2 | mossflower |
| woodlice | 2 | pearls_lutra |
| woodpigeon | 10 | mossflower, rakkety_tam, taggerung, triss |
| woodpigeon egg | 2 | rakkety_tam |
| worm | 2 | salamandastron |
| worms | 2 | outcast |
| wormwood | 1 | lord_brocktree |
| yeast | 2 | long_patrol |
| yellow cheese | 12 | rakkety_tam, salamandastron, taggerung, triss |
| young carrot crop | 1 | taggerung |
| young dandelion | 2 | salamandastron |
| young dandelion bud | 2 | triss |
| young dandelion root | 2 | triss |
| young dandelion shoot | 2 | outcast |
| young onion | 2 | outcast |
| young onions | 2 | marlfox |
| young rose leaves | 2 | outcast |
| young seaweed | 2 | taggerung |

## Limits

This is a reconciliation of the completed reading packages. It is not a second full-book reading, a calibrated production economy, or a claim of universal recipe completeness across all editions. All source ambiguity remains visible; every missing ingredient choice belongs to the game layer.
