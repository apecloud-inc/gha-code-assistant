#!/bin/bash

set -e

git config --global --add safe.directory /github/workspace

REPO_NAME=$(jq -r ".repository.full_name" "$GITHUB_EVENT_PATH")

onerror() {
	local message="🤖 says: ‼️ Code assistant action failed."
	if [[ -n "$PR_NUMBER" ]]; then
		gh pr comment "$PR_NUMBER" --body "$message<br/>See: https://github.com/$REPO_NAME/actions/runs/$GITHUB_RUN_ID"
	else
		gh issue comment "$ISSUE_NUMBER" --body "$message<br/>See: https://github.com/$REPO_NAME/actions/runs/$GITHUB_RUN_ID"
	fi  
	exit 1
}

onsuccess() {
	local message="🤖 says: Code assistant action finished successfully 🎉!"
	if [[ -n "$response" ]]; then
		rsp_message=$(echo "$RESPONSE" | jq -r '.message')
		message="$message<br/><br/>$rsp_message"
	fi
	if [[ -n "$PR_NUMBER" ]]; then
		gh pr comment "$PR_NUMBER" --body "$message<br/><br/>See: https://github.com/$REPO_NAME/actions/runs/$GITHUB_RUN_ID"
	else
		gh issue comment "$ISSUE_NUMBER" --body "$message<br/><br/>See: https://github.com/$REPO_NAME/actions/runs/$GITHUB_RUN_ID"
	fi
}

trap onerror ERR
trap onsuccess EXIT

PR_NUMBER=""
ISSUE_NUMBER=""
PR_URL=""
ISSUE_URL=""
COMMENT_BODY=""
if jq -e '.issue' "$GITHUB_EVENT_PATH" > /dev/null; then
    ISSUE_NUMBER=$(jq -r ".issue.number" "$GITHUB_EVENT_PATH")
    ISSUE_URL=$(jq -r '.issue.html_url' "$GITHUB_EVENT_PATH")
    COMMENT_BODY=$(jq -r '.comment.body' "$GITHUB_EVENT_PATH")
elif jq -e '.pull_request' "$GITHUB_EVENT_PATH" > /dev/null; then
    PR_NUMBER=$(jq -r ".pull_request.number" "$GITHUB_EVENT_PATH")
    PR_URL=$(jq -r '.pull_request.html_url' "$GITHUB_EVENT_PATH")
    COMMENT_BODY=$(jq -r '.comment.body' "$GITHUB_EVENT_PATH")
else
    echo "No issue or pull request found in event."
    exit 1
fi

if [[ -z "$PR_URL" && -z "$ISSUE_URL" ]]; then
 	echo "Neither PR URL nor Issue URL is provided."
	exit 1
fi

RESPONSE=$(curl -s -X POST "$CODE_ASSISTANT_API_URL" \
  -H "Content-Type: application/json" \
  -d @- << EOF
{
  "pr_url": "$PR_URL",
  "issue_url": "$ISSUE_URL",
  "comment_body": "$COMMENT_BODY"
}
EOF
)

if [[ $? -ne 0 ]]; then
  echo "Error calling the code assistant API."
  exit 1
fi
