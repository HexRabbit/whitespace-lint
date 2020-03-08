#!/bin/bash
GITHUB_TOKEN="$1"

# skip if no /wslint
echo "Checking if contains '/wslint' command..."
[[ -n "$(jq -r "select(.comment.body)" "$GITHUB_EVENT_PATH" | grep -E "/wslint")" ]] || exit 1

# skip if not a PR
echo "Checking if a PR command..."
[[ -n "$(jq -r "select(.issue.pull_request.url)" "$GITHUB_EVENT_PATH")" ]] || exit 1

PR_NUMBER=$(jq -r ".issue.number" "$GITHUB_EVENT_PATH")
REPO_FULLNAME=$(jq -r ".repository.full_name" "$GITHUB_EVENT_PATH")

URI="https://api.github.com"
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

pr_resp=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
  "${URI}/repos/$REPO_FULLNAME/pulls/$PR_NUMBER")

HEAD_REPO=$(echo "$pr_resp" | jq -r .head.repo.full_name)
HEAD_BRANCH=$(echo "$pr_resp" | jq -r .head.ref)

API_HEADER="Accept: application/vnd.github.VERSION.diff"
pr_diff=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
  "${URI}/repos/$REPO_FULLNAME/pulls/$PR_NUMBER")

git remote set-url origin https://x-access-token:$GITHUB_TOKEN@github.com/$REPO_FULLNAME.git
git config --global user.email "wslint@github.com"
git config --global user.name "GitHub Whitespace Linter"

git fetch origin $HEAD_BRANCH
git checkout -b $HEAD_BRANCH origin/$HEAD_BRANCH

git apply --index -R <<< "$pr_diff" &> /dev/null
git apply --index --whitespace=fix <<< "$pr_diff" &> /dev/null
git add .

if [[ -n $(git diff --cached) ]]; then
  git commit -m "Auto stripped whitespace"
  git push origin $HEAD_BRANCH
  echo ::set-output name=is_linted::1
else
  echo ::set-output name=is_linted::0
fi
