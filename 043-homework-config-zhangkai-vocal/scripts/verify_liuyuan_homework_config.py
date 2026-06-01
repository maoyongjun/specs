# -*- coding: utf-8 -*-
"""Compatibility wrapper for the liuyuan verification script."""

from pathlib import Path
import runpy


SCRIPT = Path(__file__).with_name("verify_zhangkai_homework_config.py")


if __name__ == "__main__":
    runpy.run_path(str(SCRIPT), run_name="__main__")
