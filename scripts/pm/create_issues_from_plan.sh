#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/pm/create_issues_from_plan.sh /path/to/issues.json
# JSON format:
# [
#   {
#     "title": "[Task] ...",
#     "lane": "Lane A (UI)",
#     "agent": "Claude",
#     "acceptance": ["..."],
#     "scope": ["Memora/..."],
#     "deps": ["#123"]
#   }
# ]

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI が見つかりません。先にインストールしてください。" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq が見つかりません。先にインストールしてください。" >&2
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <issues.json>" >&2
  exit 1
fi

JSON_FILE="$1"
if [[ ! -f "$JSON_FILE" ]]; then
  echo "ファイルが存在しません: $JSON_FILE" >&2
  exit 1
fi

normalize_lane_label() {
  case "$1" in
    "Lane A (UI)") echo "lane:ui" ;;
    "Lane B (Audio/STT)") echo "lane:audio-stt" ;;
    "Lane C (Models/ViewModels/Contracts)") echo "lane:model-state" ;;
    "Lane D (App/Project/CI)") echo "lane:app-infra" ;;
    "Lane E (QA/Operations)") echo "lane:qa-ops" ;;
    *) echo "" ;;
  esac
}

normalize_agent_label() {
  case "$1" in
    "Codex") echo "agent:codex" ;;
    "Claude") echo "agent:claude" ;;
    "Claude + Codex") echo "agent:pair" ;;
    *) echo "" ;;
  esac
}

count=$(jq 'length' "$JSON_FILE")
if [[ "$count" -eq 0 ]]; then
  echo "Issueが0件です。" >&2
  exit 1
fi

echo "作成対象: $count 件"

for i in $(seq 0 $((count - 1))); do
  title=$(jq -r ".[$i].title" "$JSON_FILE")
  lane=$(jq -r ".[$i].lane" "$JSON_FILE")
  agent=$(jq -r ".[$i].agent" "$JSON_FILE")

  lane_label=$(normalize_lane_label "$lane")
  agent_label=$(normalize_agent_label "$agent")

  acceptance=$(jq -r ".[$i].acceptance[]?" "$JSON_FILE" | sed 's/^/- [ ] /')
  scope=$(jq -r ".[$i].scope[]?" "$JSON_FILE" | sed 's/^/- /')
  deps=$(jq -r ".[$i].deps[]?" "$JSON_FILE" | sed 's/^/- /')

  body=$(cat <<BODY
## 概要
$title

## Lane
$lane

## Agent
$agent

## 受け入れ条件
${acceptance:-- [ ] TBD}

## 変更対象
${scope:-- TBD}

## 依存
${deps:-- なし}
BODY
)

  labels=("type:task" "status:todo")
  [[ -n "$lane_label" ]] && labels+=("$lane_label")
  [[ -n "$agent_label" ]] && labels+=("$agent_label")

  label_csv=$(IFS=,; echo "${labels[*]}")

  echo "Creating issue: $title"
  gh issue create \
    --title "$title" \
    --body "$body" \
    --label "$label_csv"
done

echo "完了: $count 件のIssueを作成しました。"
