from pathlib import Path

import pandas as pd


# Resolve paths relative to this script so it can run from any directory.
PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT_ROOT / "data" / "raw"

SOURCE_FILES = {
    "IR transactions": "ir_transactions.csv",
    "Concussions": "concussions.csv",
}


def inspect_source(source_name: str, filename: str) -> None:
    """Read a source CSV and print a basic profile without modifying it."""
    path = RAW_DIR / filename

    print(f"\n=== {source_name}: {filename} ===")

    # Stop with a clear error if the expected source file is missing.
    if not path.is_file():
        raise FileNotFoundError(f"Source file not found: {path}")

    # Preserve source values as text, including values such as "N/A".
    # Data types and missing-value rules will be handled during transformation.
    df = pd.read_csv(path, dtype=str, keep_default_na=False)

    print(f"Row count: {len(df):,}")
    print(f"Column count: {len(df.columns)}")
    print(f"Columns: {df.columns.tolist()}")

    # Count repeated rows beyond the first occurrence.
    # Report duplicates here; leave their removal to the transformation layer.
    print(f"Exact duplicate rows beyond the first: {df.duplicated().sum():,}")

    # Count empty and whitespace-only cells without changing their values.
    blank_counts = df.apply(
        lambda column: column.str.strip().eq("").sum()
    )
    print("\nBlank values per column:")
    print(blank_counts.to_string())

    print("\nFirst three rows:")
    print(df.head(3).to_string(index=False))


def main() -> None:
    """Inspect each configured source file."""
    for source_name, filename in SOURCE_FILES.items():
        inspect_source(source_name, filename)


# Run the inspection when this file is executed directly.
# Importing the file from another script will not trigger an inspection.
if __name__ == "__main__":
    main()
