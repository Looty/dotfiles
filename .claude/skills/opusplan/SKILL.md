---
name: opusplan
description: Transition to plan mode after a design discussion. Synthesizes everything discussed into a tight plan-mode prompt and enters plan mode. Use when the user says "let's plan this", "ready to plan", or "enter plan mode".
disable-model-invocation: true
---

Review our entire conversation above and synthesize a plan-mode prompt.

The prompt should be a single, self-contained paragraph (or short list) that captures:
- The exact goal
- Key constraints or decisions already made
- Relevant files, systems, or context surfaced during discussion
- What is explicitly out of scope

Write it as if handing off to a fresh context that hasn't seen our conversation.

Present the prompt to the user as a quoted block and ask: **"Enter plan mode with this prompt?"**

If they confirm (or say yes/go/looks good), call EnterPlanMode with that prompt as the goal.
If they want edits, update and re-confirm before entering.
