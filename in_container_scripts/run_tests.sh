#!/bin/bash

set -eufo pipefail

# test pydrake install
if pip list 2>/dev/null | grep -q pydrake &>/dev/null; then
    echo "pydrake not found in pip list" >&2
    exit 1
elif python3 -c "import pydrake"; then
    echo "pydrake import test passed"
else
    echo "pydrake import failure" >&2
    exit 1
fi

# test ROS vision_opencv install
if ! python3 -c "import cv_bridge"; then
    echo "cv_bridge import failure" >&2
    exit 1
elif python3 -c "import cv_bridge" 2>&1 > /dev/null | grep endian; then
    echo "CV bridge endianness problem found." >&2
    exit 1
elif ! python3 -c "from cv_bridge.boost.cv_bridge_boost import getCvType"; then
    echo "dynamic module does not define module export function (PyInit_cv_bridge_boost)" >&2
    exit 1
else
    echo "cv_bridge import tests passed"
fi

/root/scripts/test.py
