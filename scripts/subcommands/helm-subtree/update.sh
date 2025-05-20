#!/bin/bash
set -e

# Constants
CONFIG_FILE=".helm-subtree/config.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Check for yq
if ! command -v yq &>/dev/null; then
  echo "Error: yq is required but not installed."
  echo "Install with: brew install yq or go install github.com/mikefarah/yq/v4@latest"
  exit 1
fi

# Parse arguments
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <name> [new_ref]"
  echo
  echo "  name    - Name of the chart to update"
  echo "  new_ref - Optional new git reference (branch, tag, commit) to use"
  exit 1
fi

NAME="$1"
NEW_REF="$2"

# Check if name exists in config
if ! yq e ".charts.$NAME" "$CONFIG_FILE" &>/dev/null || [ "$(yq e ".charts.$NAME" "$CONFIG_FILE")" == "null" ]; then
  echo "Error: Chart '$NAME' does not exist in config."
  exit 1
fi

# Read config values
LOCAL_PATH=$(yq e ".charts.$NAME.path" "$CONFIG_FILE")
UPSTREAM_REPO=$(yq e ".charts.$NAME.upstream_repo" "$CONFIG_FILE")
UPSTREAM_PATH=$(yq e ".charts.$NAME.upstream_path" "$CONFIG_FILE")
REF=$(yq e ".charts.$NAME.ref" "$CONFIG_FILE")
TRACKING_BRANCH=$(yq e ".charts.$NAME.tracking_branch" "$CONFIG_FILE")
REMOTE_NAME="upstream-$NAME"

# Update ref if provided
if [ -n "$NEW_REF" ]; then
  REF="$NEW_REF"
  echo "Updating reference to '$REF' in config..."
  yq e ".charts.$NAME.ref = \"$REF\"" -i "$CONFIG_FILE"
fi

# Ensure remote exists
if ! git remote | grep -q "$REMOTE_NAME"; then
  echo "Adding remote '$REMOTE_NAME'..."
  git remote add "$REMOTE_NAME" "$UPSTREAM_REPO"
fi

# Fetch latest from upstream
echo "Fetching latest from upstream..."
git fetch "$REMOTE_NAME" "$REF"

# Update tracking branch
echo "Updating tracking branch..."
if git branch | grep -q "$TRACKING_BRANCH"; then
  git checkout "$TRACKING_BRANCH"
  git reset --hard "$REMOTE_NAME/$REF"
else
  git checkout -b "$TRACKING_BRANCH" "$REMOTE_NAME/$REF"
fi

# Perform subtree merge
cd "$ROOT_DIR"
echo "Updating subtree in $LOCAL_PATH..."
git checkout -
git subtree merge --prefix="$LOCAL_PATH" "$TRACKING_BRANCH" --squash -m "Update vendored chart '$NAME' from $UPSTREAM_REPO at $REF"

echo
echo "Successfully updated chart '$NAME'"
