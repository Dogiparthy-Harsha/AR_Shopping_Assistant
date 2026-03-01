#!/usr/bin/env python3
"""
One-shot migration: Add image_data column to the chats table.
Run this once to update an existing app.db.
Safe to run multiple times — it checks if the column already exists.
"""

import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "app.db")

def migrate():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Check if column already exists
    cursor.execute("PRAGMA table_info(chats)")
    columns = [col[1] for col in cursor.fetchall()]

    if "image_data" not in columns:
        print("Adding 'image_data' column to 'chats' table...")
        cursor.execute("ALTER TABLE chats ADD COLUMN image_data TEXT")
        conn.commit()
        print("✓ Migration complete.")
    else:
        print("✓ Column 'image_data' already exists. Nothing to do.")

    conn.close()

if __name__ == "__main__":
    migrate()
