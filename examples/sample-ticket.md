# Sample Linear Ticket

This is an example of a ticket created by the AI On-Call Agent.

---

## Title

`[Auto] Backend - LLM returning markdown instead of JSON`

## Priority

High (2)

## Description

<!-- FINGERPRINT: backend:llm-json-format -->

### Error Summary
**Service:** backend
**Root Cause:** LLM returning markdown-wrapped JSON instead of raw JSON, causing parse failures
**Total Occurrences:** 47 in the last hour
**First seen:** 2025-01-15T08:12:33Z
**Last seen:** 2025-01-15T09:01:44Z

### Affected Components
| Component | File | Occurrences | Sample Error |
|-----------|------|-------------|--------------|
| ExtractorAgent | `src/agents/extractor.ts` | 23 | SyntaxError: Unexpected token \` in JSON at position 0 |
| SummaryAgent | `src/agents/summary.ts` | 18 | SyntaxError: Unexpected token \` in JSON at position 0 |
| ClassifierAgent | `src/agents/classifier.ts` | 6 | SyntaxError: Unexpected token \` in JSON at position 0 |

### Common Error Pattern
```
SyntaxError: Unexpected token ` in JSON at position 0
    at JSON.parse (<anonymous>)
    at parseAgentResponse (src/utils/parse.ts:15:22)
```

### Sample Stack Trace
```
SyntaxError: Unexpected token ` in JSON at position 0
    at JSON.parse (<anonymous>)
    at parseAgentResponse (src/utils/parse.ts:15:22)
    at ExtractorAgent.run (src/agents/extractor.ts:44:18)
    at processCall (src/handlers/call-handler.ts:112:5)
```

### Sample Log Entry
```json
{
  "timestamp": "2025-01-15T08:45:12.334Z",
  "level": "error",
  "service": "backend",
  "message": "Failed to parse agent response",
  "error": "SyntaxError: Unexpected token ` in JSON at position 0",
  "agent": "ExtractorAgent",
  "input_length": 4521,
  "raw_response_preview": "```json\n{\"key\": \"value\"}\n```"
}
```

### Root Cause Analysis
The LLM is wrapping its JSON output in markdown code fences (` ```json ... ``` `). The `parseAgentResponse` utility calls `JSON.parse()` directly on the raw response without stripping markdown formatting. This affects all agents that use this shared parsing function.

### Suggested Fix
Add a markdown code fence stripping step in `src/utils/parse.ts` before calling `JSON.parse()`. Strip leading/trailing ` ```json ` and ` ``` ` markers. This single fix will resolve the issue across all 3 affected agents.

### Related Links
- [Datadog Logs](https://app.datadoghq.com/logs?query=service%3Abackend%20status%3Aerror%20%22JSON.parse%22&from_ts=1705305600000&to_ts=1705312800000)
