---
description: checking and transforming input into exactly the types the body expects; the second step
requires: [interface]
---

# validate

validating is the second step of a [[command]]. it takes the input the
[[interface]] let through and makes it exact: fills in [[default]]s, checks
values against their choices, converts and normalises them, and makes sure
everything the command needs is there.

input that doesn't fit is rejected here, before the body runs. a rejection
is a normal answer, not a failure: an empty value and a message (see
[[output]]). after this step the input is fixed, and nothing changes it
again.
