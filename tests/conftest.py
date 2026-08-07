import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent / "function_source"))

os.environ.setdefault("RETENTION_TAG_KEY", "retention")
os.environ.setdefault("RETENTION_TAG_VALUE", "transient")
