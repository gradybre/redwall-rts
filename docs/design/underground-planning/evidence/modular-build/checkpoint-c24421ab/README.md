# Refused checkpoint c24421ab

The import exited zero but emitted the same nested-project warning as 1eb7a64d. The full suite and analyzer did not start. Both child-directory `.gdignore` markers were insufficient because Godot discovers nested projects before reading their markers. The later parent-subtree marker at 9ca21351 isolates only offline source/evidence; no diagnostic allowance changed. Project, assets, source bytes and HEAD were restored and unchanged.
