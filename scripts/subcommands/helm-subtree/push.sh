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
echo "Pushing tracking branches to remote: $REMOTE"

# Read all chart names from config
CHART_NAMES=$(yq e '.charts | keys | .[]' "$CONFIG_FILE")

# Push each tracking branch to remote
for NAME in $CHART_NAMES; do
  TRACKING_BRANCH=$(yq e ".charts.$NAME.tracking_branch" "$CONFIG_FILE")

  echo "Checking tracking branch '$TRACKING_BRANCH' for chart '$NAME'..."

  # Verify branch exists locally
  if ! git branch | grep -q "$TRACKING_BRANCH"; then
    echo "  Warning: Tracking branch '$TRACKING_BRANCH' does not exist locally. Skipping."
    continue
  fi

  echo "  Pushing branch '$TRACKING_BRANCH' to $REMOTE..."
  git push "$REMOTE" "$TRACKING_BRANCH"

  echo "  Done."
done

echo
echo "All tracking branches have been pushed to $REMOTE"
