# AI On-Call Agent

Autonomous production error monitoring and resolution — as reusable GitHub Actions.

**Datadog errors → Linear tickets → Code fix → Pull Request → Slack notification**

```
┌─────────────────────────────────────────────────────────────────┐
│                    AI On-Call Agent Pipeline                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────────────┐  │
│  │ Datadog  │───>│ Claude Code  │───>│ Linear Ticket Created │  │
│  │ (errors) │    │ (analyze +   │    │ (fingerprinted,       │  │
│  └──────────┘    │  deduplicate)│    │  deduplicated)        │  │
│                  └──────────────┘    └───────────┬───────────┘  │
│                                                  │              │
│                                                  ▼              │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────────────┐  │
│  │  Slack   │<───│  GitHub PR   │<───│ Claude Code           │  │
│  │ (notify) │    │  (auto-fix)  │    │ (investigate + fix)   │  │
│  └──────────┘    └──────────────┘    └───────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

Built with [Claude Code GitHub Action](https://github.com/anthropics/claude-code-action) + [Linear MCP Server](https://github.com/linear/linear-mcp-server).

## Quick Start

```yaml
# .github/workflows/ai-oncall.yml
name: AI On-Call Agent
on:
  schedule:
    - cron: '0 * * * *'

jobs:
  monitor:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: ask-commit/ai-oncall-agent@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          datadog_api_key: ${{ secrets.DATADOG_API_KEY }}
          datadog_app_key: ${{ secrets.DATADOG_APP_KEY }}
          linear_api_key: ${{ secrets.LINEAR_API_KEY }}
```

That's it. Every hour, errors are scanned, deduplicated, and filed as Linear tickets.

To also **auto-fix** each new ticket, see the [full example pipeline](.github/workflows/example-pipeline.yml).

## Two Actions

### `ask-commit/ai-oncall-agent@v1` — Error Monitor

Scans Datadog for production errors and creates deduplicated Linear tickets.

1. Queries Datadog logs API and triggered monitors
2. Consolidates errors by root cause (one ticket per root cause, not per log line)
3. Deduplicates against existing open Linear issues using fingerprints
4. Creates Linear tickets with structured descriptions, stack traces, and Datadog links
5. Optionally sends a Slack summary

#### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `claude_code_oauth_token` | yes | — | Claude Code OAuth token |
| `github_token` | yes | — | GitHub token |
| `datadog_api_key` | yes | — | Datadog API key |
| `datadog_app_key` | yes | — | Datadog Application key |
| `linear_api_key` | yes | — | Linear API key |
| `linear_team` | no | `ENG` | Linear team identifier |
| `ticket_prefix` | no | `[Auto]` | Prefix for auto-created tickets |
| `hours_back` | no | `1` | Hours to look back |
| `min_occurrences` | no | `3` | Min error count threshold |
| `datadog_query` | no | `status:error OR status:critical` | Custom Datadog log query |
| `claude_model` | no | _(empty)_ | Claude model override |
| `slack_webhook_url` | no | _(empty)_ | Slack webhook for summary notifications |

#### Outputs

| Output | Description |
|--------|-------------|
| `new_tickets` | JSON array of newly created tickets |
| `duplicates_open` | JSON array of duplicate tickets still open |
| `duplicates_done` | JSON array of duplicate tickets previously resolved |
| `has_results` | `true` if any results were found |

### `ask-commit/ai-oncall-agent/resolve@v1` — Issue Resolver

Takes a Linear issue ID, investigates the root cause, implements a fix, and opens a PR.

1. Reads the Linear issue details (error, stack trace, affected components)
2. Searches the codebase and investigates the root cause
3. Implements a minimal fix following existing code patterns
4. Opens a PR with a structured description linking back to the issue
5. Updates the Linear issue with the PR link and sets status to "In Review"
6. Optionally sends a Slack notification

#### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `claude_code_oauth_token` | yes | — | Claude Code OAuth token |
| `github_token` | yes | — | GitHub token |
| `linear_api_key` | yes | — | Linear API key |
| `issue_id` | yes | — | Linear issue ID (e.g. `ENG-123`) |
| `issue_url` | no | _(empty)_ | Linear issue URL |
| `claude_model` | no | _(empty)_ | Claude model override |
| `slack_webhook_url` | no | _(empty)_ | Slack webhook for PR notifications |

#### Outputs

| Output | Description |
|--------|-------------|
| `pull-request-url` | URL of the created pull request |
| `pull-request-number` | Number of the created pull request |
| `branch_name` | Name of the fix branch |

## Full Example

See [`.github/workflows/example-pipeline.yml`](.github/workflows/example-pipeline.yml) for a complete copy-paste workflow that:

1. Runs the monitor on a cron schedule
2. Automatically triggers the resolver for each new ticket
3. Limits parallel resolution to 2 concurrent PRs

## Security & Disclaimer

> **This project is in early stages.** It uses AI to modify code and create pull requests autonomously. Use at your own discretion and always review generated PRs before merging.

**Recommended security practices:**
- Use **read-only API keys** for Datadog (the monitor only queries logs — it never writes)
- Use a **scoped Linear API key** with minimal permissions (create/read issues)
- **Always require PR reviews** — never auto-merge AI-generated pull requests
- Start with `workflow_dispatch` (manual trigger) before enabling cron schedules

## Prerequisites

- [Datadog](https://www.datadoghq.com/) account with API access
- [Linear](https://linear.app/) account with API access
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/github-actions) OAuth token
- Slack incoming webhook (optional)

### GitHub Secrets

Add these to your repository (`Settings → Secrets and variables → Actions`):

| Secret | Description |
|--------|-------------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude Code OAuth token |
| `DATADOG_API_KEY` | Datadog API key |
| `DATADOG_APP_KEY` | Datadog Application key |
| `LINEAR_API_KEY` | Linear personal API key |
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL (optional) |

## Key Design Decisions

### Root Cause Consolidation

Errors are grouped by root cause, not by individual log line. If 5 different API handlers all fail with "connection refused", that's ONE ticket about database connectivity — not 5 separate tickets.

### Fingerprint-Based Deduplication

Each ticket gets a `<!-- FINGERPRINT: service:root-cause-slug -->` comment in its description. The monitor checks existing tickets for matching fingerprints before creating duplicates. Done/Canceled tickets get a 24-hour cooldown before re-creating (to let fixes propagate).

### Parallel Resolution with Limits

The resolver runs with `max-parallel: 2` to avoid overwhelming your repo with simultaneous PRs while still processing multiple issues concurrently.

## Customization

See the [customization guide](docs/customization.md) for:

- Swapping Datadog for Sentry, CloudWatch, or New Relic
- Using Jira or GitHub Issues instead of Linear
- Using Microsoft Teams or Discord instead of Slack
- Tuning error sensitivity and scan frequency

### Adding Project Context

For better fix quality, add a `CLAUDE.md` file to your repo root with project-specific context (tech stack, code patterns, testing commands). Claude Code Action reads this automatically.

## Example Outputs

See the [`examples/`](./examples) directory for:

- [Sample Linear ticket](./examples/sample-ticket.md) created by the monitor
- [Sample Pull Request](./examples/sample-pr.md) created by the resolver
- [Sample Slack notification](./examples/sample-slack-notification.md) sent to your channel

## License

MIT
