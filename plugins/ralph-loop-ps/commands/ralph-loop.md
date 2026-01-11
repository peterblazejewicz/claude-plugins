---
description: "Start Ralph Loop in current session (PowerShell)"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Write"]
hide-from-slash-command-tool: "true"
---

# Ralph Loop Command (PowerShell)

## Step 1: Check for Help Request

If the arguments contain `--help` or `-h`, display this help text and stop:

```
Ralph Loop - Interactive self-referential development loop (PowerShell 7.x)

USAGE:
  /ralph-loop [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words without quotes)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase to signal completion
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Ralph Loop in your CURRENT session. The stop hook prevents
  exit and feeds your output back as input until completion or iteration limit.

  To signal completion, you must output: <promise>YOUR_PHRASE</promise>

EXAMPLES:
  /ralph-loop Build a todo API --completion-promise 'DONE' --max-iterations 20
  /ralph-loop --max-iterations 10 Fix the auth bug
  /ralph-loop Refactor cache layer  (runs forever)
  /ralph-loop --completion-promise 'TASK COMPLETE' Create a REST API

STOPPING:
  Only by reaching --max-iterations or detecting --completion-promise
  No manual stop - Ralph runs infinitely by default!
```

Do NOT create the state file when showing help. Stop here.

## Step 2: Parse Arguments

Parse arguments from: $ARGUMENTS

Extract from the arguments:
- **prompt**: The main task description (everything that's not a flag or flag value)
- **--max-iterations N**: Maximum iterations (must be a non-negative integer, default: 0 = unlimited)
- **--completion-promise TEXT**: Promise phrase to detect completion (default: null)

**Parsing rules:**
- Flags can appear anywhere in the arguments (before, after, or mixed with prompt text)
- Flag values immediately follow their flags
- Everything else is the prompt text, joined with spaces
- If `--max-iterations` is provided without a valid number, use 0 (unlimited)
- If `--completion-promise` is provided without text, ignore it

## Step 3: Validate

If no prompt text is provided (only flags or empty), display an error:
```
Error: No task prompt provided.

Usage: /ralph-loop <your task> [options]

Example: /ralph-loop Build a REST API --max-iterations 20
```

Do NOT create the state file. Stop here.

## Step 4: Create State File

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

**IMPORTANT - completion_promise format:**
- If a promise was provided: use quoted string, e.g., `completion_promise: "DONE"`
- If NO promise was provided: use the literal 4-character string `null` (not YAML null, not empty)
- Example with promise: `completion_promise: "All tests passing"`
- Example without: `completion_promise: null`

This must be the literal string `null` because the stop-hook.ps1 checks for this exact string.

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