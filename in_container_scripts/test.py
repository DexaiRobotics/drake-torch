#!/usr/bin/env python

import unittest
import pydrake
import torch


class TestImage(unittest.TestCase):

    def test_drake_path(self):
        """
        Test that the drake path is not empty
        """
        self.assertEqual(len(pydrake.getDrakePath()), 22)

    def test_torch_(self):
        x = torch.rand(5, 3)
        self.assertEqual(tuple(x.shape), (5, 3))


if __name__ == '__main__':
    unittest.main(exit=True)
