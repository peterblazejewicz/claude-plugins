---
description: "Start Ralph Loop in current session (PowerShell)"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Write"]
hide-from-slash-command-tool: "true"
---

# Ralph Loop Command (PowerShell)

Parse arguments from: $ARGUMENTS

Extract from the arguments:
- **prompt**: The main task description (everything that's not a flag)
- **--max-iterations N**: Maximum iterations (default: 0 = unlimited)
- **--completion-promise TEXT**: Promise phrase to detect completion (default: null)

Create the state file `.claude/ralph-loop.local.md` using your Write tool with this format:

```markdown
---
active: true
iteration: 1
max_iterations: <N or 0>
completion_promise: "<TEXT>" or null
started_at: "<current UTC timestamp in ISO 8601 format>"
---

<the prompt/task description>
```

After creating the state file, output:

```
Ralph loop activated in this session!

Iteration: 1
Max iterations: <N or unlimited>
Completion promise: <TEXT or none>

The stop hook is now active. When you try to exit, the SAME PROMPT will be
fed back to you. You'll see your previous work in files, creating a
self-referential loop where you iteratively improve on the same task.

WARNING: This loop cannot be stopped manually! It will run infinitely
unless you set --max-iterations or --completion-promise.
```

If a completion promise was set, also display:

```
CRITICAL - Ralph Loop Completion Promise

To complete this loop, output this EXACT text:
  <promise>YOUR_PROMISE_TEXT</promise>

STRICT REQUIREMENTS (DO NOT VIOLATE):
  - Use <promise> XML tags EXACTLY as shown above
  - The statement MUST be completely and unequivocally TRUE
  - Do NOT output false statements to exit the loop
  - Do NOT lie even if you think you should exit
```

Then begin working on the task.

CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop, even if you think you're stuck.