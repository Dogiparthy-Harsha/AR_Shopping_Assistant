#!/usr/bin/env python3
"""
Backfill Pinecone with existing chat history from SQLite
Run this once to populate Pinecone with all past conversations
"""

from embeddings import EmbeddingService
from database import SessionLocal
import models
from dotenv import load_dotenv

from pathlib import Path
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

def backfill_pinecone():
    """
    Read all messages from SQLite and store them in Pinecone
    """
    print("🔄 Starting Pinecone backfill...")
    
    # Initialize services
    db = SessionLocal()
    embedding_service = EmbeddingService()
    
    # Get all chat messages
    all_messages = db.query(models.Chat).order_by(models.Chat.timestamp.asc()).all()
    
    print(f"📊 Found {len(all_messages)} messages in database")
    
    success_count = 0
    error_count = 0
    
    for i, msg in enumerate(all_messages, 1):
        try:
            # Get user_id from conversation
            conversation = db.query(models.Conversation).filter(
                models.Conversation.id == msg.conversation_id
            ).first()
            
            if not conversation:
                print(f"⚠️  Skipping message {i}: No conversation found")
                continue
            
            # Store in Pinecone
            embedding_service.store_message(
                user_id=conversation.user_id,
                conversation_id=msg.conversation_id,
                message=msg.message,
                role=msg.role
            )
            
            success_count += 1
            
            if i % 10 == 0:
                print(f"✓ Processed {i}/{len(all_messages)} messages...")
                
        except Exception as e:
            error_count += 1
            print(f"✗ Error processing message {i}: {e}")
    
    db.close()
    
    print(f"\n✅ Backfill complete!")
    print(f"   Success: {success_count}")
    print(f"   Errors: {error_count}")
    print(f"   Total: {len(all_messages)}")

if __name__ == "__main__":
    backfill_pinecone()
