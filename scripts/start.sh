#!/bin/bash
# Start the MRI at Scale Demo with distributed node (required for Khepri/Ra)

set -e
cd "$(dirname "$0")/.."

echo "Starting Macula MRI at Scale Demo..."
echo ""

# Ensure assets are built
mix assets.deploy 2>/dev/null || mix assets.build 2>/dev/null || true

# Start with distributed node name
elixir --sname mri_demo -S mix phx.server
