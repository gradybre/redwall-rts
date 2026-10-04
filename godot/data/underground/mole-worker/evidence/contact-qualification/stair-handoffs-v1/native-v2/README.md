# Rejected native v2

The screenshot index conversion saved the first actual image. The process then
stopped making source progress with no raw diagnostic. A read-only one-second
native process sample is retained. After more than four minutes at approximately
98 percent CPU, only the exact owned native PID was sent SIGTERM. The wrapper
recorded exit -15, rejected execution, rehashed sources and removed its own
unchanged override. No other process was signaled.

The successor explicitly resumes on process_frame after a screenshot's
frame_post_draw completion before native matrix readback. This is a narrow
coroutine-boundary hypothesis, not a claimed engine root-cause diagnosis.
The successor also bounds total engine iterations with --quit-after; premature
termination still fails the full report/census guard. These changes do not alter
source phase, pose, root, fixture, camera or source proof.
