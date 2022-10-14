"""Setup script for drake to enable import without modifying pythonpath.

Install in editable/development mode with 'pip install -e.'
"""

import setuptools

setuptools.setup(
    name="pydrake",
    version="nightly",
    description="pydrake",
    url="https://drake.mit.edu/",
    packages=setuptools.find_packages(),
    python_requires=">=3.6",
    install_requires=["u-msgpack-python >= 2.7.1"]
)
