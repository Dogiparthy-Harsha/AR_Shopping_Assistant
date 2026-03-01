#!/usr/bin/env python3
"""
MCP Client Helper
Manages connections to MCP servers
"""

import asyncio
import json
from typing import Dict, Any, Optional
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


class MCPClientManager:
    """Manages connections to multiple MCP servers"""
    
    def __init__(self):
        self.sessions = {}
        self.clients = {}
    
    async def connect_server(self, server_name: str, command: str, args: list, env: Optional[Dict] = None):
        """Connect to an MCP server"""
        server_params = StdioServerParameters(
            command=command,
            args=args,
            env=env or {}
        )
        
        # Use stdio_client as async context manager
        stdio_transport = stdio_client(server_params)
        read_stream, write_stream = await stdio_transport.__aenter__()
        
        self.clients[server_name] = stdio_transport
        
        session = ClientSession(read_stream, write_stream)
        await session.initialize()
        self.sessions[server_name] = session
        
        print(f"✓ Connected to {server_name} MCP server")
        return session
    
    async def call_tool(self, server_name: str, tool_name: str, arguments: Dict[str, Any]) -> Any:
        """Call a tool on a specific MCP server"""
        if server_name not in self.sessions:
            raise ValueError(f"Server {server_name} not connected")
        
        session = self.sessions[server_name]
        result = await session.call_tool(tool_name, arguments)
        
        # Parse the result
        if result and len(result.content) > 0:
            content = result.content[0]
            if hasattr(content, 'text'):
                try:
                    return json.loads(content.text)
                except json.JSONDecodeError:
                    return content.text
        
        return None
    
    async def close_all(self):
        """Close all MCP server connections"""
        for server_name, session in self.sessions.items():
            try:
                await session.close()
                print(f"✓ Closed {server_name} connection")
            except Exception as e:
                print(f"⚠️  Error closing {server_name}: {e}")
        
        self.sessions.clear()
        self.clients.clear()


# Global MCP client manager instance
mcp_manager = None


async def initialize_mcp_clients():
    """Initialize all MCP server connections"""
    global mcp_manager
    
    import os
    from dotenv import load_dotenv
    from pathlib import Path
    load_dotenv(Path(__file__).resolve().parent.parent / ".env")
    
    mcp_manager = MCPClientManager()
    
    # Connect to Research Agent
    if os.environ.get("SERPER_API_KEY"):
        await mcp_manager.connect_server(
            "research-agent",
            "python3",
            ["mcp_servers/research_server.py"],
            env={
                "RESEARCH_AGENT_API_KEY": os.environ.get("RESEARCH_AGENT_API_KEY") or os.environ.get("OPENROUTER_API_KEY"),
                "SERPER_API_KEY": os.environ.get("SERPER_API_KEY")
            }
        )
    
    # Connect to eBay Search
    await mcp_manager.connect_server(
        "ebay-search",
        "python3",
        ["mcp_servers/ebay_server.py"],
        env={
            "EBAY_CLIENT_ID": os.environ.get("EBAY_CLIENT_ID"),
            "EBAY_CLIENT_SECRET": os.environ.get("EBAY_CLIENT_SECRET")
        }
    )
    
    # Connect to Amazon Search
    await mcp_manager.connect_server(
        "amazon-search",
        "python3",
        ["mcp_servers/amazon_server.py"],
        env={
            "RAINFOREST_API_KEY": os.environ.get("RAINFOREST_API_KEY")
        }
    )
    
    return mcp_manager


async def shutdown_mcp_clients():
    """Shutdown all MCP server connections"""
    global mcp_manager
    if mcp_manager:
        await mcp_manager.close_all()
