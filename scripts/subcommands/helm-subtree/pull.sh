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

# Parse remote argument
REMOTE="${1:-origin}"
echo "Pulling tracking branches from remote: $REMOTE"

# Read all chart names from config
CHART_NAMES=$(yq e '.charts | keys | .[]' "$CONFIG_FILE")

# Fetch all from remote
echo "Fetching all branches from $REMOTE..."
git fetch "$REMOTE"

# Pull each tracking branch from remote
for NAME in $CHART_NAMES; do
  TRACKING_BRANCH=$(yq e ".charts.$NAME.tracking_branch" "$CONFIG_FILE")

  echo "Checking tracking branch '$TRACKING_BRANCH' for chart '$NAME'..."

  # Verify branch exists on remote
  if ! git branch -r | grep -q "$REMOTE/$TRACKING_BRANCH"; then
    echo "  Warning: Tracking branch '$TRACKING_BRANCH' does not exist on $REMOTE. Skipping."
    continue
  fi

  # Create or update local branch
  if git branch | grep -q "$TRACKING_BRANCH"; then
    echo "  Updating local tracking branch..."
    git checkout "$TRACKING_BRANCH"
    git reset --hard "$REMOTE/$TRACKING_BRANCH"
  else
    echo "  Creating local tracking branch..."
    git checkout -b "$TRACKING_BRANCH" "$REMOTE/$TRACKING_BRANCH"
  fi

  git checkout -
  echo "  Done."
done

echo
echo "All tracking branches have been pulled from $REMOTE"
