#!bin/bash

# test pydrake install
if pip list 2>/dev/null | grep -q pydrake &>/dev/null; then
echo "pydrake not found in pip list"
exit 1
else
python3 -c "import pydrake" || (echo "pydrake import failure" && exit 1)
echo "pydrake import test passed"
fi

# test ROS vision_opencv install
python3 -c "import cv_bridge" || (echo "cv_bridge import failure" && exit 1)
if python3 -c "import cv_bridge" 2>&1 > /dev/null| grep endian; then
echo "CV bridge endianness problem found."
exit 1
fi
echo "cv_bridge import test passed with no endianness problem"

/root/scripts/test.py
