#!/bin/bash
# Start all HTTP-based MCP servers for the shopping assistant

echo "🚀 Starting HTTP-based MCP Servers..."
echo "================================"

# Get the directory where this script is located (backend/)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$SCRIPT_DIR"

# Load environment variables from project root
if [ -f "$PROJECT_ROOT/.env" ]; then
    export $(cat "$PROJECT_ROOT/.env" | grep -v '^#' | grep -v '^\s*$' | xargs)
fi

# Start Research Agent HTTP Server (port 8001)
echo "Starting Research Agent Server (port 8001)..."
python3 mcp_servers/research_server.py &
RESEARCH_PID=$!
sleep 2

# Start eBay Search HTTP Server (port 8002)
echo "Starting eBay Search Server (port 8002)..."
python3 mcp_servers/ebay_server.py &
EBAY_PID=$!
sleep 2

# Start Amazon Search HTTP Server (port 8003)
echo "Starting Amazon Search Server (port 8003)..."
python3 mcp_servers/amazon_server.py &
AMAZON_PID=$!
sleep 2

echo ""
echo "✓ All HTTP MCP servers started!"
echo "================================"
echo "Research Agent: http://127.0.0.1:8001 (PID: $RESEARCH_PID)"
echo "eBay Search:    http://127.0.0.1:8002 (PID: $EBAY_PID)"
echo "Amazon Search:  http://127.0.0.1:8003 (PID: $AMAZON_PID)"
echo ""
echo "To stop all servers, run:"
echo "  kill $RESEARCH_PID $EBAY_PID $AMAZON_PID"
echo ""
echo "Or use: pkill -f 'mcp_servers'"
echo "================================"
echo ""
echo "Now start the main API:"
echo "  python3 api_mcp.py"
echo "================================"

# Keep script running
wait
