#!/usr/bin/env bash

set -euo pipefail

DUMMY_TARGETS='["target-a", "target-b"]'

# API Token
if [[ -z ${API_TOKEN+x} ]]; then
  echo "Missing API Token"
  exit 2
fi

# POST Body Parameters
if [[ (-z ${REPOSITORY}) || (-z ${TARGET_BRANCH}) ]]; then
  echo "Missing Repo params"
  exit 2
fi

REPO_OWNER=$(echo "${REPOSITORY}" | cut -d "/" -f 1)
REPO_NAME=$(echo "${REPOSITORY}" | cut -d "/" -f 2)

if [[ (-z ${PR_NUMBER}) || (-z ${PR_SHA}) ]]; then
  echo "Missing PR params"
  exit 2
fi

# API URL
if [[ -z ${API_URL+x} ]]; then
  API_URL="https://api.trunk-staging.io:443/v1/setImpactedTargets"
fi

REPO_BODY=$(
  jq --null-input \
    --arg host "Github" \
    --arg owner "${REPO_OWNER}" \
    --arg name "${REPO_NAME}" \
    '{ "host": $host, "owner": $owner, "name": $name }'
)

PR_BODY=$(
  jq --null-input \
    --arg number "${PR_NUMBER}" \
    --arg sha "${PR_SHA}" \
    '{ "number": $number, "sha": $sha }'
)

POST_BODY="./post_body_tmp"
jq --null-input \
  --argjson repo "${REPO_BODY}" \
  --argjson pr "${PR_BODY}" \
  --arg impactedTargets "${DUMMY_TARGETS}" \
  --arg targetBranch "${TARGET_BRANCH}" \
  '{ "repo": $repo, "pr": $pr, "targetBranch": $targetBranch, "impactedTargets": $impactedTargets }' \
  >"${POST_BODY}"

cat "${POST_BODY}"
cat "${API_URL}"

HTTP_STATUS_CODE=$(
  curl -s -o /dev/null -w '%{http_code}' -X POST \
    -H "Content-Type: application/json" -H "x-api-token:${API_TOKEN}" \
    -d "@${POST_BODY}" \
    "${API_URL}"
)

if [[ ${HTTP_STATUS_CODE} == 200 ]]; then
  exit 0
else
  echo "${HTTP_STATUS_CODE}" " @ " "${PR_SHA}"
  exit 1
fi
