import unittest
from ohamlab_harness.cli import main
from ohamlab_harness.runtime import default_home

class CLITests(unittest.TestCase):
    def test_status(self):
        self.assertEqual(main(["status", "--home", "/tmp/nonexistent-ohamlab-test"]), 0)
    def test_home(self):
        self.assertTrue(str(default_home()))

if __name__ == "__main__":
    unittest.main()
