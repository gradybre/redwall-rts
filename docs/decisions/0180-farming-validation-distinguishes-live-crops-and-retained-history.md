# 0180 — Farming validation distinguishes live crops and retained history

Date:2026-09-20. Status: Accepted for bounded implementation.

FARMING-S4-VALIDATE-R01v1 adds a cold15-column FarmPlot image, pure predicate and owner2framedbridge withoutchangingversion1schema, gameplaywriters or existingsection1TileHistory APIs. Clear defaults differ fromlivecreation. Destroy clearspresence/crop/state/tile/self but retains validsoil/fertility/moisture/growth/health/family/streak/compost/sowday. Inactivegrowth keeps fullnonnegativei64domain; presentstate rules use the actual crop duration and boundedhourlyrelease.

A GROWING crop stops belowtarget and moves toRIPE on crossing; onehour releases atmost1000, so presentnonEMPTYgrowth is atmosttarget+999. SOWN is0growth/fullhealth; RIPE haspositivehealth andgrowth>=target. WITHERED has two valid causes: zerohealth belowtarget, or positivehealth at/above target afterageexpiry. Publicprobe434/0 includes healthyWITHERED and maximumday/streak histories. No unjustified health0-only withering rule or inactive normalization.

Localuniquetile andselfslot rules followcreation and globalDirectorygeneration semantics; two presentrows cannotshareoneglobalselfslot evenwithdifferentgenerations. Two4096i32sortcopies preserveoriginals and yield565248conservativepackedbytes withcaller/defaultColumns, below6417408streamallowance; native/RSS unmeasured. Alltableindices require priorcrop/soil gates and bridgepins of exactsource-tablelengths/values.

Existing family/streak helper is reused afterranges onallrows. GameplayfamilyIDs continue tocome fromCatalog; bridgeconstants pin thiswireversion's ordinal compatibility ratherthan defininganothergameplaydomain. No repair is made for checkedgrowthoverflow reachableonlyfromillegalinjectedstate. Bulk FarmPlot capture/apply, savedsection1/Directory/clock/mirrors andwhole-filepublication remain separateFARMING-SAVED-BINDINGS; nofarminggameplaycompletion implied.

Independentfeasibility/contractreviews and dispositions,163plannedimages,50codemutationunits and24metadata/sourcefaultcases are in farming-validation-planning-2026-09-20. Runtimeacceptance remains required.
