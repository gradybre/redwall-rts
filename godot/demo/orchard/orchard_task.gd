extends "res://demo/work/owned_job_task.gd"
## One resident's part in an orchard job (orchard_jobs.gd; decision 0671). A thin adapter like the fishery's
## (fishery_task.gd): the orchard's board holds every number and decides each next step; this task only lets the brain
## walk where the board says and stand at the work, and tells the board when it arrives, when it is called away and
## when it is over -- so an interruption loses nothing (a load in hand is set down for the next to carry on). Called
## away by an order, a meal or the night, its resident keeps the job to come back to (`unfinished`; decision 1900).
## While fruit or berries are in its hands, the night does not take it to bed first (`urgent`).
## Everything it does is the shared adapter's (demo/work/owned_job_task.gd, decision 1905).
