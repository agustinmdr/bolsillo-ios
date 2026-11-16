"""Verificación independiente del ZIP/OOXML y del contenido generado por Swift."""
from pathlib import Path
from decimal import Decimal
from zipfile import ZipFile
import sys
import xml.etree.ElementTree as ET
from openpyxl import load_workbook

folder = Path(sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/BolsilloExcelQA')
checks = 0
def check(condition, label):
    global checks
    assert condition, label
    checks += 1

for path in folder.glob('*.xlsx'):
    with ZipFile(path) as archive:
        check(archive.testzip() is None, f'{path.name}: CRC correcto')
        for name in archive.namelist():
            ET.fromstring(archive.read(name))
        check(True, f'{path.name}: XML válido')
        names = archive.namelist()
        charts = [n for n in names if n.startswith('xl/charts/chart')]
    formulas = load_workbook(path, data_only=False)
    values = load_workbook(path, data_only=True)
    present = {r[10] for r in values['Gastos'].iter_rows(min_row=5, values_only=True) if r[10] in ['ARS', 'USD']}
    check(len(charts) == len(present), f'{path.name}: un gráfico por moneda con gastos')
    check(values.sheetnames == ['Resumen ARS', 'Resumen USD', 'Gastos', 'Ingresos'], 'Cuatro hojas sin mezclar monedas')
    for currency in ['ARS', 'USD']:
        summary = values[f'Resumen {currency}']
        rows = [r for r in values['Gastos'].iter_rows(min_row=5, values_only=True) if r[10] == currency]
        def cents(value): return int((Decimal(str(value or 0))*100).quantize(Decimal('1')))
        check(cents(summary['B5'].value) == sum(cents(r[6]) for r in rows), 'Total de gastos conciliado')
        check(cents(summary['B9'].value) == sum(cents(r[7]) for r in rows), 'Mi parte conciliada')
        check(cents(summary['B10'].value) == sum(cents(r[8]) for r in rows), 'Otra parte conciliada')
        check(cents(summary['B12'].value) == cents(summary['B11'].value)-cents(summary['B9'].value), 'Disponible conciliado')
        check(cents(summary['B5'].value) == sum(cents(summary[f'B{r}'].value) for r in range(17, summary.max_row+1)), 'Categorías suman gasto neto')
        check(formulas[f'Resumen {currency}']['B5'].data_type == 'f', 'Resumen con fórmulas reales')
        check(formulas[f'Resumen {currency}']['B12'].value == '=B11-B9', 'Disponible usa sus componentes')
    check(formulas['Gastos'].freeze_panes == 'A5', 'Encabezado inmovilizado')
    check(formulas['Gastos'].auto_filter.ref.startswith('A4:O'), 'Detalle con filtros')
    check(formulas['Gastos'].column_dimensions['M'].hidden, 'IDs técnicos ocultos')
    for row in values['Gastos'].iter_rows(min_row=5):
        if row[10].value in ['ARS', 'USD']:
            check(row[0].is_date, 'Fecha numérica con formato')
            check(isinstance(row[6].value, (int, float)), 'Importe numérico')
    if path.stem == 'mixto':
        check(cents(values['Resumen ARS']['B5'].value) == 16232, 'Cuota exacta y reintegro ARS')
        check(cents(values['Resumen ARS']['B9'].value) == 6616, 'Reparto exacto incluyendo reintegro')
        check(cents(values['Resumen ARS']['B12'].value) == 93384, 'Sueldo menos parte propia')
        check(cents(values['Resumen USD']['B5'].value) == 1250, 'USD independiente')
        titles = [r[1].value for r in formulas['Gastos'].iter_rows(min_row=5)]
        check('Mes siguiente excluido' not in titles, 'Mes siguiente excluido')
        malicious = next(r[1] for r in formulas['Gastos'].iter_rows(min_row=5) if str(r[1].value).startswith('=HYPERLINK'))
        check(malicious.data_type == 's', 'Texto con = no se convierte en fórmula')
        check('Notebook <nueva>' in titles, 'Texto XML conserva caracteres')
        ars_chart = formulas['Resumen ARS']._charts[0]
        check(len(ars_chart.ser[0].dPt) == 3, 'Color por categoría en gráfico nativo')
        check(any(r[6].value < 0 for r in values['Gastos'].iter_rows(min_row=5) if r[10].value == 'ARS'), 'Reintegro mantiene signo negativo')
    if path.stem == 'vacio':
        check(values['Resumen ARS']['B5'].value == 0 and values['Resumen USD']['B5'].value == 0, 'Mes vacío válido')
print(f'{checks} verificaciones Excel correctas.')
