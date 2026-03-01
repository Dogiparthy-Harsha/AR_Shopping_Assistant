#!/usr/bin/env python3
"""
eBay Search Agent - HTTP Server
Provides eBay product search functionality
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

# Import eBay search
from agents import eBaySearch

from pathlib import Path
load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")

# Initialize FastAPI
app = FastAPI(title="eBay Search MCP Server")

# Initialize eBay Search
EBAY_CLIENT_ID = os.environ.get("EBAY_CLIENT_ID")
EBAY_CLIENT_SECRET = os.environ.get("EBAY_CLIENT_SECRET")

print("Authenticating with eBay API...")
ebay = eBaySearch(EBAY_CLIENT_ID, EBAY_CLIENT_SECRET)
ebay.get_access_token()
print("✓ eBay Search initialized")


# Request/Response Models
class SearchRequest(BaseModel):
    query: str
    limit: int = 4


class ProductResult(BaseModel):
    title: Optional[str]
    price: Optional[str]
    condition: Optional[str]
    url: Optional[str]
    image_url: Optional[str]


class SearchResponse(BaseModel):
    results: List[ProductResult]
    count: int


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "ebay-search"}


@app.post("/search", response_model=SearchResponse)
async def search_ebay(request: SearchRequest):
    """Search for products on eBay"""
    ebay_data = ebay.search_items(request.query, limit=request.limit)
    
    results = []
    if ebay_data and "itemSummaries" in ebay_data:
        for item in ebay_data["itemSummaries"][:request.limit]:
            results.append(ProductResult(
                title=item.get("title"),
                price=f"{item.get('price', {}).get('value')} {item.get('price', {}).get('currency')}",
                condition=item.get("condition"),
                url=item.get("itemWebUrl"),
                image_url=item.get("image", {}).get("imageUrl")
            ))
    
    return SearchResponse(results=results, count=len(results))


if __name__ == "__main__":
    print("🛒 Starting eBay Search HTTP Server on port 8002...")
    uvicorn.run(app, host="127.0.0.1", port=8002)
