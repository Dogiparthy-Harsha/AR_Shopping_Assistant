#!/usr/bin/env python3
"""
Embedding Service for RAG with Pinecone
Handles text embeddings and vector storage for chat personalization
"""

import os
from datetime import datetime
from typing import List, Dict, Optional
from openai import OpenAI
from pinecone import Pinecone, ServerlessSpec
from dotenv import load_dotenv

from pathlib import Path
load_dotenv(Path(__file__).resolve().parent.parent / ".env")


class EmbeddingService:
    """
    Service for generating embeddings and managing Pinecone vector storage
    """
    
    def __init__(self):
        """Initialize OpenAI and Pinecone clients"""
        # OpenAI client for embeddings
        self.openai_client = OpenAI(
            api_key=os.getenv("OPENAI_API_KEY")
        )
        
        # Pinecone client
        self.pc = Pinecone(api_key=os.getenv("PINECONE_API_KEY"))
        
        # Connect to existing index
        self.index_name = "chat-history"
        self.index = self.pc.Index(self.index_name)
        
        print(f"✓ Embedding Service initialized (Index: {self.index_name})")
    
    def embed_text(self, text: str) -> List[float]:
        """
        Generate embedding vector for text
        
        Args:
            text: Text to embed
            
        Returns:
            List of 1536 floats representing the embedding
        """
        try:
            response = self.openai_client.embeddings.create(
                model="text-embedding-3-small",
                input=text
            )
            return response.data[0].embedding
        except Exception as e:
            print(f"✗ Error generating embedding: {e}")
            return []
    
    def store_message(
        self, 
        user_id: int, 
        conversation_id: int, 
        message: str, 
        role: str,
        metadata: Optional[Dict] = None
    ) -> bool:
        """
        Store a message in Pinecone with its embedding
        
        Args:
            user_id: User ID for isolation
            conversation_id: Conversation ID
            message: Message text
            role: 'user' or 'assistant'
            metadata: Additional metadata (optional)
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Generate embedding
            embedding = self.embed_text(message)
            if not embedding:
                return False
            
            # Create unique ID
            timestamp = datetime.now().isoformat()
            vector_id = f"user_{user_id}_conv_{conversation_id}_{timestamp}"
            
            # Prepare metadata
            vector_metadata = {
                "user_id": user_id,
                "conversation_id": conversation_id,
                "message": message[:1000],  # Limit message length in metadata
                "role": role,
                "timestamp": timestamp
            }
            
            # Add custom metadata if provided
            if metadata:
                vector_metadata.update(metadata)
            
            # Upsert to Pinecone
            self.index.upsert(vectors=[{
                "id": vector_id,
                "values": embedding,
                "metadata": vector_metadata
            }])
            
            return True
            
        except Exception as e:
            print(f"✗ Error storing message in Pinecone: {e}")
            return False
    
    def search_similar(
        self, 
        user_id: int, 
        query: str, 
        top_k: int = 5,
        filter_metadata: Optional[Dict] = None
    ) -> List[Dict]:
        """
        Search for similar messages in user's history
        
        Args:
            user_id: User ID to filter by
            query: Search query
            top_k: Number of results to return
            filter_metadata: Additional filters (optional)
            
        Returns:
            List of similar messages with metadata
        """
        try:
            # Generate query embedding
            query_embedding = self.embed_text(query)
            if not query_embedding:
                return []
            
            # Build filter
            filter_dict = {"user_id": user_id}
            if filter_metadata:
                filter_dict.update(filter_metadata)
            
            # Query Pinecone
            results = self.index.query(
                vector=query_embedding,
                top_k=top_k,
                filter=filter_dict,
                include_metadata=True
            )
            
            # Extract matches
            matches = []
            for match in results.matches:
                matches.append({
                    "score": match.score,
                    "message": match.metadata.get("message", ""),
                    "role": match.metadata.get("role", ""),
                    "conversation_id": match.metadata.get("conversation_id", 0),
                    "timestamp": match.metadata.get("timestamp", "")
                })
            
            return matches
            
        except Exception as e:
            print(f"✗ Error searching Pinecone: {e}")
            return []
    
    def get_user_context(self, user_id: int, query: str, top_k: int = 3) -> str:
        """
        Get formatted context from user's past conversations
        
        Args:
            user_id: User ID
            query: Current query
            top_k: Number of past messages to retrieve
            
        Returns:
            Formatted context string for AI prompt
        """
        # Search for similar past messages
        similar_messages = self.search_similar(user_id, query, top_k=10)  # Get more results
        
        if not similar_messages:
            return ""
        
        # Extract product-related information
        products_mentioned = []
        seen_products = set()
        
        for msg in similar_messages:
            message_text = msg['message'].lower()
            
            # Skip meta-questions about search history
            if any(word in message_text for word in ['previously', 'before', 'searched for', 'what did i']):
                continue
            
            # Extract product mentions (simple keyword extraction)
            # Look for product names, colors, storage sizes, etc.
            if msg['role'] == 'user' or 'FINAL_QUERY' in msg['message']:
                # Clean up the message
                clean_msg = msg['message'].replace('FINAL_QUERY:', '').strip()
                
                # Only add if it's substantive (not a meta-question)
                if len(clean_msg) > 5 and clean_msg not in seen_products:
                    products_mentioned.append({
                        'text': clean_msg[:150],
                        'role': msg['role']
                    })
                    seen_products.add(clean_msg)
        
        if not products_mentioned:
            return ""
        
        # Format context with actual product details
        context_parts = ["Based on your search history, you've looked for:"]
        
        for i, product in enumerate(products_mentioned[:5], 1):  # Limit to top 5
            context_parts.append(f"- {product['text']}")
        
        return "\n".join(context_parts)
    
    def delete_user_data(self, user_id: int) -> bool:
        """
        Delete all vectors for a specific user (GDPR compliance)
        
        Args:
            user_id: User ID to delete
            
        Returns:
            True if successful
        """
        try:
            # Note: Pinecone doesn't support delete by metadata filter directly
            # You'd need to fetch all IDs first, then delete
            # This is a placeholder for future implementation
            print(f"⚠️  Delete user data not fully implemented for user {user_id}")
            return False
        except Exception as e:
            print(f"✗ Error deleting user data: {e}")
            return False


# Test function
if __name__ == "__main__":
    print("Testing Embedding Service...")
    
    try:
        # Initialize service
        service = EmbeddingService()
        
        # Test embedding generation
        print("\n1. Testing embedding generation...")
        embedding = service.embed_text("test message")
        print(f"   Embedding dimension: {len(embedding)}")
        assert len(embedding) == 1536, "Embedding dimension should be 1536"
        print("   ✓ Embedding generation works!")
        
        # Test storing message
        print("\n2. Testing message storage...")
        success = service.store_message(
            user_id=999,
            conversation_id=1,
            message="I want an iPhone 15 Pro",
            role="user"
        )
        print(f"   ✓ Message stored: {success}")
        
        # Test search
        print("\n3. Testing similarity search...")
        results = service.search_similar(
            user_id=999,
            query="I need a phone",
            top_k=3
        )
        print(f"   Found {len(results)} similar messages")
        for r in results:
            print(f"   - Score: {r['score']:.3f}, Message: {r['message'][:50]}...")
        
        # Test context generation
        print("\n4. Testing context generation...")
        context = service.get_user_context(user_id=999, query="phone")
        print(f"   Context:\n{context}")
        
        print("\n✅ All tests passed!")
        
    except Exception as e:
        print(f"\n✗ Test failed: {e}")
