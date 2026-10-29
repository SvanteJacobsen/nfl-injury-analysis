from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = PROJECT_ROOT / "data" / "raw" / "nflverse" / "injuries"


def main() -> None:
    """Profile the archived injury files without changing their contents."""
    reference_columns = None
    coverage = []

    for season in range(2015, 2026):
        path = SOURCE_DIR / f"injuries_{season}.csv"

        # Preserve text values, including empty strings and "NA".
        df = pd.read_csv(
            path,
            dtype=str,
            keep_default_na=False,
            skip_blank_lines=False,
        )
        columns = df.columns.tolist()

        print(f"\n=== {path.name} ===")
        print(f"Rows: {len(df):,}")
        print(f"Exact duplicate rows: {df.duplicated().sum():,}")

        # Compare each file's structure with the first season.
        if reference_columns is None:
            reference_columns = columns
            print(f"Reference columns: {columns}")
        elif columns == reference_columns:
            print("Column structure: matches reference.")
        else:
            print(f"Different column structure: {columns}")

        required = {"season", "game_type", "week", "team", "gsis_id"}
        missing = required - set(columns)

        if missing:
            print(f"Cannot profile coverage; missing columns: {sorted(missing)}")
            continue

        print(f"Season values: {sorted(df['season'].unique().tolist())}")
        print(f"Blank player IDs: {df['gsis_id'].str.strip().eq('').sum():,}")

        # Summarize observed coverage separately for each competition phase.
        for game_type, group in df.groupby("game_type", sort=True):
            weeks = pd.to_numeric(group["week"], errors="coerce")
            teams = group["team"].str.strip()

            coverage.append({
                "file_season": season,
                "game_type": game_type,
                "rows": len(group),
                "teams": teams[teams.ne("")].nunique(),
                "distinct_weeks": weeks.nunique(),
                "first_week": weeks.min(),
                "last_week": weeks.max(),
                "invalid_or_blank_weeks": weeks.isna().sum(),
            })

    print("\n=== Observed coverage by season and competition phase ===")
    if coverage:
        print(pd.DataFrame(coverage).to_string(index=False))


if __name__ == "__main__":
    main()
