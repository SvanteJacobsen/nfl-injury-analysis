from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = PROJECT_ROOT / "data" / "raw" / "nflverse"

SOURCE_GROUPS = {
    "rosters": "roster",
    "weekly_rosters": "roster_weekly",
}


def main() -> None:
    """Inspect roster structures and coverage without modifying sources."""
    summary = []

    for source_group, prefix in SOURCE_GROUPS.items():
        reference_columns = None

        print(f"\n=== COLUMN STRUCTURE: {source_group} ===")

        for season in range(2015, 2026):
            filename = f"{prefix}_{season}.csv"
            path = SOURCE_DIR / source_group / filename

            # Preserve source text, including empty strings and "NA".
            df = pd.read_csv(
                path,
                dtype=str,
                keep_default_na=False,
                skip_blank_lines=False,
            )
            columns = df.columns.tolist()

            # Compare structures separately for season and weekly rosters.
            if reference_columns is None:
                reference_columns = columns
                print(f"{filename}: reference columns:\n{columns}")
            elif columns != reference_columns:
                print(f"\n{filename}: different column structure:")
                print(columns)

            required = {"season", "team", "full_name", "position", "gsis_id"}
            if source_group == "weekly_rosters":
                required.add("week")

            missing = required - set(columns)
            if missing:
                raise ValueError(
                    f"{filename}: missing required columns: {sorted(missing)}"
                )

            # Report unexpected season values without changing source data.
            season_values = sorted(df["season"].unique().tolist())
            if season_values != [str(season)]:
                print(f"WARNING: {filename}: season values {season_values}")

            player_ids = df["gsis_id"].str.strip()
            teams = df["team"].str.strip()

            summary.append({
                "source": source_group,
                "season": season,
                "rows": len(df),
                "unique_nonblank_ids": player_ids[player_ids.ne("")].nunique(),
                "teams": teams[teams.ne("")].nunique(),
                "blank_ids": player_ids.eq("").sum(),
                "blank_names": df["full_name"].str.strip().eq("").sum(),
                "blank_positions": df["position"].str.strip().eq("").sum(),
                "exact_duplicates": df.duplicated().sum(),
            })

            if source_group == "weekly_rosters":
                # Display observed weeks separately for each competition phase.
                if "game_type" in columns:
                    groups = df.groupby("game_type", sort=True)
                else:
                    groups = [("not_available", df)]

                for game_type, group in groups:
                    weeks = pd.to_numeric(group["week"], errors="coerce")
                    observed_weeks = sorted(weeks.dropna().unique().tolist())

                    print(
                        f"{season} | {game_type} | "
                        f"weeks: {observed_weeks} | "
                        f"invalid/blank weeks: {weeks.isna().sum()}"
                    )

            # Release the current dataframe before reading the next file.
            del df

    print("\n=== ROSTER SUMMARY ===")
    print(pd.DataFrame(summary).to_string(index=False))


if __name__ == "__main__":
    main()
