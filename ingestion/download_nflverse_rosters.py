import requests

from download_nflverse_injuries import PROJECT_ROOT, download_source


BASE_DIR = PROJECT_ROOT / "data" / "raw" / "nflverse"
SEASONS = range(2015, 2026)

# Map each GitHub release to its seasonal CSV filename prefix.
SOURCE_GROUPS = {
    "rosters": "roster",
    "weekly_rosters": "roster_weekly",
}


def main() -> None:
    """Archive season and weekly rosters using the shared downloader."""
    planned_downloads = []

    with requests.Session() as session:
        # Check both releases before starting any downloads.
        for release_tag, prefix in SOURCE_GROUPS.items():
            release_url = (
                "https://api.github.com/repos/nflverse/"
                f"nflverse-data/releases/tags/{release_tag}"
            )

            response = session.get(
                release_url,
                headers={"Accept": "application/vnd.github+json"},
                timeout=30,
            )
            response.raise_for_status()

            assets = {
                asset["name"]: asset
                for asset in response.json()["assets"]
            }

            for season in SEASONS:
                filename = f"{prefix}_{season}.csv"

                if filename not in assets:
                    raise ValueError(
                        f"Missing source file in {release_tag}: {filename}"
                    )

                planned_downloads.append(
                    (assets[filename], BASE_DIR / release_tag)
                )

        # Reuse checksum checks, metadata recording, and snapshot preservation.
        for asset, output_dir in planned_downloads:
            download_source(session, asset, output_dir=output_dir)

    print("Roster source download completed.")


if __name__ == "__main__":
    main()
