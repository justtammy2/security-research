## hypothesis

one or two sentences. the bug stated as a claim. what breaks, why, what the attacker gets. reads like the first line of a contest finding.

## preconditions

bullet list. what has to be true for the attack to work — protocol state, function accessibility, attacker capabilities. helps a reviewer confirm applicability.

## attack steps

numbered list, plain english. one line per step. no code yet. anyone reading this should be able to follow the exploit without opening the PoC.

## why each step works

bullet per step (or grouped). explains the _mechanism_ — why the pool lets this happen, what check is missing or wrong, what assumption is violated.

## poc

the foundry test. minimum viable — no extra logging, no dead code. include the run command.

## summary

2-3 sentences. the bug in the simplest possible words, plus the general lesson (the pattern this belongs to). this is the paragraph that goes into your pattern file.

## diagram (optional)

sequence diagram, call graph, or state-change table. only if it clarifies something the prose doesn't. skip for simple bugs.
