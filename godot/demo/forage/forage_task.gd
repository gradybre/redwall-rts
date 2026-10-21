extends "res://demo/work/owned_job_task.gd"
## One resident's seat on a foraging trip (forage_trips.gd): walking to its spot in the woods, gathering its share and
## carrying the haul to its store. Decision 0681 (live demo). A thin adapter like the ferry's (ferry_task.gd): the trips
## hold every number (what is claimed, gathered, carried and stored, and how much work is done) and decide each next
## step; this task only lets the brain walk where the trips say and stand at the work (resident_brain.gd TASKS), and
## tells them when it arrives, when it is called away and when it is over -- so an interruption loses nothing: a haul in
## hand is set down where it is for the next to fetch.
## Called away by an order, a meal or the night, its resident keeps the job to come back to (`unfinished`; decision
## 1905, as the orchard's 1900).
## While it carries its haul, the night and a meal call wait (`urgent`).
## Everything it does is the shared adapter's (demo/work/owned_job_task.gd, decision 1905).
