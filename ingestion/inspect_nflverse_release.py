import requests


RELEASE_URL = (
    "https://api.github.com/repos/nflverse/"
    "nflverse-data/releases/tags/injuries"
)
SEASONS = range(2015, 2026)


def main() -> None:
    """Check which seasonal injury CSV files are published by nflverse."""
    response = requests.get(
        RELEASE_URL,
        headers={"Accept": "application/vnd.github+json"},
        timeout=30,
    )

    # Stop if GitHub returns an HTTP error instead of release metadata.
    response.raise_for_status()
    release = response.json()

    # Index the published files by filename.
    assets = {
        asset["name"]: asset
        for asset in release["assets"]
    }

    print("NFLverse injury report availability\n")

    for season in SEASONS:
        filename = f"injuries_{season}.csv"
        asset = assets.get(filename)

        if asset is None:
            print(f"{season}: MISSING — {filename}")
            continue

        size_kb = asset["size"] / 1024
        updated_at = asset["updated_at"]

        print(
            f"{season}: AVAILABLE — {filename} "
            f"({size_kb:,.0f} KB; updated {updated_at})"
        )


if __name__ == "__main__":
    main()
