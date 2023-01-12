# setup.py

from distutils.core import setup
from Cython.Build import cythonize

setup(
    ext_modules=cythonize(
        "plc_client_os.pyx", compiler_directives={"language_level": "3"}
    )
)