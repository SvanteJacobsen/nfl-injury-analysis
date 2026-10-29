import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

import requests


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "data" / "raw" / "nflverse" / "injuries"

RELEASE_URL = (
    "https://api.github.com/repos/nflverse/"
    "nflverse-data/releases/tags/injuries"
)
SEASONS = range(2015, 2026)


def download_source(
    session: requests.Session,
    asset: dict,
    output_dir: Path = OUTPUT_DIR,
) -> None:
    """Archive one source file and its metadata in the selected directory."""
    output_dir.mkdir(parents=True, exist_ok=True)

    filename = asset["name"]
    destination = output_dir / filename
    metadata_path = output_dir / f"{filename}.metadata.json"

    # Preserve existing snapshots rather than replacing them on every run.
    if destination.exists() or metadata_path.exists():
        if not destination.exists() or not metadata_path.exists():
            raise ValueError(
                f"{filename}: incomplete local archive. "
                "Both the CSV and its metadata file must exist."
            )

        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        actual_hash = hashlib.sha256(destination.read_bytes()).hexdigest()

        if actual_hash != metadata["sha256"]:
            raise ValueError(f"{filename}: local file checksum mismatch.")

        print(f"SKIPPED: {filename} — local snapshot verified.")
        return

    source_url = asset["browser_download_url"]
    response = session.get(source_url, timeout=60)
    response.raise_for_status()
    content = response.content

    # Detect a download that differs in size from the published asset.
    if len(content) != asset["size"]:
        raise ValueError(f"{filename}: unexpected download size.")

    file_hash = hashlib.sha256(content).hexdigest()

    # Verify against GitHub's checksum when one is provided.
    published_digest = asset.get("digest")
    if published_digest and published_digest.startswith("sha256:"):
        if published_digest != f"sha256:{file_hash}":
            raise ValueError(f"{filename}: published checksum mismatch.")

    metadata = {
        "filename": filename,
        "source_url": source_url,
        "downloaded_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_asset_id": asset["id"],
        "source_updated_at": asset["updated_at"],
        "size_bytes": len(content),
        "sha256": file_hash,
    }

    # Write to temporary files before publishing the completed local files.
    temporary_csv = destination.with_suffix(".csv.tmp")
    temporary_metadata = metadata_path.with_suffix(".json.tmp")

    temporary_csv.write_bytes(content)
    temporary_metadata.write_text(
        json.dumps(metadata, indent=2) + "\n",
        encoding="utf-8",
    )

    temporary_csv.replace(destination)
    temporary_metadata.replace(metadata_path)

    print(f"DOWNLOADED: {filename} — {len(content):,} bytes.")


def main() -> None:
    """Download the configured seasons without overwriting archived files."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    with requests.Session() as session:
        response = session.get(
            RELEASE_URL,
            headers={"Accept": "application/vnd.github+json"},
            timeout=30,
        )
        response.raise_for_status()

        assets = {
            asset["name"]: asset
            for asset in response.json()["assets"]
        }

        # Check availability before starting any downloads.
        filenames = [f"injuries_{season}.csv" for season in SEASONS]
        missing = [name for name in filenames if name not in assets]

        if missing:
            raise ValueError(f"Missing source files: {', '.join(missing)}")

        for filename in filenames:
            download_source(session, assets[filename])

    print("Source download completed.")


if __name__ == "__main__":
    main()
