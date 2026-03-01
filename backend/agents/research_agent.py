#!/usr/bin/env python3
"""
Research Agent - Specialized AI agent for product verification and web search
This agent uses web search to verify product existence and gather current information
"""

import os
import requests
from typing import Dict, Optional
from openai import OpenAI
from dotenv import load_dotenv

from pathlib import Path
load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")

class ResearchAgent:
    """
    An AI agent specialized in researching products using web search.
    It can verify if products exist and gather current information about them.
    """
    
    def __init__(self, openrouter_api_key: str, serper_api_key: str):
        """
        Initialize the research agent with API keys
        
        Args:
            openrouter_api_key: API key for OpenRouter (AI)
            serper_api_key: API key for Serper (web search)
        """
        self.serper_api_key = serper_api_key
        
        # Initialize AI client for analysis
        self.ai_client = OpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=openrouter_api_key,
            default_headers={
                "HTTP-Referer": "http://localhost",
                "X-Title": "Research-Agent"
            },
        )
    
    def web_search(self, query: str, num_results: int = 5) -> Dict:
        """
        Perform a web search using Serper API
        
        Args:
            query: Search query
            num_results: Number of results to return
            
        Returns:
            Dictionary containing search results
        """
        url = "https://google.serper.dev/search"
        
        payload = {
            "q": query,
            "num": num_results
        }
        
        headers = {
            "X-API-KEY": self.serper_api_key,
            "Content-Type": "application/json"
        }
        
        try:
            response = requests.post(url, json=payload, headers=headers)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Error performing web search: {e}")
            return {}
    
    def verify_product(self, product_name: str) -> Dict[str, any]:
        """
        Verify if a product exists and gather information about it
        
        Args:
            product_name: Name of the product to verify
            
        Returns:
            Dictionary with:
                - exists: bool (whether product exists)
                - info: str (information about the product)
                - confidence: str (high/medium/low)
        """
        # Step 1: Search the web for the product
        search_query = f"{product_name} official release date specs"
        search_results = self.web_search(search_query, num_results=5)
        
        if not search_results or "organic" not in search_results:
            return {
                "exists": False,
                "info": "Unable to find information about this product.",
                "confidence": "low"
            }
        
        # Step 2: Extract relevant information from search results
        context = self._extract_search_context(search_results)
        print(f"🔍 Research Agent Context:\n{context}") # DEBUG PRINT
        
        # Step 3: Use AI to analyze the search results
        analysis = self._analyze_with_ai(product_name, context)
        
        return analysis
    
    def _extract_search_context(self, search_results: Dict) -> str:
        """
        Extract relevant text from search results
        
        Args:
            search_results: Raw search results from Serper
            
        Returns:
            Formatted string with search context
        """
        context_parts = []
        
        # Extract organic results
        if "organic" in search_results:
            for i, result in enumerate(search_results["organic"][:5], 1):
                title = result.get("title", "")
                snippet = result.get("snippet", "")
                context_parts.append(f"{i}. {title}\n   {snippet}")
        
        # Extract knowledge graph if available
        if "knowledgeGraph" in search_results:
            kg = search_results["knowledgeGraph"]
            title = kg.get("title", "")
            description = kg.get("description", "")
            if title or description:
                context_parts.insert(0, f"Knowledge Graph:\n{title}\n{description}")
        
        return "\n\n".join(context_parts)
    
    def _analyze_with_ai(self, product_name: str, search_context: str) -> Dict[str, any]:
        """
        Use AI to analyze search results and determine product existence
        
        Args:
            product_name: Name of the product
            search_context: Context from web search
            
        Returns:
            Dictionary with analysis results
        """
        from datetime import datetime
        current_date = datetime.now().strftime("%B %d, %Y")
        
        prompt = f"""Today's date is {current_date}.

You are a research agent analyzing web search results to verify if a product is CURRENTLY AVAILABLE for purchase.

Product being researched: {product_name}

Web search results:
{search_context}

CRITICAL RULES (follow in order):

1. DATE COMPARISON IS YOUR PRIMARY TOOL:
   - If you find a release date for this SPECIFIC product, compare it to today ({current_date}).
   - If the release date is ON or BEFORE today, the product IS RELEASED and EXISTS. Set exists=true, release_status="available".
   - If the release date is AFTER today, it is NOT YET RELEASED. Set exists=false, release_status="upcoming".

2. IGNORE SUCCESSOR/NEXT-GEN PRODUCTS:
   - Search results often mention FUTURE models (e.g., "iPhone 18" in an article about "iPhone 17").
   - ONLY consider information about the EXACT product being researched: "{product_name}".
   - If a sentence says "new models not expected until [date]", that refers to the NEXT generation, NOT the product being researched.
   - Do NOT confuse the product's release date with the release date of its successor.

3. TRUST SHOPPING SIGNALS:
   - If search results contain "Buy", "Shop", "Price", "$", "In Stock", "Add to Cart", or retailer names (Amazon, Best Buy, eBay, etc.), the product EXISTS and is available.
   - These signals override any ambiguity.

4. If a product is only "rumored", "leaked", "expected", or has NO confirmed release date, set exists=false.

5. When in doubt and no clear signals exist, default to exists=true to avoid blocking valid searches.

Based on these search results, provide a JSON response with:
1. "exists": true/false - Is this product currently available for purchase?
2. "info": A brief 1-2 sentence summary. If it doesn't exist yet, mention when it's expected.
3. "confidence": "high"/"medium"/"low" - How confident are you?
4. "release_status": "available"/"upcoming"/"rumored"/"unknown" - Current status

Respond ONLY with valid JSON, no other text.
"""
        
        try:
            response = self.ai_client.chat.completions.create(
                model="google/gemini-2.5-flash-lite",  # Using faster model for quick analysis
                messages=[
                    {"role": "system", "content": "You are a research analyst. Respond only with valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3  # Lower temperature for more factual responses
            )
            
            import json
            result_text = response.choices[0].message.content.strip()
            
            # Try to extract JSON if wrapped in markdown code blocks
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            analysis = json.loads(result_text)
            return analysis
            
        except Exception as e:
            print(f"Error analyzing with AI: {e}")
            return {
                "exists": True,  # Default to true to avoid blocking searches
                "info": "Unable to verify product details, but proceeding with search.",
                "confidence": "low"
            }


# Example usage
if __name__ == "__main__":
    # Test the research agent
    OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
    SERPER_API_KEY = os.environ.get("SERPER_API_KEY")
    
    if not SERPER_API_KEY:
        print("⚠️  SERPER_API_KEY not found in .env file")
        print("Please add it to continue. Get a free key at https://serper.dev")
        exit(1)
    
    agent = ResearchAgent(OPENROUTER_API_KEY, SERPER_API_KEY)
    
    # Test with a product
    print("Testing Research Agent...")
    print("-" * 50)
    
    test_product = "iPhone 17"
    print(f"Researching: {test_product}")
    result = agent.verify_product(test_product)
    
    print(f"\nExists: {result['exists']}")
    print(f"Info: {result['info']}")
    print(f"Confidence: {result['confidence']}")
