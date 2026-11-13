# =====================================================================
# export_to_csv.py — превращает DOE_heights.xlsx в один "плоский" CSV
# Запуск:  python export_to_csv.py
# Нужно:   pip install openpyxl
# Результат: heights_clean.csv (160 строк, по одной на линзу в измерении)
# =====================================================================
import csv
from datetime import datetime
from openpyxl import load_workbook

XLSX = "DOE_heights.xlsx"
OUT = "heights_clean.csv"

# Открываем Excel. data_only=True — брать значения ячеек, а не формулы.
wb = load_workbook(XLSX, data_only=True)

rows = []

# Перебираем листы по очереди; каждый лист = одно измерение.
for ws in wb.worksheets:
    title = ws.title

    # --- Разбираем название листа обычными операциями со строками ---
    date_text, rest = title.split(" (")
    rest = rest.rstrip(")")
    parts = rest.split(" ", 1)
    sample_code = parts[0]
    label = parts[1] if len(parts) > 1 else ""

    # Дату '03.02.26' превращаем в формат ГГГГ-ММ-ДД ('2026-02-03'),
    # который PostgreSQL понимает сразу.
    measured_on = datetime.strptime(date_text, "%d.%m.%y").date().isoformat()

    # --- Читаем высоты с листа ---
    all_rows = list(ws.iter_rows(values_only=True))
    header = all_rows[0]
    h_col = header.index("h, мкм")

    lens_no = 0
    for r in all_rows[1:]:
        height = r[h_col]
        if height is None:
            continue
        lens_no += 1                                  
        rows.append([title, sample_code, measured_on, label, lens_no, float(height)])

    # Проверка: на каждом листе должно быть ровно 16 линз.
    assert lens_no == 16, f"На листе {title!r} {lens_no} значений вместо 16"

# --- Записываем CSV ---
with open(OUT, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["source_sheet", "sample_code", "measured_on", "label", "lens_no", "height_um"])
    writer.writerows(rows)

print(f"Готово: {len(rows)} строк записано в {OUT}")
