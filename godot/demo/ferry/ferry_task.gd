extends "res://demo/work/owned_job_task.gd"
## One resident's part in a ferry job -- gathering the far copse's windfall, hauling the landed wood to the log stack, or
## crewing a crossing (ferry.gd). Decision 0437 (live demo). A thin adapter like the fishery's (fishery_task.gd): the
## ferry holds every number (what is lying, carried, aboard and stacked, and how much work is done) and decides each
## next step; this task only lets the brain walk where the ferry says and stand at the work (resident_brain.gd TASKS),
## and tells the ferry when it arrives, when it is called away and when it is over -- so an interruption loses nothing:
## a load in hand is set down where it is for the next to fetch.
## Called away by an order, a meal or the night, its resident keeps the job to come back to (`unfinished`; decision
## 1905, as the orchard's 1900).
## While it carries wood or is on a stage's deck or afloat, the night does not take it to bed first (`urgent`).
## Everything it does is the shared adapter's (demo/work/owned_job_task.gd, decision 1905).
