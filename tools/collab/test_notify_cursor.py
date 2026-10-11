#!/usr/bin/env python3
"""Tests for cursor helpers in tools/collab/notify.py."""
import os
import sys
import sqlite3
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import notify


class TestCursorHelpers(unittest.TestCase):
    """Test read_cursor and write_cursor with an in-memory SQLite board."""

    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.execute("""
            CREATE TABLE notes (id INTEGER PRIMARY KEY, author TEXT, recipient TEXT, text TEXT, created REAL)
        """)
        # Insert a few rows so the newest id is 5.
        for i in range(1, 6):
            self.db.execute(
                "INSERT INTO notes VALUES (?, ?, ?, ?, ?)",
                (i, f"author{i}", "all", f"text {i}", 0.0),
            )
        self.db.commit()

    def test_read_cursor_missing_file(self):
        """Missing cursor file falls back to the board's newest note id."""
        after = notify.read_cursor("", self.db, "all")
        self.assertEqual(after, 5)

    def test_read_cursor_empty_file(self):
        """Empty cursor file falls back to the board's newest note id."""
        with tempfile.NamedTemporaryFile(mode="w", delete=False, suffix=".cur") as f:
            path = f.name
        try:
            after = notify.read_cursor(path, self.db, "all")
            self.assertEqual(after, 5)
        finally:
            os.unlink(path)

    def test_read_cursor_non_numeric_file(self):
        """Non-numeric cursor file falls back to the board's newest note id."""
        with tempfile.NamedTemporaryFile(mode="w", delete=False, suffix=".cur") as f:
            f.write("not a number")
            path = f.name
        try:
            after = notify.read_cursor(path, self.db, "all")
            self.assertEqual(after, 5)
        finally:
            os.unlink(path)

    def test_read_cursor_valid_number(self):
        """A valid numeric cursor file returns the number as an int."""
        with tempfile.NamedTemporaryFile(mode="w", delete=False, suffix=".cur") as f:
            f.write("3")
            path = f.name
        try:
            after = notify.read_cursor(path, self.db, "all")
            self.assertEqual(after, 3)
        finally:
            os.unlink(path)

    def test_write_cursor_empty_path(self):
        """write_cursor with an empty path writes nothing."""
        notify.write_cursor("", 5)
        # No file should be created.
        self.assertFalse(os.path.exists(""))

    def test_write_cursor_creates_missing_parent_folders(self):
        """write_cursor creates missing parent folders when the path requires them."""
        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "sub", "folder", "cursor.cur")
            notify.write_cursor(path, 5)
            self.assertTrue(os.path.exists(path))
            with open(path, encoding="utf-8") as f:
                self.assertEqual(f.read().strip(), "5")


if __name__ == "__main__":
    unittest.main()
