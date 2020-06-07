"""Setup script for drake to enable import without modifying pythonpath.

Install in editable/development mode with 'pip install .'
"""

import setuptools

setuptools.setup(
    name="pydrake",
    version="nightly",
    description="pydrake",
    url="https://drake.mit.edu/i",
    packages=setuptools.find_packages(),
    python_requires=">=3.6"
)
