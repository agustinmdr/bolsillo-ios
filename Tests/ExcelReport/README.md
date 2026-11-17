# Comprobar el reporte Excel

Desde la raíz del proyecto:

```sh
xcrun swiftc -module-cache-path /private/tmp/BolsilloModuleCache Core/Models/Finance.swift Core/Domain/Operations.swift Core/Planning/*.swift Core/Services/Storage/LedgerStorage.swift Core/Services/Export/ExcelReport.swift Tests/ExcelReport/main.swift -o /private/tmp/bolsillo-excel-tests
/private/tmp/bolsillo-excel-tests /private/tmp/BolsilloExcelQA
python3 Tests/ExcelReport/verify.py /private/tmp/BolsilloExcelQA
```

El verificador requiere openpyxl únicamente en el entorno de desarrollo; la app no tiene dependencias externas. El ejecutable acepta un segundo argumento opcional con una ruta de ledger.json para generar noviembre de 2026 sin modificar ese archivo. Los ejemplos incluyen ARS/USD, cuota mensual con centavos, responsabilidades, reintegro, ingresos de otro mes excluidos, categorías con caracteres especiales, texto que comienza con =, mes vacío y monto máximo. Se comprueban ZIP/CRC, XML, tipos de datos, fórmulas con valores guardados, gráficos nativos, filtros y totales independientes.

La revisión adicional con Artifact Tool importa el archivo generado, recalcula fórmulas, comprueba el cambio de un importe en una copia en memoria y renderiza las cuatro hojas. No se vuelve a exportar esa copia.
