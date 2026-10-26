---
description: a check that a module is installed and set up so its commands can run
requires: [module, command]
---

# test

a test checks that a [[module]] is in a state where its [[command]]s can
keep their promise: what it [[requires]] is there, the paths it [[owns]] have
the right shape, its commands answer as their [[interface]] says.

a test belongs to installing and setting up, not to running. it runs when a
module is added or changed, and only where a check is actually needed.
