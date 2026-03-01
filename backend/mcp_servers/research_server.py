#!/usr/bin/env python3
"""
Research Agent - HTTP Server
Provides product verification via web search
"""

import os
import sys
import uvicorn
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Dict
from dotenv import load_dotenv

# Add parent directory to path to import agents
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import the research agent
from agents import ResearchAgent

from pathlib import Path
load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")

# Initialize FastAPI
app = FastAPI(title="Research Agent MCP Server")

# Initialize Research Agent
OPENROUTER_API_KEY = os.environ.get("RESEARCH_AGENT_API_KEY") or os.environ.get("OPENROUTER_API_KEY")
SERPER_API_KEY = os.environ.get("SERPER_API_KEY")

if not SERPER_API_KEY:
    print("⚠️  SERPER_API_KEY not found - Research Agent will not work")
    research_agent = None
else:
    research_agent = ResearchAgent(OPENROUTER_API_KEY, SERPER_API_KEY)
    print("✓ Research Agent initialized")


# Request/Response Models
class VerifyProductRequest(BaseModel):
    product_name: str


class VerifyProductResponse(BaseModel):
    exists: bool
    info: str
    confidence: str
    release_status: str


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "research-agent"}


@app.post("/verify_product", response_model=VerifyProductResponse)
async def verify_product(request: VerifyProductRequest):
    """Verify if a product exists and is currently available"""
    if not research_agent:
        return VerifyProductResponse(
            exists=False,
            info="Research agent not available - SERPER_API_KEY missing",
            confidence="low",
            release_status="unknown"
        )
    
    result = research_agent.verify_product(request.product_name)
    
    return VerifyProductResponse(
        exists=result.get("exists", False),
        info=result.get("info", ""),
        confidence=result.get("confidence", "low"),
        release_status=result.get("release_status", "unknown")
    )


if __name__ == "__main__":
    print("🔍 Starting Research Agent HTTP Server on port 8001...")
    uvicorn.run(app, host="127.0.0.1", port=8001)
