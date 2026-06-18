#!/usr/bin/env python
# -*- coding: utf-8 -*-
import setuptools
import os

ver_file = os.path.join('hw2vec', '_version.py')
with open(ver_file) as f:
    exec(f.read())

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

INSTALL_REQUIRES = [line.strip() for line in open("requirements.txt").readlines()
                    if line.strip() and not line.startswith('#')]

setuptools.setup(
    name='VeriWalk',
    version=__version__,
    author="VeriWalk Authors",
    description="VeriWalk: RTL Hardware Trojan Detection via Data Flow Graph Walk and Subgraph Similarity",
    long_description=long_description,
    long_description_content_type="text/markdown",
    packages=setuptools.find_packages(exclude=[
        'assets', 'assets.*', 'outputs', 'outputs.*',
        'examples.result*', 'JPlag', 'JPlag.*',
        'venv', 'venv.*',
    ]),
    package_data={
        'hw2vec': ['configs/*.yaml'],
        'pyverilog': ['ast_code_generator/template/*.txt'],
    },
    install_requires=INSTALL_REQUIRES,
    python_requires='>=3.8',
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Topic :: Scientific/Engineering :: Electronic Design Automation (EDA)",
    ],
)
