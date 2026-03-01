#!/usr/bin/env python3
"""
Amazon Search Agent - HTTP Server
Provides Amazon product search functionality via Rainforest API
"""

import os
import sys
import uvicorn
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Dict, Optional
from dotenv import load_dotenv

# Add parent directory to path to import agents
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import Amazon search
from agents import RainforestSearch

from pathlib import Path
load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")

# Initialize FastAPI
app = FastAPI(title="Amazon Search MCP Server")

# Initialize Amazon Search
RAINFOREST_API_KEY = os.environ.get("RAINFOREST_API_KEY")

print("Initializing Rainforest API...")
amazon = RainforestSearch(RAINFOREST_API_KEY)
print("✓ Amazon Search initialized")


# Request/Response Models
class SearchRequest(BaseModel):
    query: str


class ProductResult(BaseModel):
    title: Optional[str]
    price: Optional[str]
    rating: Optional[str]
    url: Optional[str]
    image_url: Optional[str]


class SearchResponse(BaseModel):
    results: List[ProductResult]
    count: int


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "amazon-search"}


@app.post("/search", response_model=SearchResponse)
async def search_amazon(request: SearchRequest):
    """Search for products on Amazon"""
    amazon_data = amazon.search_items(request.query)
    
    results = []
    if amazon_data and "search_results" in amazon_data:
        for item in amazon_data["search_results"][:4]:
            results.append(ProductResult(
                title=item.get("title"),
                price=item.get("price", {}).get("raw"),
                rating=f"{item.get('rating')} stars ({item.get('ratings_total')} reviews)" if item.get('rating') else None,
                url=item.get("link"),
                image_url=item.get("image")
            ))
    
    return SearchResponse(results=results, count=len(results))


if __name__ == "__main__":
    print("🛒 Starting Amazon Search HTTP Server on port 8003...")
    uvicorn.run(app, host="127.0.0.1", port=8003)
