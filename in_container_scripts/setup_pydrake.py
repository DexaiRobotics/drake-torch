"""Setup script for drake to enable import without modifying pythonpath.

Install in editable/development mode with 'pip install -e.'
"""

import setuptools

setuptools.setup(
    name="pydrake",
    version="1.12.0",
    description="pydrake",
    url="https://drake.mit.edu/",
    packages=setuptools.find_packages(),
    python_requires=">=3.8",
    # typically covers the missing packages:
    # ipython, pyzmq, u-msgpack-python, tornado
    install_requires=["meshcat >= 0.3.2"]
)
