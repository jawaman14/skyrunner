import os
import sys
import tempfile
import unittest
import sqlite3

sys.path.insert(0, os.path.dirname(__file__))
import notify


class TestCursorHelpers(unittest.TestCase):
    """Tests for read_cursor and write_cursor in notify.py."""

    def setUp(self):
        """Create an in-memory SQLite board with some notes."""
        self.db = sqlite3.connect(":memory:")
        self.db.execute(
            "CREATE TABLE notes (id INTEGER PRIMARY KEY, author TEXT, recipient TEXT, text TEXT, created REAL)"
        )
        # Insert a few rows
        self.db.execute("INSERT INTO notes VALUES (1, 'alice', 'bob', 'Hello Bob', 1.0)")
        self.db.execute("INSERT INTO notes VALUES (2, 'bob', 'alice', 'Hi Alice', 2.0)")
        self.db.execute("INSERT INTO notes VALUES (3, 'charlie', 'all', 'Hello All', 3.0)")
        self.db.commit()
        
        # Create a temporary directory for cursor files
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        self.db.close()
        # Clean up temp dir
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def _cursor_path(self, name):
        return os.path.join(self.tmpdir, name)

    # --- read_cursor tests ---

    def test_read_cursor_missing_file_fallback(self):
        """If cursor file does not exist, return the max id from the board."""
        path = self._cursor_path("missing.txt")
        result = notify.read_cursor(path, self.db, "bob")
        # Max id in our test data is 3
        self.assertEqual(result, 3)

    def test_read_cursor_empty_file_fallback(self):
        """If cursor file is empty, fall back to max id."""
        path = self._cursor_path("empty.txt")
        with open(path, "w") as f:
            f.write("")
        result = notify.read_cursor(path, self.db, "bob")
        self.assertEqual(result, 3)

    def test_read_cursor_non_numeric_file_fallback(self):
        """If cursor file contains non-numeric text, fall back to max id."""
        path = self._cursor_path("bad.txt")
        with open(path, "w") as f:
            f.write("not a number")
        result = notify.read_cursor(path, self.db, "bob")
        self.assertEqual(result, 3)

    def test_read_cursor_valid_number(self):
        """If cursor file contains a valid integer, return it as int."""
        path = self._cursor_path("valid.txt")
        with open(path, "w") as f:
            f.write("  2  \n")  # Whitespace should be stripped
        result = notify.read_cursor(path, self.db, "bob")
        self.assertEqual(result, 2)
        self.assertIsInstance(result, int)

    def test_read_cursor_no_path(self):
        """If path is empty/None, fall back to max id."""
        result = notify.read_cursor("", self.db, "bob")
        self.assertEqual(result, 3)
        
        result = notify.read_cursor(None, self.db, "bob")
        self.assertEqual(result, 3)

    # --- write_cursor tests ---

    def test_write_cursor_empty_path_writes_nothing(self):
        """If path is empty, write_cursor should do nothing."""
        # This should not raise an error
        notify.write_cursor("", 5)
        # No file should be created in current dir or anywhere specific
        # We just verify it doesn't crash.

    def test_write_cursor_creates_parent_folders(self):
        """write_cursor should create missing parent directories."""
        nested_path = self._cursor_path("deep/nested/dir/cursor.txt")
        # Ensure the directory doesn't exist yet
        self.assertFalse(os.path.exists(os.path.dirname(nested_path)))
        
        notify.write_cursor(nested_path, 10)
        
        self.assertTrue(os.path.exists(nested_path))
        with open(nested_path, "r") as f:
            content = f.read()
        self.assertEqual(content, "10")

    def test_write_cursor_writes_value(self):
        """write_cursor should write the value as a string."""
        path = self._cursor_path("simple.txt")
        notify.write_cursor(path, 42)
        
        with open(path, "r") as f:
            content = f.read()
        self.assertEqual(content, "42")


if __name__ == "__main__":
    unittest.main()
