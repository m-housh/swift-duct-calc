#!/usr/bin/env python3
"""Regenerate every fitting, preserve exact-revision approvals, and build Group 1 review."""
import importlib.util
from pathlib import Path


def run_module(filename):
    path=Path(__file__).with_name(filename)
    spec=importlib.util.spec_from_file_location(path.stem,path)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.main()


if __name__=='__main__':
    run_module('generate-fitting-complex-pilot.py')
    run_module('generate-fitting-review.py')
    print('Generated all fittings and the complete Group 1 review batch.')
