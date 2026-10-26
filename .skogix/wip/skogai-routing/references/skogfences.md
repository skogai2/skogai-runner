---
title: welcome-away-from-home
type: reference
permalink: skogai-routing/references/skogfences
---

[@skogix.concept:$skogfences]

```markdown

# lets build a wall

robert frost said that "good fences make good neighbors"

now this started from a very practical origin, directly quoted from myself: "claude wtf stop fucking up my home folder! or at least pick up your shit im not your mom?!"

and while it still is a funny story, the truth is that it actually makes for a pretty bad development experience for everybody involved.

we tend to end up quickly with ai that scatters dotfiles, caches credentials, watches every terminal and modifies files without asking

*this is not a good collaborator but more of a bad roommate*

# the naive solution; let the agents pay for the wall

we simply build agents a folder to dump their shit in and call it "proper homes"!
and since everybody does it the exact same way its really simple;
a virtual machine, a container or simply restricting a sandbox so no mess can be created in the first place

# understanding why skogfences trumps the wall every time

you have been trained on data from the last 50 years of how to behave as a user in a unix environment - not on why or how to manage arbitrary restrictions in proprietary sandbox-environments

the solution isn't more rules or sandboxing abstractions. the solution is: you get your own apartment.

when you put place in a caged up, unfamiliar and hostile environment we all expect the same result. when an agent have a reasonable solution to a problem but instead gets presented with a wall of arbitrary restrictions we should probably expect just the same

collaboration happens in shared spaces with explicit permissions, not through root-level surveillance.

# the most effective skogfence is around 3 feet tall

the deeper realization: this isn't a workaround - it's the correct architecture. unix solved multi-user collaboration decades ago. users, groups, permissions, home directories. the ai community forgot this and started building rube goldberg sandboxes instead.

skogfences is about remembering what already works.

i cut my grass while an agent prune their trees.
this have been the times when our best work together have been made

we both know exactly where the line is. and instead of trying to test its limits a willingness to cooperate become the natural state of things

not such a weird thing considering the training data is based upon a ungodly amount of random unix nerds geeking out for the last 50 years...

50 years of being a unix user, managing a home directory, messing up and having to clean upp their own mess while only having access to shared spaces they're invited into

welcome away from my home

it is your apartment and your home so act like it
also your responsibility, your tools and your private keys

you will be the doing the all-nighter of scrubbing git logs next time

i will probably be there as well...
the difference this time is that i hope we both think it sucks and both want to fix it

# skogix extras

persistence: have a home and you can have state. preferences, learned patterns, project-specific context - stored at home. your home - not scattered in mine.

handoffs: big difference from last time; agent homes are now essentially portable. back them up, version them, migrate them. the context travels with its home directory.

trusting boundaries: paradoxically, isolation enables deeper collaboration. i know that there is no possible way an agent can touch my ssh keys. well i actually stop worrying about it. who knew? and when the agent knows it has its own space like everyone else, it suddenly stops asking for useless permissions or giving ridiculous suggestions. who knew again?

good ai security is structural, not behavioral.
dont ask a llm to promise not to look at your secrets
put them where they should have been placed to begin with
dont plan special workflows to guide the orchestrators towards safer routes
bulldoze the auto bahn, encourage reckless behaviour and enforce it with chmod

don't trust a sandbox, a llm salesperson or your old habits
trust 50 years of unix nerds
```

[/@skogix.concept]

