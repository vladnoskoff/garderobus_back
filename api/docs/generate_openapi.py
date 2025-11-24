"""Utility helpers to export the OpenAPI spec and optional SDK."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from fastapi import FastAPI

API_DIR = Path(__file__).resolve().parents[1]
if str(API_DIR) not in sys.path:
    sys.path.append(str(API_DIR))

import main


OUTPUT_DIR = Path(__file__).resolve().parent / "openapi"
OUTPUT_DIR.mkdir(exist_ok=True)


def export_openapi(app: FastAPI, output_path: Path = OUTPUT_DIR / "smart_closet.openapi.json") -> Path:
    """Generate and persist the OpenAPI document produced by FastAPI."""

    schema = app.openapi()
    output_path.write_text(json.dumps(schema, indent=2, ensure_ascii=False))
    return output_path


def generate_sdk(spec_path: Path, client_dir: Path | None = None) -> None:
    """Generate a typed Python client if openapi-python-client is available."""

    if shutil.which("openapi-python-client") is None:
        print("openapi-python-client is not installed; skipping SDK generation")
        return

    client_dir = client_dir or OUTPUT_DIR / "python-sdk"
    client_dir.mkdir(exist_ok=True)

    subprocess.run(
        [
            "openapi-python-client",
            "generate",
            f"--path={spec_path}",
            f"--output={client_dir}",
            "--overwrite",
        ],
        check=True,
    )
    print(f"SDK generated at {client_dir}")


if __name__ == "__main__":
    spec_path = export_openapi(main.app)
    print(f"OpenAPI schema written to {spec_path}")
    generate_sdk(spec_path)
