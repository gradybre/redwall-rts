# Rejected native capture

This intermediate run returned exit 0 but emitted 20 SCRIPT ERROR lines. The bounded attachment helper called ArrayMesh-only get_blend_shape_count on the actual CylinderMesh carried log, and those carry cases consequently omitted their attachments. This batch is rejected; it is not passing measurement evidence. The final helper explicitly distinguishes ArrayMesh and PrimitiveMesh, tests the actual primitive case, and the reproduction tool rejects diagnostic lines and case/attachment coverage mismatches before accepting evidence.
