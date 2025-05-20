#!/bin/bash
set -e

# Constants
CONFIG_FILE=".helm-subtree/config.yaml"

# Check for yq
if ! command -v yq &>/dev/null; then
  echo "Error: yq is required but not installed."
  echo "Install with: brew install yq or go install github.com/mikefarah/yq/v4@latest"
  exit 1
fi

# Read all chart names from config
CHART_NAMES=$(yq e '.charts | keys | .[]' "$CONFIG_FILE")

if [ -z "$CHART_NAMES" ]; then
  echo "No charts found in configuration."
  exit 0
fi

echo "Configured Helm Charts:"
echo "======================="
echo

for NAME in $CHART_NAMES; do
  echo "Chart: $NAME"
  echo "  Path: $(yq e ".charts.$NAME.path" "$CONFIG_FILE")"
  echo "  Upstream: $(yq e ".charts.$NAME.upstream_repo" "$CONFIG_FILE")"
  echo "  Upstream Path: $(yq e ".charts.$NAME.upstream_path" "$CONFIG_FILE")"
  echo "  Reference: $(yq e ".charts.$NAME.ref" "$CONFIG_FILE")"
  echo "  Tracking Branch: $(yq e ".charts.$NAME.tracking_branch" "$CONFIG_FILE")"
  echo
done
