# Customization Guide

## Swap the Error Source

### Sentry instead of Datadog

Replace Steps 1 and 2 in the monitor prompt. You'll need to fork the action or wrap it with your own composite action that modifies the prompt. Alternatively, use the `datadog_query` input to customize what's queried, or replace the Datadog API calls entirely:

```bash
# List unresolved issues from the last hour
curl -s "https://sentry.io/api/0/projects/{org}/{project}/issues/?query=is:unresolved&statsPeriod=1h" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}"
```

Add `SENTRY_AUTH_TOKEN` to your GitHub secrets instead of `DATADOG_API_KEY` / `DATADOG_APP_KEY`.

### CloudWatch instead of Datadog

```bash
aws logs filter-log-events \
  --log-group-name "/your/app/logs" \
  --start-time "$(($(date +%s) - 3600))000" \
  --filter-pattern "ERROR" \
  --limit 100
```

Add AWS credentials to your GitHub secrets.

### New Relic instead of Datadog

```bash
curl -s "https://api.newrelic.com/graphql" \
  -H "API-Key: ${NEW_RELIC_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ actor { account(id: YOUR_ACCOUNT_ID) { nrql(query: \"SELECT * FROM Log WHERE level = '\''ERROR'\'' SINCE 1 hour ago LIMIT 100\") { results } } } }"}'
```

## Swap the Issue Tracker

### Jira instead of Linear

Use the [Atlassian MCP Server](https://github.com/atlassian/mcp-server-atlassian):

```json
{
  "mcpServers": {
    "atlassian": {
      "command": "npx",
      "args": ["-y", "@atlassian/mcp-server-atlassian"],
      "env": {
        "JIRA_API_TOKEN": "${{ secrets.JIRA_API_TOKEN }}",
        "JIRA_BASE_URL": "https://your-org.atlassian.net"
      }
    }
  }
}
```

Update `claude_args` to allow the Jira MCP tools and adjust the prompt accordingly.

### GitHub Issues instead of Linear

No MCP server needed — Claude Code Action has native GitHub access. Replace the Linear tool calls with:

```bash
gh issue create --title "[Auto] ..." --body "..." --label "auto-fix"
gh issue list --label "auto-fix" --state open
```

## Swap the Notification Channel

### Microsoft Teams instead of Slack

Replace `slack_webhook_url` with a Teams incoming webhook:

```bash
curl -X POST "$TEAMS_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"text": "Production errors detected — see Linear for details"}'
```

### Discord instead of Slack

```bash
curl -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content": "Production errors detected — see Linear for details"}'
```

## Tuning the Agent

### Adjust Error Sensitivity

Use the `min_occurrences` input on the monitor action:

```yaml
- uses: ask-commit/ai-oncall-agent@v1
  with:
    min_occurrences: '5'  # Increase to reduce noise, decrease for more sensitivity
```

### Adjust Scan Frequency

Change the cron schedule in your calling workflow:

```yaml
schedule:
  - cron: '*/15 * * * *'  # Every 15 minutes (aggressive)
  - cron: '0 * * * *'     # Every hour (default)
  - cron: '0 */6 * * *'   # Every 6 hours (relaxed)
```

### Custom Datadog Query

Use the `datadog_query` input to filter specific services or log sources:

```yaml
- uses: ask-commit/ai-oncall-agent@v1
  with:
    datadog_query: 'service:api-gateway status:error'
```

### Limit Parallel Resolvers

In your calling workflow's resolver job:

```yaml
strategy:
  max-parallel: 2  # Increase for faster resolution, decrease to avoid PR noise
```

### Add Project Context

Create a `CLAUDE.md` in your repo root with:

- Tech stack and framework versions
- Code conventions and patterns
- Common pitfalls specific to your codebase
- Testing commands
- File structure overview

Claude Code Action reads this file automatically and uses it to write better fixes.
