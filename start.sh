#!/bin/bash
# Top-level convenience script to start the entire Live Shopping application.
# This runs the backend's start_all.sh from the correct directory.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/backend"

# Make sure it's executable
chmod +x start_all.sh start_mcp_servers.sh

exec ./start_all.sh
