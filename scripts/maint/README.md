# Maintenance Policy

`policy-overrides.json` contains only SCTMES-specific maintenance markers. The
flake exposes `lib.maintenancePolicy` by extending the policy base from its
locked `upstream` input, so `maint-switch` and CI evaluate the same target policy
before activation.
