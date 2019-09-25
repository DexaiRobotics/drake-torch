import unittest
import pydrake
import torch

class TestPydrakeInstall(unittest.TestCase):
    def test_drake_path(self):
        """
        Test that the drake path is not empty
        """
        self.assertEqual(len(pydrake.getDrakePath()), 22)

if __name__ == '__main__':
    print("before unit test")
    unittest.main(exit=True)
    # print("result of unittest.main", result)
