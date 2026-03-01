# HTTP-Based MCP Architecture - Quick Start

## ✅ What Changed

Converted from **stdio-based MCP** to **HTTP-based MCP** for better scalability and multi-client support.

## 🏗️ New Architecture

```
Main API (port 8000)
    ↓ HTTP REST
    ├─→ Research Agent (port 8001)
    ├─→ eBay Agent (port 8002)
    └─→ Amazon Agent (port 8003)
```

Each MCP server is now an independent FastAPI HTTP server.

## 🚀 Quick Start

### Step 1: Install httpx

```bash
pip install httpx
```

### Step 2: Kill old stdio servers (if running)

```bash
pkill -f 'mcp_servers'
```

### Step 3: Start HTTP MCP Servers

**Terminal 1:**
```bash
./start_mcp_servers.sh
```

You should see:
```
🚀 Starting HTTP-based MCP Servers...
================================
Starting Research Agent Server (port 8001)...
Starting eBay Search Server (port 8002)...
Starting Amazon Search Server (port 8003)...

✓ All HTTP MCP servers started!
================================
Research Agent: http://127.0.0.1:8001 (PID: xxxxx)
eBay Search:    http://127.0.0.1:8002 (PID: xxxxx)
Amazon Search:  http://127.0.0.1:8003 (PID: xxxxx)
```

### Step 4: Start Main API

**Terminal 2:**
```bash
python3 api_mcp.py
```

You should see:
```
Initializing OpenRouter AI for main agent...
Starting Main API Server (HTTP-based MCP) at http://127.0.0.1:8000
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
```

### Step 5: Start Frontend

**Terminal 3:**
```bash
python3 -m http.server 3000
```

### Step 6: Open Browser

Go to: **http://localhost:3000**

## 🧪 Test the Servers

### Test Research Agent:
```bash
curl -X POST http://127.0.0.1:8001/verify_product \
  -H "Content-Type: application/json" \
  -d '{"product_name": "iPhone 16"}'
```

### Test eBay Search:
```bash
curl -X POST http://127.0.0.1:8002/search \
  -H "Content-Type: application/json" \
  -d '{"query": "iPhone 16", "limit": 4}'
```

### Test Amazon Search:
```bash
curl -X POST http://127.0.0.1:8003/search \
  -H "Content-Type: application/json" \
  -d '{"query": "iPhone 16"}'
```

### Health Checks:
```bash
curl http://127.0.0.1:8001/health
curl http://127.0.0.1:8002/health
curl http://127.0.0.1:8003/health
```

## ✅ Benefits of HTTP-based MCP

1. **Multi-client support** - Multiple clients can connect simultaneously
2. **Standard REST API** - Easy to test with curl/Postman
3. **No stdio limitations** - Servers run independently
4. **Better debugging** - Can test each server separately
5. **Scalability** - Can run servers on different machines
6. **Health checks** - Easy monitoring with `/health` endpoints

## 🔄 Comparison

| Feature | stdio MCP | HTTP MCP |
|---------|-----------|----------|
| **Communication** | stdin/stdout | HTTP REST |
| **Multi-client** | ❌ One parent only | ✅ Multiple clients |
| **Testing** | ⚠️  Complex | ✅ Easy (curl/Postman) |
| **Debugging** | ⚠️  Difficult | ✅ Easy (logs, health checks) |
| **Scalability** | ⚠️  Limited | ✅ High |
| **Deployment** | ⚠️  Complex | ✅ Standard web deployment |

## 🛑 Stopping Servers

```bash
# Stop all MCP servers
pkill -f 'mcp_servers'

# Or kill specific PIDs (shown in startup output)
kill PID1 PID2 PID3
```

## 📝 API Endpoints

### Research Agent (port 8001)
- `POST /verify_product` - Verify product exists
- `GET /health` - Health check

### eBay Agent (port 8002)
- `POST /search` - Search eBay
- `GET /health` - Health check

### Amazon Agent (port 8003)
- `POST /search` - Search Amazon
- `GET /health` - Health check

## 🐛 Troubleshooting

### "Connection refused"
- Make sure MCP servers are running
- Check ports aren't already in use: `lsof -i :8001`

### "httpx not found"
```bash
pip install httpx
```

### Servers not starting
- Check `.env` file has all required API keys
- Check terminal output for specific errors

---

**Status:** HTTP-based MCP architecture ready! Much better than stdio for your use case.
