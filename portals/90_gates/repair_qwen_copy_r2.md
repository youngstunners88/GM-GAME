<!-- dispatched: qwen/qwen3.8-max-prime
     prompt: prompts/portals/repair_qwen_copy.md
     files inlined: 1
     images attached: 0
     tokens: 3149 in / 2714 out
     cost: $0.0452
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
FACT_LOCK: FAIL

```json
[
  {
    "path": "smoke.examiner_intro[2]",
    "text": "Eleven questions.",
    "problem": "Contains a numeric value (\"Eleven\") which is not \"~100 days\" or \"~1% per day\".",
    "fix": "Replace with a non-numeric phrasing, e.g. \"A short set of questions.\""
  },
  {
    "path": "smoke.quiz_intro",
    "text": "Replace with non-numeric phrasing, e.g. 'A short quiz. Most correct to pass.",
    "problem": "Editorial placeholder instruction left in ship-ready copy; not valid in-game text.",
    "fix": "Replace with final line, e.g. \"A short quiz. Most correct to pass.\""
  },
  {
    "path": "smoke.stops[5].line",
    "text": "Remove the count: 'My desk. A quiz when you are ready. Press E.",
    "problem": "Editorial placeholder instruction left in ship-ready copy; not valid in-game text.",
    "fix": "Replace with final line, e.g. \"My desk. A quiz when you are ready. Press E.\""
  },
  {
    "path": "diamonds.stops[1].line",
    "text": "Remove the added claim: 'The waves end. The float stays tight.",
    "problem": "Editorial placeholder instruction left in ship-ready copy; not valid in-game text.",
    "fix": "Replace with final line, e.g. \"The waves end. The float stays tight.\""
  }
]
```