#!/usr/bin/env python3
"""
Bulk import Excel holdings data to Supabase.

Usage:
  python import_excel_to_supabase.py \
    --excel path/to/data.xlsx \
    --city "اسم الجمعية" \
    --url https://xxx.supabase.co \
    --key your-service-role-key
"""

import argparse
import sys
from pathlib import Path

try:
    import openpyxl
except ImportError:
    print("Error: openpyxl not installed. Run: pip install openpyxl supabase")
    sys.exit(1)

try:
    from supabase import create_client
except ImportError:
    print("Error: supabase not installed. Run: pip install supabase")
    sys.exit(1)


def read_excel(file_path):
    """Read holdings data from Excel file."""
    wb = openpyxl.load_workbook(file_path)
    ws = wb.active

    rows = []
    for idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
        if not any(row):  # skip empty rows
            continue
        rows.append(row)

    return rows


def parse_holdings(excel_rows):
    """
    Parse Excel rows into holdings records.
    Assumes Excel columns match the old app format:
    A: holding_id, B: holder_name, C: national_id, D: land_number, E: feddan,
    F: qirat, G: sahm, H: total_sqm, I: border_east, J: border_west,
    K: border_south, L: border_north, M: page_number, N: basin_code, O: basin_name,
    P: association_name, Q: administration, R: directorate, T: unified_number
    """
    holdings = []

    for row in excel_rows:
        if len(row) < 18:
            continue

        holding = {
            'holding_id_number': str(row[0]) if row[0] else None,  # A: رقم الحيازة
            'holder_name': str(row[1]).strip() if row[1] else None,  # B
            'national_id': str(row[2]) if row[2] else None,  # C
            'land_number': str(row[3]) if row[3] else None,  # D
            'feddan': int(row[4]) if row[4] and isinstance(row[4], (int, float)) else 0,  # E
            'qirat': int(row[5]) if row[5] and isinstance(row[5], (int, float)) else 0,  # F
            'sahm': int(row[6]) if row[6] and isinstance(row[6], (int, float)) else 0,  # G
            'total_sqm': float(row[7]) if row[7] and isinstance(row[7], (int, float)) else None,  # H
            'border_east': str(row[8]).strip() if row[8] else None,  # I
            'border_west': str(row[9]).strip() if row[9] else None,  # J
            'border_south': str(row[10]).strip() if row[10] else None,  # K
            'border_north': str(row[11]).strip() if row[11] else None,  # L
            'page_number': str(row[12]) if row[12] else None,  # M
            'basin_code': str(row[13]) if row[13] else '-1',  # N
            'basin_name': str(row[14]).strip() if row[14] else None,  # O
            'association_name': str(row[15]).strip() if row[15] else None,  # P
            'administration': str(row[16]).strip() if row[16] else None,  # Q
            'directorate': str(row[17]).strip() if row[17] else None,  # R
            'unified_number': str(row[19]).strip() if len(row) > 19 and row[19] else None,  # T
        }

        # Only add if holder_name is present (required field)
        if holding['holder_name']:
            holdings.append(holding)

    return holdings


def get_or_create_city(supabase, city_name):
    """Get existing city or create new one."""
    response = supabase.table('cities').select('id').eq('name', city_name).execute()

    if response.data:
        return response.data[0]['id']

    # Create new city
    response = supabase.table('cities').insert({
        'name': city_name,
        'status': 'active'
    }).execute()

    return response.data[0]['id']


def bulk_insert_holdings(supabase, city_id, holdings):
    """Bulk insert holdings into Supabase."""
    if not holdings:
        print("No holdings to insert.")
        return 0

    # Add city_id to each holding
    for holding in holdings:
        holding['city_id'] = city_id

    # Insert in batches of 100 (Supabase API limit)
    batch_size = 100
    inserted_count = 0

    for i in range(0, len(holdings), batch_size):
        batch = holdings[i:i + batch_size]
        try:
            response = supabase.table('holdings').insert(batch).execute()
            inserted_count += len(batch)
            print(f"✓ Inserted {len(batch)} holdings ({inserted_count}/{len(holdings)})")
        except Exception as e:
            print(f"✗ Error inserting batch {i//batch_size + 1}: {e}")
            return inserted_count

    return inserted_count


def main():
    parser = argparse.ArgumentParser(description='Bulk import Excel holdings data to Supabase')
    parser.add_argument('--excel', required=True, help='Path to Excel file')
    parser.add_argument('--city', required=True, help='City/community name')
    parser.add_argument('--url', required=True, help='Supabase project URL')
    parser.add_argument('--key', required=True, help='Supabase service role key')

    args = parser.parse_args()

    # Validate Excel file exists
    excel_path = Path(args.excel)
    if not excel_path.exists():
        print(f"Error: Excel file not found: {args.excel}")
        sys.exit(1)

    print(f"📂 Reading Excel file: {args.excel}")
    excel_rows = read_excel(excel_path)
    print(f"   Found {len(excel_rows)} rows")

    print(f"\n📝 Parsing holdings...")
    holdings = parse_holdings(excel_rows)
    print(f"   Parsed {len(holdings)} holdings")

    if not holdings:
        print("Error: No valid holdings found in Excel file.")
        sys.exit(1)

    print(f"\n🔗 Connecting to Supabase...")
    supabase = create_client(args.url, args.key)

    print(f"\n🏙️ Getting/creating city: {args.city}")
    city_id = get_or_create_city(supabase, args.city)
    print(f"   City ID: {city_id}")

    print(f"\n📤 Uploading {len(holdings)} holdings to Supabase...")
    inserted = bulk_insert_holdings(supabase, city_id, holdings)

    print(f"\n✅ Successfully imported {inserted}/{len(holdings)} holdings!")
    print(f"   City: {args.city}")
    print(f"   Ready to download in the app!")


if __name__ == '__main__':
    main()
