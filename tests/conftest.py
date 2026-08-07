import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent / "function_source"))

os.environ["EXPIRE_TAG_KEY"] = "expire"
os.environ["EXPIRE_TAG_VALUE"] = "true"
