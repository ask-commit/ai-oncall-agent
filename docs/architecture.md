# Architecture

## Pipeline Overview

The AI On-Call Agent ships as two composable GitHub Actions that form a two-stage pipeline.

```
                         ┌─────────────────┐
                         │   Cron Trigger   │
                         │  (every hour)    │
                         └────────┬────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────┐
│          Stage 1: Error Monitor (action.yml)                 │
│                                                              │
│  ┌────────────┐    ┌─────────────────┐    ┌──────────────┐  │
│  │  Datadog   │    │   Claude Code   │    │   Linear     │  │
│  │  Logs API  │───>│   Action        │───>│   (create    │  │
│  │  Monitor   │    │                 │    │    tickets)  │  │
│  │  API       │    │  • Consolidate  │    └──────────────┘  │
│  └────────────┘    │  • Fingerprint  │                      │
│                    │  • Deduplicate  │    ┌──────────────┐  │
│                    │                 │───>│   Slack      │  │
│                    └─────────────────┘    │   (notify)   │  │
│                                          └──────────────┘  │
└─────────────────────────────────┬───────────────────────────┘
                                  │
                    For each new ticket
                    (max 2 in parallel)
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────┐
│       Stage 2: Issue Resolver (resolve/action.yml)           │
│                                                              │
│  ┌────────────┐    ┌─────────────────┐    ┌──────────────┐  │
│  │  Linear    │    │   Claude Code   │    │  GitHub PR   │  │
│  │  (read     │───>│   Action        │───>│  (auto-fix)  │  │
│  │   issue)   │    │                 │    └──────┬───────┘  │
│  └────────────┘    │  • Investigate  │           │          │
│                    │  • Fix code     │    ┌──────▼───────┐  │
│                    │  • Run tests    │    │  Slack       │  │
│                    │  • Commit       │    │  (PR ready)  │  │
│                    └────────┬────────┘    └──────────────┘  │
│                             │                               │
│                    ┌────────▼────────┐                      │
│                    │  Linear         │                      │
│                    │  (update issue, │                      │
│                    │   add comment)  │                      │
│                    └─────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

## Action Inputs vs. Secrets

Since composite actions cannot access the `secrets` context, all credentials are passed as action inputs. Your calling workflow is responsible for forwarding secrets:

```yaml
- uses: ask-commit/ai-oncall-agent@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    datadog_api_key: ${{ secrets.DATADOG_API_KEY }}
    # ...
```

## Error Consolidation

The monitor doesn't create one ticket per error log. It groups errors by root cause:

```
Raw errors from Datadog:
  ├── ExtractorAgent: SyntaxError: Unexpected token `
  ├── SummaryAgent: SyntaxError: Unexpected token `
  ├── ClassifierAgent: SyntaxError: Unexpected token `
  ├── API Gateway: Connection refused to port 5432
  └── API Gateway: Connection refused to port 5432

After consolidation:
  ├── Ticket 1: "LLM returning markdown instead of JSON" (3 components, 47 occurrences)
  └── Ticket 2: "Database connection refused" (1 component, 2 occurrences → SKIPPED, < 3 threshold)
```

The `min_occurrences` input (default: `3`) controls the threshold.

## Deduplication Flow

```
New error detected
    │
    ▼
Search Linear for matching fingerprint
    │
    ├── Match found, status: Open/In Progress
    │   └── SKIP (already tracked)
    │
    ├── Match found, status: Done, updated < 24h ago
    │   └── SKIP (fix is propagating)
    │
    ├── Match found, status: Done, updated > 24h ago
    │   └── CREATE new ticket (error has recurred)
    │
    └── No match found
        └── CREATE new ticket
```

## Tools Used

| Tool | Purpose |
|------|---------|
| [Claude Code Action](https://github.com/anthropics/claude-code-action) | AI reasoning engine — analyzes errors, investigates code, implements fixes |
| [Linear MCP Server](https://github.com/linear/linear-mcp-server) | Issue tracker integration via Model Context Protocol |
| [Datadog API](https://docs.datadoghq.com/api/) | Error log and monitor querying |
| [Slack Webhooks](https://api.slack.com/messaging/webhooks) | Team notifications |
| [GitHub Actions](https://github.com/features/actions) | Orchestration and automation |
