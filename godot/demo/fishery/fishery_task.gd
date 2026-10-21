extends "res://demo/work/owned_job_task.gd"
## One resident's part in a fishery job -- a fishing trip's seat, a trap's collection, the rack, the mill, making or
## mending gear (fishery.gd). Decision 0431 (live demo). A thin adapter like the kitchen's (kitchen_task.gd): the
## fishery holds every number (what is reserved, caught, carried and how much work is done) and decides each next
## step; this task only lets the brain walk where the fishery says and stand at the work (resident_brain.gd TASKS),
## and tells the fishery when it arrives, when it is called away and when it is over -- so an interruption loses
## nothing: a load in hand is set down at its landing for the next fisher (REQ-SET-054: "retain cargo there").
## Called away by an order, a meal or the night, its resident keeps the job to come back to (`unfinished`; decision
## 1905, as the orchard's 1900).
## While it carries a load (a catch, dried fish, flour, made gear) or is out on the water or the ice, the night does
## not take it to bed first (`urgent`).
## Everything it does is the shared adapter's (demo/work/owned_job_task.gd, decision 1905).
