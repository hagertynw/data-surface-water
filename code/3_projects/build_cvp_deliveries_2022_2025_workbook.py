"""Build the CVP deliveries workbook for 2022-2025 from extracted PDF tables.

The Stata CVP cleaner expects one worksheet per delivery table, named 22-28,
with columns:
Water User, branch, category, year, Jan-Dec, Total.
"""

from __future__ import annotations

import re
from pathlib import Path

import openpyxl
import pdfplumber


ROOT = Path(__file__).resolve().parents[2]
PDF_DIR = ROOT / "raw" / "cvp" / "deliveries" / "extracted"
OUTPUT = ROOT / "raw" / "cvp" / "deliveries" / "deliveries 2022-2025.xlsx"

YEARS = range(2022, 2026)
TABLES = range(22, 29)
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
HEADERS = ["Water User", "branch", "category", "year", *MONTHS, "Total"]

TABLE_BRANCH = {
    22: "Friant-Kern Canal",
    23: "Madera Canal and Millerton Lake",
    24: "San Joaquin and Mendota Pool",
    25: "Delta-Mendota Canal",
    26: "San Luis and Cross Valley Canals",
    27: "Tehama-Colusa Canal",
    28: "Sacramento River",
}

CATEGORY_LINES = {
    "MADERA CANAL",
    "MILLERTON LAKE",
    "SAN LUIS CANAL",
    "O'NEILL FOREBAY DELIVERIES",
    "SAN FELIPE DIVISION",
    "Exchange Contractors",
    "Refuges",
}


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip())


def parse_number(text: str) -> int:
    if text == "NA":
        return 0
    return int(text.replace(",", ""))


def parse_value_row(line: str) -> tuple[str, list[int]] | tuple[None, None]:
    parts = line.split()
    numbers: list[int] = []
    split_at = len(parts)
    while split_at > 0 and re.fullmatch(r"(?:-?[\d,]+|NA)", parts[split_at - 1]):
        numbers.append(parse_number(parts[split_at - 1]))
        split_at -= 1
    if len(numbers) == 12:
        values = list(reversed(numbers))
        if sum(values[:11]) == values[11]:
            values.insert(11, 0)
            return normalize(" ".join(parts[:split_at])), values
    if len(numbers) != 13:
        return None, None
    return normalize(" ".join(parts[:split_at])), list(reversed(numbers))


def is_category_line(line: str) -> bool:
    return line in CATEGORY_LINES or line.startswith("CROSS VALLEY CANAL")


def should_skip_line(line: str, year: int, table: int) -> bool:
    if not line or line == "." or line == str(year):
        return True
    if line == TABLE_BRANCH[table]:
        return True
    if line.startswith(("Table ", "Note", "Notes:", "*")):
        return True
    skip_fragments = [
        "Department of Interior",
        "Department of the Interior",
        "Bureau of Reclamation",
        "Central Valley Operations Office",
        "Preliminary",
        "Monthly Deliveries",
        "Delivery data is based",
    ]
    if any(fragment in line for fragment in skip_fragments):
        return True
    return line.startswith("Water User")


def append_continuation(name: str, continuation: str) -> str:
    if name.endswith("-"):
        return normalize(f"{name}{continuation}")
    return normalize(f"{name} {continuation}")


def clean_user_name(name: str) -> str:
    replacements = {
        "Southern San Joaquin MUD - Ou": "Southern San Joaquin MUD - Out",
        "Tranquility Public Utilities District (TPUD) (formerly Hughes, Melvin)": (
            "Tranquility Public Utilities District\n(TPUD) (formerly Hughes, Melvin)"
        ),
    }
    return replacements.get(name, name)


def parse_pdf(table: int, year: int) -> tuple[list[dict[str, int | str]], list[dict[str, int | str]]]:
    path = PDF_DIR / f"table_{table}_{year}.pdf"
    if not path.exists():
        raise FileNotFoundError(path)

    with pdfplumber.open(path) as pdf:
        lines = []
        for page in pdf.pages:
            page_text = page.extract_text(x_tolerance=1, y_tolerance=3) or ""
            lines.extend(page_text.splitlines())

    rows: list[dict[str, int | str]] = []
    total_mismatches: list[dict[str, int | str]] = []
    category = ""
    pending_name = ""
    last_row_index: int | None = None

    for raw_line in lines:
        line = normalize(raw_line)
        if should_skip_line(line, year, table):
            continue
        if is_category_line(line):
            category = "CROSS VALLEY CANAL" if line.startswith("CROSS VALLEY CANAL") else line
            pending_name = ""
            last_row_index = None
            continue

        name, values = parse_value_row(line)
        if values is not None:
            if not name:
                name = pending_name
                pending_name = ""
            elif pending_name:
                name = normalize(f"{pending_name} {name}")
                pending_name = ""

            row = {
                "Water User": clean_user_name(name),
                "branch": TABLE_BRANCH[table],
                "category": category,
                "year": year,
            }
            row.update(dict(zip(MONTHS, values[:12])))
            row["Total"] = values[12]
            rows.append(row)

            monthly_total = sum(int(row[month]) for month in MONTHS)
            if monthly_total != row["Total"]:
                total_mismatches.append(
                    {
                        "table": table,
                        "year": year,
                        "Water User": name,
                        "monthly_total": monthly_total,
                        "printed_total": row["Total"],
                        "category": category,
                    }
                )
            last_row_index = len(rows) - 1
            continue

        if last_row_index is not None and (line.startswith("(") or str(rows[last_row_index]["Water User"]).endswith("-")):
            rows[last_row_index]["Water User"] = clean_user_name(
                append_continuation(str(rows[last_row_index]["Water User"]), line)
            )
            last_row_index = None
            continue

        pending_name = normalize(f"{pending_name} {line}")
        last_row_index = None

    return rows, total_mismatches


def write_workbook(rows_by_table: dict[int, list[dict[str, int | str]]]) -> None:
    wb = openpyxl.Workbook()
    wb.remove(wb.active)
    for table in TABLES:
        ws = wb.create_sheet(str(table))
        ws.append(HEADERS)
        for row in rows_by_table[table]:
            ws.append([row[column] for column in HEADERS])
        ws.freeze_panes = "A2"
        for column_cells in ws.columns:
            max_width = max(len(str(cell.value)) if cell.value is not None else 0 for cell in column_cells)
            ws.column_dimensions[column_cells[0].column_letter].width = min(max(max_width + 2, 10), 48)
    wb.save(OUTPUT)


def main() -> None:
    rows_by_table: dict[int, list[dict[str, int | str]]] = {table: [] for table in TABLES}
    mismatches: list[dict[str, int | str]] = []

    for year in YEARS:
        for table in TABLES:
            rows, table_mismatches = parse_pdf(table, year)
            rows_by_table[table].extend(rows)
            mismatches.extend(table_mismatches)

    for table, rows in rows_by_table.items():
        if not rows:
            raise RuntimeError(f"No rows parsed for table {table}")

    write_workbook(rows_by_table)

    print(f"Wrote {OUTPUT}")
    for table in TABLES:
        years = sorted({row["year"] for row in rows_by_table[table]})
        print(f"sheet {table}: {len(rows_by_table[table])} rows, years {years[0]}-{years[-1]}")

    if mismatches:
        print("Printed Total differs from monthly sum for these rows; Stata drops Total.")
        for mismatch in mismatches:
            print(
                f"table {mismatch['table']} year {mismatch['year']}: "
                f"{mismatch['Water User']} monthly={mismatch['monthly_total']} "
                f"printed={mismatch['printed_total']} category={mismatch['category']}"
            )


if __name__ == "__main__":
    main()
