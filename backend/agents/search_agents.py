#!/usr/bin/env python3
"""
eBay & Amazon Product Search Script
Searches eBay and Amazon products using their respective APIs,
orchestrated by a Gemini AI assistant.
"""

import requests
import json
import base64
import os
from typing import Dict, List, Optional
# import google.generativeai as genai
from openai import OpenAI
from dotenv import load_dotenv

# --- Load All API Keys from .env file ---
from pathlib import Path
load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")
EBAY_CLIENT_ID = os.environ.get("EBAY_CLIENT_ID")
EBAY_CLIENT_SECRET = os.environ.get("EBAY_CLIENT_SECRET")
# GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
##AMAZON_API_KEY = os.environ.get("AMAZON_API_KEY")
#AMAZON_API_ENDPOINT = os.environ.get("AMAZON_API_ENDPOINT") # The POST URL for your Bright Data scraper
RAINFOREST_API_KEY = os.environ.get("RAINFOREST_API_KEY")

# ==============================================================================
# eBaySearch CLASS (No changes here)
# ==============================================================================
class eBaySearch:
    """Class to handle eBay API searches."""
    
    def __init__(self, client_id: str, client_secret: str):
        """
        Initialize eBay Search with API credentials.
        
        Args:
            client_id: eBay Application Client ID
            client_secret: eBay Application Client Secret
        """
        self.client_id = client_id
        self.client_secret = client_secret
        self.access_token = None
        # Using Production URLs as seen in your .env file
        self.base_url = "https://api.ebay.com"
        self.token_url = "https://api.ebay.com/identity/v1/oauth2/token"
        self.search_endpoint = "/buy/browse/v1/item_summary/search"
        
    def get_access_token(self) -> bool:
        """Get OAuth2 access token."""
        try:
            credentials = f"{self.client_id}:{self.client_secret}"
            encoded_credentials = base64.b64encode(credentials.encode()).decode()
            
            headers = {
                "Content-Type": "application/x-www-form-urlencoded",
                "Authorization": f"Basic {encoded_credentials}"
            }
            data = {
                "grant_type": "client_credentials",
                "scope": "https://api.ebay.com/oauth/api_scope"
            }
            
            response = requests.post(self.token_url, headers=headers, data=data)
            response.raise_for_status()
            
            token_data = response.json()
            self.access_token = token_data.get("access_token")
            
            if self.access_token:
                print("✓ Successfully obtained eBay access token")
                return True
            else:
                print("✗ Failed to obtain eBay access token")
                return False
                
        except requests.exceptions.RequestException as e:
            print(f"✗ Error obtaining eBay access token: {e}")
            if hasattr(e.response, 'text'):
                print(f"Response: {e.response.text}")
            return False
    
    def search_items(self, query: str, limit: int = 4) -> Optional[Dict]:
        """Search for items on eBay."""
        if not self.access_token:
            print("✗ No eBay access token. Please authenticate first.")
            return None
        
        try:
            headers = {
                "Authorization": f"Bearer {self.access_token}",
                "X-EBAY-C-MARKETPLACE-ID": "EBAY_US",
                "Content-Type": "application/json"
            }
            params = {
                "q": query,
                "limit": min(max(limit, 1), 200)
            }
            
            url = f"{self.base_url}{self.search_endpoint}"
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            
            return response.json()
            
        except requests.exceptions.RequestException as e:
            print(f"✗ Error searching eBay: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"Response: {e.response.text}")
            return None
    
    def display_results(self, results: Dict):
        """Display eBay search results."""
        if not results:
            print("No eBay results to display.")
            return
        
        item_summaries = results.get("itemSummaries", [])
        total = results.get("total", 0)
        
        # We only display the top 4 (or fewer)
        results_to_display = item_summaries[:4]
        
        print(f"\n{'='*80}")
        print(f"Found {total} item(s) on eBay")
        print(f"Displaying {len(results_to_display)} result(s):")
        print(f"{'='*80}\n")
        
        if not results_to_display:
            print("No eBay items found matching your search criteria.")
            return
        
        for idx, item in enumerate(results_to_display, 1):
            title = item.get("title", "N/A")
            price = item.get("price", {})
            price_value = price.get("value", "N/A")
            price_currency = price.get("currency", "USD")
            condition = item.get("condition", "N/A")
            item_web_url = item.get("itemWebUrl", "N/A")
            
            print(f"{idx}. {title}")
            print(f"   Price: {price_value} {price_currency}")
            print(f"   Condition: {condition}")
            print(f"   URL: {item_web_url}")
            print(f"   {'-'*78}")

# ==============================================================================
# NEW AmazonSearch CLASS
# ==============================================================================
# ==============================================================================
# NEW RainforestSearch CLASS
# ==============================================================================
class RainforestSearch:
    """Class to handle Rainforest API (Amazon) searches."""
    
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://api.rainforestapi.com/request"
        
    def search_items(self, query: str) -> Optional[Dict]:
        """
        Search for items on Amazon using Rainforest API.
        """
        if not self.api_key:
            print("✗ Error: RAINFOREST_API_KEY not found in .env file.")
            return None
            
        # These are the parameters for a Rainforest "search" request
        params = {
            "api_key": self.api_key,
            "type": "search",
            "amazon_domain": "amazon.com",
            "search_term": query
        }
        
        print(f"\nSearching Amazon (via Rainforest) for: '{query}'...")
        
        try:
            response = requests.get(self.base_url, params=params)
            response.raise_for_status() # Raises an error for bad responses (4xx or 5xx)
            
            # Return the JSON response
            return response.json() 
            
        except requests.exceptions.RequestException as e:
            print(f"✗ Error searching Amazon (Rainforest): {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"Response: {e.response.text[:500]}...")
            return None
# ==============================================================================
# NEW Amazon Display Function
# ==============================================================================
# def display_amazon_results(results: List[Dict]):
#     """
#     Display Amazon search results in a formatted way.
#     NOTE: This is a BEST-GUESS parser. You MUST check the JSON output
#     from a real search and update the keys (e.g., 'title', 'price_string').
#     """
#     if not results:
#         print("\nNo Amazon results to display.")
#         return
    
#     # Slice to get max 4 results
#     results_to_display = results[:4]
    
#     print(f"\n{'='*80}")
#     print(f"Found {len(results)} item(s) on Amazon")
#     print(f"Displaying {len(results_to_display)} result(s):")
#     print(f"{'='*80}\n")
    
#     if not results_to_display:
#         print("No Amazon items found matching your search criteria.")
#         return

#     print("!!! WARNING: Amazon field names are a guess. You may need to edit 'display_amazon_results' in the code. !!!\n")
    
#     for idx, item in enumerate(results_to_display, 1):
#         # --- YOU MUST UPDATE THESE KEYS ---
#         # Run a search, look at the JSON, and find the *real* keys
#         title = item.get("title", "N/A (Check key 'title')")
#         price_str = item.get("price_string", "N/A (Check key 'price_string')")
        
#         if price_str == "N/A (Check key 'price_string')":
#              price_str = f"${item.get('price', 'N/A (Check key price)')}" # Fallback
        
#         url = item.get("url", "N/A (Check key 'url')")
#         if not url.startswith("http"):
#             url = f"https://www.amazon.com{url}"
        
#         rating = item.get("rating", "N/A")
#         reviews_count = item.get("reviews_count", "N/A")
#         # --- END OF KEYS TO UPDATE ---
        
#         print(f"{idx}. {title}")
#         print(f"   Price: {price_str}")
#         print(f"   Rating: {rating} stars ({reviews_count} reviews)")
#         print(f"   URL: {url}")
#         print(f"   {'-'*78}")

# ==============================================================================
# NEW Rainforest Display Function
# ==============================================================================
def display_rainforest_results(results: Dict):
    """
    Display Rainforest (Amazon) search results in a formatted way.
    
    NOTE: This parser is based on standard Rainforest "search" results.
    You may still need to add your debug print line to confirm keys.
    """
    if not results:
        print("\nNo Amazon results to display.")
        return

    # Rainforest puts search results in a 'search_results' list
    search_results = results.get("search_results", [])
    
    # Slice to get max 4 results
    results_to_display = search_results[:4]
    
    print(f"\n{'='*80}")
    print(f"Found {len(search_results)} item(s) on Amazon (via Rainforest)")
    print(f"Displaying {len(results_to_display)} result(s):")
    print(f"{'='*80}\n")
    
    if not results_to_display:
        print("No Amazon items found matching your search criteria.")
        return

    for idx, item in enumerate(results_to_display, 1):
        # --- These keys are standard for Rainforest ---
        title = item.get("title", "N/A")
        price = item.get("price", {}).get("raw", "N/A") # Get the 'raw' price string, e.g., "$19.99"
        link = item.get("link", "N/A")
        rating = item.get("rating", "N/A")
        ratings_total = item.get("ratings_total", 0)
        # --- End of keys ---
        
        print(f"{idx}. {title}")
        print(f"   Price: {price}")
        print(f"   Rating: {rating} stars ({ratings_total} reviews)")
        print(f"   URL: {link}")
        print(f"   {'-'*78}")

# ==============================================================================
# UPDATED main() Function
# ==============================================================================
# def main():
#     """Main function to run the eBay and Amazon search."""
#     print("="*80)
#     print("eBay & Amazon AI-Powered Product Search")
#     print("="*80)
    
#     # --- 1. eBay Setup ---
#     if not EBAY_CLIENT_ID or not EBAY_CLIENT_SECRET:
#         print("✗ Error: eBay Client ID and Client Secret not found in .env file.")
#         return
#     ebay = eBaySearch(EBAY_CLIENT_ID, EBAY_CLIENT_SECRET)
#     print("\nAuthenticating with eBay API...")
#     if not ebay.get_access_token():
#         print("✗ Failed to authenticate with eBay. Please check your credentials.")
#         return
        
#     # --- 2. Amazon Setup ---
#     if not RAINFOREST_API_KEY:
#         print("✗ Error: RAINFOREST_API_KEY not found in .env file.")
#         print("   Please add it to your .env file.")
#         return

#     amazon = RainforestSearch(RAINFOREST_API_KEY)
#     print("✓ Amazon (Rainforest) API credentials loaded.")
        
#     # --- 3. AI Setup (CHANGED FOR OPENROUTER) ---
#     if not OPENROUTER_API_KEY:
#         print("✗ Error: OPENROUTER_API_KEY not found in .env file.")
#         return
        
#     try:
#         # This is the new OpenAI client, configured for OpenRouter
#         client = OpenAI(
#             base_url="https://openrouter.ai/api/v1",
#             api_key=OPENROUTER_API_KEY,
#             default_headers={
#                 "HTTP-Referer": "http://localhost", # Optional, but good practice
#                 "X-Title": "eBay-Amazon-Search"     # Optional, but good practice
#             },
#         )
#         print("✓ Successfully configured AI with OpenRouter")
#     except Exception as e:
#         print(f"✗ Error configuring OpenRouter client: {e}")
#         return

#     # --- 4. Main Search Loop ---
#     while True:
#         print("\n" + "="*80)
        
#         system_prompt = (
#             "You are a helpful search assistant for eBay and Amazon. "
#             "Your goal is to ask the user 1-2 follow-up questions to get key details "
#             "(like model, color, size, condition, storage, or budget) to refine their search. "
#             "Once you have enough details, your *very last* message must ONLY be the "
#             "final search query, prefixed with 'FINAL_QUERY:'. "
#             "For example: 'FINAL_QUERY: iPhone 15 Pro Max 256GB new'"
#         )
        
#         # --- CHANGED: Manual Chat History ---
#         # We must now manually keep track of the conversation
#         chat_history = [
#             {"role": "system", "content": system_prompt},
#             {"role": "assistant", "content": "OK, I understand. I will help you find the best deals on eBay and Amazon. What are you looking for today?"}
#         ]

#         print("AI: OK, I understand. I will help you find the best deals on eBay and Amazon.")
#         user_input = input("AI: What are you looking for today?\nYou: ").strip()

#         if user_input.lower() in ['quit', 'exit', 'q']:
#             print("Goodbye!")
#             break

#         final_query = ""

#         # --- 5. Inner AI Chat Loop (CHANGED FOR OPENAI SYNTAX) ---
#         while True:
#             try:
#                 # Add the user's last message to the history
#                 chat_history.append({"role": "user", "content": user_input})
                
#                 # Make the API call to OpenRouter
#                 response = client.chat.completions.create(
#                     model="google/gemini-2.5-flash-lite",  # Use an OpenRouter model name. This one is fast and cheap.
#                     messages=chat_history
#                 )
                
#                 ai_message = response.choices[0].message.content.strip()
                
#                 # Add the AI's response to the history
#                 chat_history.append({"role": "assistant", "content": ai_message})
                
#                 # Check if the AI has decided on a final query
#                 if ai_message.startswith("FINAL_QUERY:"):
#                     final_query = ai_message.replace("FINAL_QUERY:", "").strip()
#                     print(f"\nAI: Great! I will search both eBay and Amazon for: '{final_query}'")
#                     break 
                
#                 # If not a final query, just print the AI's question
#                 print(f"\nAI: {ai_message}")
                
#                 # Get the user's answer
#                 user_input = input("You: ").strip()
#                 if user_input.lower() in ['quit', 'exit', 'q']:
#                     break
            
#             except Exception as e:
#                 print(f"✗ Error communicating with OpenRouter: {e}")
#                 break 

#         if final_query:
#             # --- 6. Search Both APIs (No changes here) ---
#             print(f"\nSearching eBay for: '{final_query}'...")
#             ebay_results = ebay.search_items(final_query, limit=4)
            
#             amazon_results = amazon.search_items(final_query)
#             # Add this debug print if you're still testing the Amazon parser:
#             # print(f"DEBUG: Amazon raw data: {amazon_results}") 
            
#             # --- Display All Results (Using the fix from last time) ---
#             if ebay_results:
#              ebay.display_results(ebay_results)
#             else:
#              print("✗ No eBay results found or an error occurred.")

#             if amazon_results is not None: # Check for None (an error)
#                  display_rainforest_results(amazon_results) # <-- CHANGED function name
#             else:
#                 print("✗ An Amazon (Rainforest) API error occurred.")
        
#         # Check if user wants to search again
#         continue_search = input("\nSearch again? (y/n): ").strip().lower()
#         if continue_search not in ['y', 'yes']:
#             print("Goodbye!")
#             break

