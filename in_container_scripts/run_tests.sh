#!/bin/bash

set -eufo pipefail

# test pydrake install
if pip list 2>/dev/null | grep -q pydrake &>/dev/null; then
    echo "pydrake not found in pip list"
    exit 1
elif python3 -c "import pydrake"; then
    echo "pydrake import test passed"
else
    echo "pydrake import failure"
    exit 1
fi

# test ROS vision_opencv install
if ! python3 -c "import cv_bridge"; then
    echo "cv_bridge import failure"
    exit 1
elif python3 -c "import cv_bridge" 2>&1 > /dev/null| grep endian; then
    echo "CV bridge endianness problem found."
    exit 1
else
    echo "cv_bridge import test passed with no endianness problem"
fi

/root/scripts/test.py
