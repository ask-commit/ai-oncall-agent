#!/usr/bin/env bash
set -euo pipefail

# Slack notification script for AI On-Call Agent monitor results.
# Expects env vars: NEW_TICKETS, DUPS_OPEN, DUPS_DONE, SLACK_WEBHOOK_URL, GITHUB_RUN_URL

if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
  echo "SLACK_WEBHOOK_URL not set, skipping notification"
  exit 0
fi

NEW_COUNT=$(echo "$NEW_TICKETS" | jq length)
DUPS_OPEN_COUNT=$(echo "$DUPS_OPEN" | jq length)
DUPS_DONE_COUNT=$(echo "$DUPS_DONE" | jq length)

MESSAGE=""

if [ "$NEW_COUNT" -gt 0 ]; then
  NEW_LINES=$(echo "$NEW_TICKETS" | jq -r '.[] | "• <\(.url // "")|\(.identifier // "unknown")>: \(.title // "" | gsub("\\[Auto\\] "; ""))"' | head -10)
  MESSAGE="*New ($NEW_COUNT):*\n$NEW_LINES"
fi

if [ "$DUPS_OPEN_COUNT" -gt 0 ]; then
  DUPS_OPEN_LINES=$(echo "$DUPS_OPEN" | jq -r '.[] | "• <\(.url // "")|\(.identifier // "unknown")>: \(.title // "" | gsub("\\[Auto\\] "; "")) _(\(.status // "unknown"))_"' | head -10)
  [ -n "$MESSAGE" ] && MESSAGE="$MESSAGE\n\n"
  MESSAGE="${MESSAGE}*Duplicates - Open ($DUPS_OPEN_COUNT):*\n$DUPS_OPEN_LINES"
fi

if [ "$DUPS_DONE_COUNT" -gt 0 ]; then
  DUPS_DONE_LINES=$(echo "$DUPS_DONE" | jq -r '.[] | "• <\(.url // "")|\(.identifier // "unknown")>: \(.title // "" | gsub("\\[Auto\\] "; ""))"' | head -10)
  [ -n "$MESSAGE" ] && MESSAGE="$MESSAGE\n\n"
  MESSAGE="${MESSAGE}*Recurring - Previously Resolved ($DUPS_DONE_COUNT):*\n$DUPS_DONE_LINES"
fi

if [ -n "$MESSAGE" ]; then
  FOOTER="Working on fixes... PRs incoming"
  if [ "$NEW_COUNT" -eq 0 ] && [ "$DUPS_OPEN_COUNT" -gt 0 ]; then
    FOOTER="These issues already have open tickets — no new work triggered"
  fi

  MESSAGE=$(sed 's/\\n/\n/g' <<< "$MESSAGE")

  PAYLOAD=$(jq -n \
    --arg message "$MESSAGE" \
    --arg footer "$FOOTER | <${GITHUB_RUN_URL:-}|View Workflow>" \
    '{
      "blocks": [
        {"type": "header", "text": {"type": "plain_text", "text": "Production Errors Detected", "emoji": true}},
        {"type": "section", "text": {"type": "mrkdwn", "text": $message}},
        {"type": "divider"},
        {"type": "context", "elements": [{"type": "mrkdwn", "text": $footer}]}
      ]
    }')

  curl -s -X POST "$SLACK_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD"
fi
