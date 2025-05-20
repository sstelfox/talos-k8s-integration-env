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
if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <name> <upstream_repo> <ref> <upstream_path> [local_path]"
  echo
  echo "  name          - A unique name for this chart"
  echo "  upstream_repo - URL of the git repository containing the chart"
  echo "  ref           - Git reference (branch, tag, commit) to use"
  echo "  upstream_path - Path to the chart within the upstream repo"
  echo "  local_path    - Local path where the chart should be vendored (optional, defaults to charts/vendored/<name>)"
  exit 1
fi

NAME="$1"
UPSTREAM_REPO="$2"
REF="$3"
UPSTREAM_PATH="$4"
LOCAL_PATH="${5:-charts/vendored/$NAME}"
TRACKING_BRANCH="vendored-$NAME-history"

# Check if name already exists in config
if yq e ".charts.$NAME" "$CONFIG_FILE" &>/dev/null && [ "$(yq e ".charts.$NAME" "$CONFIG_FILE")" != "null" ]; then
  echo "Error: Chart '$NAME' already exists in config."
  exit 1
fi

# Add to config file
echo "Adding chart '$NAME' to config..."
yq e ".charts.$NAME.path = \"$LOCAL_PATH\"" -i "$CONFIG_FILE"
yq e ".charts.$NAME.upstream_repo = \"$UPSTREAM_REPO\"" -i "$CONFIG_FILE"
yq e ".charts.$NAME.upstream_path = \"$UPSTREAM_PATH\"" -i "$CONFIG_FILE"
yq e ".charts.$NAME.ref = \"$REF\"" -i "$CONFIG_FILE"
yq e ".charts.$NAME.tracking_branch = \"$TRACKING_BRANCH\"" -i "$CONFIG_FILE"

echo "Configuration updated."

# Make sure directory exists
mkdir -p "$(dirname "$LOCAL_PATH")"

# Set up the remote and fetch
REMOTE_NAME="upstream-$NAME"
if ! git remote | grep -q "$REMOTE_NAME"; then
  echo "Adding remote '$REMOTE_NAME'..."
  git remote add "$REMOTE_NAME" "$UPSTREAM_REPO"
fi

echo "Fetching from upstream..."
git fetch "$REMOTE_NAME" "$REF"

# Checkout the specified ref
echo "Setting up tracking branch..."
git checkout -b "$TRACKING_BRANCH" "$REMOTE_NAME/$REF"

# Initialize the subtree
cd "$ROOT_DIR"
echo "Creating subtree in $LOCAL_PATH..."
git checkout -
if [ ! -d "$LOCAL_PATH" ]; then
  # First time - do read-tree
  git read-tree --prefix="$LOCAL_PATH" -u "$TRACKING_BRANCH:$UPSTREAM_PATH"
  git commit -m "Add vendored chart '$NAME' from $UPSTREAM_REPO at $REF"
else
  # Directory exists - use subtree merge
  git subtree merge --prefix="$LOCAL_PATH" "$TRACKING_BRANCH" --squash -m "Update vendored chart '$NAME' from $UPSTREAM_REPO at $REF"
fi

echo
echo "Successfully added chart '$NAME'"
echo "To update this chart in the future, run: ./helm-subtree update $NAME"
