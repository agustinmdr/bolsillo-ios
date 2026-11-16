import Foundation

/// Reporte mensual OOXML. Solo lee una foto del ledger; nunca escribe movimientos.
enum ExcelReport {
    private static let spreadsheet = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    private static let relationships = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    private static let package = "http://schemas.openxmlformats.org/package/2006/relationships"
    private static let declaration = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"

    static func data(ledger: Ledger, month: Month) throws -> Data {
        try ledger.validate()
        guard (2000...2200).contains(month.year), (1...12).contains(month.month) else { throw FinanceError.invalid }
        let charges = ["ARS", "USD"].flatMap { ledger.charges(in: month, currency: $0) }.sorted {
            if $0.expense.date != $1.expense.date { return $0.expense.date < $1.expense.date }
            return $0.id < $1.id
        }
        let incomes = ledger.incomes.filter { $0.month == month }.sorted { $0.id.uuidString < $1.id.uuidString }
        guard charges.count < 1_048_571, incomes.count < 1_048_571 else { throw ReportError.tooLarge }
        let end = max(5, charges.count + 4), incomeEnd = max(5, incomes.count + 4)
        var files: [(String, String)] = []
        var chartSheets: [Int] = []
        for (index, currency) in ["ARS", "USD"].enumerated() {
            let rows = charges.filter { $0.expense.currency == currency }
            let categoryTotals = Dictionary(grouping: rows, by: { $0.expense.categoryID }).mapValues { $0.reduce(Int64(0)) { $0+$1.cents } }
            let categories = ledger.categories.filter { categoryTotals[$0.id] != nil }.sorted {
                if categoryTotals[$0.id] != categoryTotals[$1.id] { return categoryTotals[$0.id]! > categoryTotals[$1.id]! }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            let chartID = index + 1
            files.append(("xl/worksheets/sheet\(chartID).xml", summary(ledger: ledger, month: month, currency: currency, charges: rows, categories: categories, end: end, incomeEnd: incomeEnd)))
            if !categories.isEmpty {
                chartSheets.append(chartID)
                files.append(("xl/worksheets/_rels/sheet\(chartID).xml.rels", rels([( "drawing", "../drawings/drawing\(chartID).xml") ])))
                files.append(("xl/drawings/drawing\(chartID).xml", drawing(rows: max(13, categories.count * 2 + 6))))
                files.append(("xl/drawings/_rels/drawing\(chartID).xml.rels", rels([("chart", "../charts/chart\(chartID).xml")])))
                files.append(("xl/charts/chart\(chartID).xml", chart(currency: currency, categories: categories, charges: rows)))
            }
        }
        var expenseRows = [row(1, [text("A1", "Bolsillo · Gastos del mes", 1)], height: 32), row(2, [text("A2", "\(month.label) · Cargo mensual de cada compra, cuota, recurrente o ajuste.", 3)], height: 28)]
        let headers = ["Fecha registrada", "Descripción", "Categoría", "Medio de pago", "Responsabilidad", "Cuota / tipo", "Cargo del mes", "Mi parte", "Otra parte", "Pagado por", "Moneda", "Notas", "ID registro", "ID categoría", "ID origen"]
        expenseRows.append(row(4, headers.enumerated().map { text("\(column($0.offset))4", $0.element, 2) }, height: 30))
        for (index, charge) in charges.enumerated() {
            let r = index + 5, e = charge.expense
            let category = ledger.categories.first { $0.id == e.categoryID }!
            let wallet = ledger.wallets.first { $0.id == e.walletID }!
            let status = charge.installmentProgress?.label ?? (e.isAdjustment ? e.tags : e.recurring ? "Recurrente" : "Un pago")
            let ownershipStyle = e.allocation == .mine ? 6 : e.allocation == .shared ? 7 : 8
            let notes = e.notes + (e.purchaseMonth.map { "\nConsumo: \($0.label). Resumen / pago: \(month.label)." } ?? "")
            expenseRows.append(row(r, [number("A\(r)", serial(e.date), 5), text("B\(r)", e.displayTitle), text("C\(r)", category.name), text("D\(r)", wallet.displayName), text("E\(r)", e.allocation.title, ownershipStyle), text("F\(r)", status), amount("G\(r)", charge.cents), amount("H\(r)", charge.agusShare), amount("I\(r)", charge.maiShare), text("J\(r)", e.paidBy.title), text("K\(r)", e.currency), text("L\(r)", notes), text("M\(r)", charge.id), text("N\(r)", category.id.uuidString), text("O\(r)", e.sourceKey ?? "")], height: 44))
        }
        if charges.isEmpty { expenseRows.append(row(5, [text("B5", "Sin gastos en este mes.", 3)])) }
        files.append(("xl/worksheets/sheet3.xml", sheet(rows: expenseRows, widths: [18, 42, 26, 30, 26, 24, 22, 22, 22, 22, 12, 65, 28, 28, 28], last: "O\(end)", filter: "A4:O\(end)", merges: ["A1:L1", "A2:L2"], frozen: true, hiddenFrom: 13)))
        var incomeRows = [row(1, [text("A1", "Bolsillo · Ingresos del mes", 1)], height: 32), row(2, [text("A2", "\(month.label) · Ingresos personales registrados; separados de gastos y devoluciones.", 3)], height: 28), row(4, [text("A4", "Mes", 2), text("B4", "Descripción", 2), text("C4", "Importe", 2), text("D4", "Moneda", 2), text("E4", "ID origen", 2)], height: 30)]
        for (i, income) in incomes.enumerated() {
            let r = i + 5
            incomeRows.append(row(r, [number("A\(r)", serial(income.month.date), 5), text("B\(r)", income.title), amount("C\(r)", income.cents), text("D\(r)", income.currency), text("E\(r)", income.sourceKey ?? income.id.uuidString)], height: 30))
        }
        if incomes.isEmpty { incomeRows.append(row(5, [text("B5", "Sin ingresos registrados.", 3)])) }
        files.append(("xl/worksheets/sheet4.xml", sheet(rows: incomeRows, widths: [18, 45, 24, 16, 50], last: "E\(incomeEnd)", filter: "A4:E\(incomeEnd)", merges: ["A1:E1", "A2:E2"], frozen: true)))
        let names = ["Resumen ARS", "Resumen USD", "Gastos", "Ingresos"]
        files.append(("xl/workbook.xml", declaration + "<workbook xmlns=\"\(spreadsheet)\" xmlns:r=\"\(relationships)\"><bookViews><workbookView/></bookViews><sheets>" + names.enumerated().map { "<sheet name=\"\($0.element)\" sheetId=\"\($0.offset+1)\" r:id=\"rId\($0.offset+1)\"/>" }.joined() + "</sheets><calcPr calcId=\"191029\" fullCalcOnLoad=\"1\"/></workbook>"))
        files.append(("xl/_rels/workbook.xml.rels", rels((1...4).map { ("worksheet", "worksheets/sheet\($0).xml") } + [("styles", "styles.xml")])))
        files.append(("_rels/.rels", rels([("officeDocument", "xl/workbook.xml")])))
        files.append(("xl/styles.xml", styles))
        let overrides = [("/xl/workbook.xml", "sheet.main+xml"), ("/xl/styles.xml", "styles+xml")] + (1...4).map { ("/xl/worksheets/sheet\($0).xml", "worksheet+xml") }
        let content = overrides.map { "<Override PartName=\"\($0.0)\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.\($0.1)\"/>" }.joined() + chartSheets.map { "<Override PartName=\"/xl/charts/chart\($0).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawingml.chart+xml\"/><Override PartName=\"/xl/drawings/drawing\($0).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawing+xml\"/>" }.joined()
        files.append(("[Content_Types].xml", declaration + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/>\(content)</Types>"))
        return try ReportZIP.archive(files.map { ($0.0, Data($0.1.utf8)) })
    }

    private static func summary(ledger: Ledger, month: Month, currency: String, charges: [Charge], categories: [Category], end: Int, incomeEnd: Int) -> String {
        let c = "\"\(currency)\""
        func sum(_ column: String) -> String { "SUMIFS('Gastos'!$\(column)$5:$\(column)$\(end),'Gastos'!$K$5:$K$\(end),\(c))" }
        func allocationSum(_ allocation: Allocation) -> String { "SUMIFS('Gastos'!$G$5:$G$\(end),'Gastos'!$K$5:$K$\(end),\(c),'Gastos'!$E$5:$E$\(end),\"\(allocation.title)\")" }
        let total = charges.reduce(Int64(0)) { $0 + $1.cents }, own = charges.reduce(Int64(0)) { $0 + $1.agusShare }
        let income = ledger.incomes.filter { $0.month == month && $0.currency == currency }.reduce(Int64(0)) { $0 + $1.cents }
        var rows = [row(1, [text("A1", "Bolsillo · Resumen \(currency)", 1)], height: 34), row(2, [text("A2", month.label, 3)], height: 28), row(4, [text("A4", "Concepto", 2), text("B4", "Importe \(currency)", 2)], height: 28)]
        let metrics: [(String, String, Int64)] = [
            ("Gastos netos del mes", sum("G"), total),
            ("Mío", allocationSum(.mine), charges.filter { $0.expense.allocation == .mine }.reduce(0) { $0+$1.cents }),
            ("Compartido (total)", allocationSum(.shared), charges.filter { $0.expense.allocation == .shared }.reduce(0) { $0+$1.cents }),
            ("De otra persona", allocationSum(.mai), charges.filter { $0.expense.allocation == .mai }.reduce(0) { $0+$1.cents }),
            ("Mi parte de los gastos", sum("H"), own),
            ("Parte de otra persona", sum("I"), total-own),
            ("Ingresos personales", "SUMIFS('Ingresos'!$C$5:$C$\(incomeEnd),'Ingresos'!$D$5:$D$\(incomeEnd),\(c))", income),
            ("Disponible personal", "B11-B9", income-own)
        ]
        for (i, metric) in metrics.enumerated() { let r = i+5; rows.append(row(r, [text("A\(r)", metric.0), formula("B\(r)", metric.1, metric.2)], height: 27)) }
        rows.append(row(14, [text("A14", "Los reintegros restan del gasto. Las cuotas incluyen solo el cargo de este mes. Disponible = ingresos menos mi parte; no es saldo bancario.", 3)], height: 54))
        rows.append(row(16, [text("A16", "Categoría", 2), text("B16", "Gasto neto \(currency)", 2)], height: 28))
        for (i, category) in categories.enumerated() {
            let r = i+17, cents = charges.filter { $0.expense.categoryID == category.id }.reduce(Int64(0)) { $0+$1.cents }
            let f = "SUMIFS('Gastos'!$G$5:$G$\(end),'Gastos'!$K$5:$K$\(end),\(c),'Gastos'!$N$5:$N$\(end),$C\(r))"
            rows.append(row(r, [text("A\(r)", category.name), formula("B\(r)", f, cents), text("C\(r)", category.id.uuidString)], height: 28))
        }
        if categories.isEmpty { rows.append(row(17, [text("A17", "Sin gastos en esta moneda.", 3)], height: 30)) }
        return sheet(rows: rows, widths: [36, 24, 3] + Array(repeating: 12, count: 9), last: "L\(max(18, categories.count+16))", merges: ["A1:L1", "A2:L2", "A14:B15"], drawing: !categories.isEmpty, hiddenFrom: 3, hiddenThrough: 3)
    }

    private static func chart(currency: String, categories: [Category], charges: [Charge]) -> String {
        let c = "http://schemas.openxmlformats.org/drawingml/2006/chart", a = "http://schemas.openxmlformats.org/drawingml/2006/main"
        let last = categories.count+16, name = "Resumen \(currency)"
        let points = categories.enumerated().map { "<c:pt idx=\"\($0.offset)\"><c:v>\(xml($0.element.name))</c:v></c:pt>" }.joined()
        let values = categories.enumerated().map { i, category in "<c:pt idx=\"\(i)\"><c:v>\(decimal(charges.filter { $0.expense.categoryID == category.id }.reduce(0) { $0+$1.cents }))</c:v></c:pt>" }.joined()
        let colors = categories.enumerated().map { "<c:dPt><c:idx val=\"\($0.offset)\"/><c:spPr><a:solidFill><a:srgbClr val=\"\($0.element.reportColorHex)\"/></a:solidFill><a:ln><a:noFill/></a:ln></c:spPr></c:dPt>" }.joined()
        return declaration + """
        <c:chartSpace xmlns:c="\(c)" xmlns:a="\(a)"><c:lang val="es-AR"/><c:chart><c:title><c:tx><c:rich><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="es-AR" sz="1200"/><a:t>Gasto neto por categoría (\(currency))</a:t></a:r></a:p></c:rich></c:tx><c:overlay val="0"/></c:title><c:plotArea><c:layout/><c:barChart><c:barDir val="bar"/><c:grouping val="clustered"/><c:varyColors val="1"/><c:ser><c:idx val="0"/><c:order val="0"/><c:tx><c:v>Gasto neto</c:v></c:tx>\(colors)<c:cat><c:strRef><c:f>'\(name)'!$A$17:$A$\(last)</c:f><c:strCache><c:ptCount val="\(categories.count)"/>\(points)</c:strCache></c:strRef></c:cat><c:val><c:numRef><c:f>'\(name)'!$B$17:$B$\(last)</c:f><c:numCache><c:formatCode>#,##0.00</c:formatCode><c:ptCount val="\(categories.count)"/>\(values)</c:numCache></c:numRef></c:val></c:ser><c:gapWidth val="70"/><c:axId val="100"/><c:axId val="200"/></c:barChart><c:catAx><c:axId val="100"/><c:scaling><c:orientation val="maxMin"/></c:scaling><c:delete val="0"/><c:axPos val="l"/><c:tickLblPos val="low"/><c:crossAx val="200"/><c:crosses val="autoZero"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/></c:catAx><c:valAx><c:axId val="200"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="b"/><c:majorGridlines/><c:numFmt formatCode="#,##0.00" sourceLinked="0"/><c:tickLblPos val="nextTo"/><c:crossAx val="100"/><c:crosses val="autoZero"/><c:crossBetween val="between"/></c:valAx></c:plotArea><c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/></c:chart><c:spPr><a:solidFill><a:srgbClr val="FAF8F1"/></a:solidFill><a:ln><a:noFill/></a:ln></c:spPr><c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1100"><a:latin typeface="Arial"/></a:defRPr></a:pPr><a:endParaRPr lang="es-AR"/></a:p></c:txPr></c:chartSpace>
        """
    }
    private static func drawing(rows: Int) -> String {
        declaration + """
        <xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><xdr:twoCellAnchor><xdr:from><xdr:col>3</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>3</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:to><xdr:col>12</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>\(rows)</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to><xdr:graphicFrame macro=""><xdr:nvGraphicFramePr><xdr:cNvPr id="2" name="Gastos por categoría"/><xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr><xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"><c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:r="\(relationships)" r:id="rId1"/></a:graphicData></a:graphic></xdr:graphicFrame><xdr:clientData/></xdr:twoCellAnchor></xdr:wsDr>
        """
    }
    private static func sheet(rows: [String], widths: [Int], last: String, filter: String? = nil, merges: [String] = [], frozen: Bool = false, drawing: Bool = false, hiddenFrom: Int? = nil, hiddenThrough: Int = 100) -> String {
        let cols = widths.enumerated().map { i, width in "<col min=\"\(i+1)\" max=\"\(i+1)\" width=\"\(width)\" customWidth=\"1\"\(hiddenFrom.map { (i+1 >= $0 && i+1 <= hiddenThrough) ? " hidden=\"1\"" : "" } ?? "")/>" }.joined()
        let pane = frozen ? "<pane ySplit=\"4\" topLeftCell=\"A5\" activePane=\"bottomLeft\" state=\"frozen\"/>" : ""
        return declaration + "<worksheet xmlns=\"\(spreadsheet)\" xmlns:r=\"\(relationships)\"><dimension ref=\"A1:\(last)\"/><sheetViews><sheetView showGridLines=\"0\" workbookViewId=\"0\">\(pane)</sheetView></sheetViews><sheetFormatPr defaultRowHeight=\"22\"/><cols>\(cols)</cols><sheetData>\(rows.joined())</sheetData>" + (filter.map { "<autoFilter ref=\"\($0)\"/>" } ?? "") + (merges.isEmpty ? "" : "<mergeCells count=\"\(merges.count)\">" + merges.map { "<mergeCell ref=\"\($0)\"/>" }.joined() + "</mergeCells>") + "<pageMargins left=\"0.3\" right=\"0.3\" top=\"0.4\" bottom=\"0.4\" header=\"0.2\" footer=\"0.2\"/>" + (drawing ? "<drawing r:id=\"rId1\"/>" : "") + "</worksheet>"
    }
    private static func rels(_ targets: [(String, String)]) -> String {
        declaration + "<Relationships xmlns=\"\(package)\">" + targets.enumerated().map { "<Relationship Id=\"rId\($0.offset+1)\" Type=\"\(relationships)/\($0.element.0)\" Target=\"\($0.element.1)\"/>" }.joined() + "</Relationships>"
    }
    private static func row(_ r: Int, _ cells: [String], height: Int = 24) -> String { "<row r=\"\(r)\" ht=\"\(height)\" customHeight=\"1\">\(cells.joined())</row>" }
    private static func text(_ ref: String, _ value: String, _ style: Int = 0) -> String { "<c r=\"\(ref)\" s=\"\(style)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xml(String(value.prefix(32_767))))</t></is></c>" }
    private static func number(_ ref: String, _ value: String, _ style: Int) -> String { "<c r=\"\(ref)\" s=\"\(style)\"><v>\(value)</v></c>" }
    private static func amount(_ ref: String, _ cents: Int64) -> String { number(ref, decimal(cents), 4) }
    private static func formula(_ ref: String, _ value: String, _ cents: Int64) -> String { "<c r=\"\(ref)\" s=\"4\"><f>\(xml(value))</f><v>\(decimal(cents))</v></c>" }
    private static func decimal(_ cents: Int64) -> String { let n = abs(cents); return "\(cents < 0 ? "-" : "")\(n/100).\(String(format: "%02lld", n%100))" }
    private static func serial(_ date: Date) -> String {
        let calendar = Calendar.current, parts = calendar.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = utc.date(from: parts)!, base = utc.date(from: DateComponents(year: 1899, month: 12, day: 30))!
        return String(Int(day.timeIntervalSince(base)/86400))
    }
    private static func column(_ index: Int) -> String { String(UnicodeScalar(65+index)!) }
    private static func xml(_ value: String) -> String {
        String(value.unicodeScalars.filter { $0.value == 9 || $0.value == 10 || $0.value == 13 || (0x20...0xD7FF).contains($0.value) || (0xE000...0xFFFD).contains($0.value) || (0x10000...0x10FFFF).contains($0.value) }).replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;")
    }
    private static var styles: String {
        let fonts = "<fonts count=\"4\"><font><sz val=\"11\"/><color rgb=\"FF263D32\"/><name val=\"Arial\"/></font><font><b/><sz val=\"16\"/><color rgb=\"FF17664F\"/><name val=\"Arial\"/></font><font><b/><sz val=\"11\"/><color rgb=\"FFFAF8F1\"/><name val=\"Arial\"/></font><font><i/><sz val=\"11\"/><color rgb=\"FF657064\"/><name val=\"Arial\"/></font></fonts>"
        let fills = "<fills count=\"7\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill>" + ["17664F", "FAF8F1", "E2EBDC", "F3E6C9", "E5EAF7"].map { "<fill><patternFill patternType=\"solid\"><fgColor rgb=\"FF\($0)\"/><bgColor indexed=\"64\"/></patternFill></fill>" }.joined() + "</fills>"
        let definitions = [(0,3,0),(1,3,0),(2,2,0),(3,3,0),(0,3,164),(0,3,165),(0,4,0),(0,5,0),(0,6,0)]
        let xfs = definitions.map { font, fill, format in "<xf numFmtId=\"\(format)\" fontId=\"\(font)\" fillId=\"\(fill)\" borderId=\"0\" xfId=\"0\" applyNumberFormat=\"1\" applyFill=\"1\" applyFont=\"1\" applyAlignment=\"1\"><alignment vertical=\"center\" wrapText=\"1\" indent=\"1\"/></xf>" }.joined()
        return declaration + "<styleSheet xmlns=\"\(spreadsheet)\"><numFmts count=\"2\"><numFmt numFmtId=\"164\" formatCode=\"#,##0.00;[Red]-#,##0.00\"/><numFmt numFmtId=\"165\" formatCode=\"dd/mm/yyyy\"/></numFmts>\(fonts)\(fills)<borders count=\"1\"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs><cellXfs count=\"9\">\(xfs)</cellXfs><cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles></styleSheet>"
    }
    enum ReportError: LocalizedError {
        case tooLarge
        var errorDescription: String? { "El reporte supera el tamaño permitido por Excel. Exportá un período más pequeño." }
    }
}

/// ZIP con entradas sin compresión: compatible con OOXML, sin librerías externas.
private enum ReportZIP {
    static func archive(_ entries: [(String, Data)]) throws -> Data {
        var result = Data(), directory = Data()
        func word(_ value: UInt16) -> Data { var n = value.littleEndian; return withUnsafeBytes(of: &n) { Data($0) } }
        func dword(_ value: UInt32) -> Data { var n = value.littleEndian; return withUnsafeBytes(of: &n) { Data($0) } }
        for (name, data) in entries {
            let path = Data(name.utf8)
            guard data.count < Int(UInt32.max), result.count < Int(UInt32.max), path.count <= Int(UInt16.max) else { throw ExcelReport.ReportError.tooLarge }
            let size = UInt32(data.count), offset = UInt32(result.count), crc = crc32(data)
            result.append(dword(0x04034B50)); result.append(word(20)); result.append(word(0x0800)); result.append(word(0)); result.append(word(0)); result.append(word(0x0021)); result.append(dword(crc)); result.append(dword(size)); result.append(dword(size)); result.append(word(UInt16(path.count))); result.append(word(0)); result.append(path); result.append(data)
            directory.append(dword(0x02014B50)); directory.append(word(20)); directory.append(word(20)); directory.append(word(0x0800)); directory.append(word(0)); directory.append(word(0)); directory.append(word(0x0021)); directory.append(dword(crc)); directory.append(dword(size)); directory.append(dword(size)); directory.append(word(UInt16(path.count))); directory.append(word(0)); directory.append(word(0)); directory.append(word(0)); directory.append(word(0)); directory.append(dword(0)); directory.append(dword(offset)); directory.append(path)
        }
        guard result.count < Int(UInt32.max), directory.count < Int(UInt32.max), entries.count <= Int(UInt16.max) else { throw ExcelReport.ReportError.tooLarge }
        let offset = UInt32(result.count); result.append(directory)
        result.append(dword(0x06054B50)); result.append(word(0)); result.append(word(0)); result.append(word(UInt16(entries.count))); result.append(word(UInt16(entries.count))); result.append(dword(UInt32(directory.count))); result.append(dword(offset)); result.append(word(0))
        return result
    }
    private static let table: [UInt32] = (0..<256).map { n in
        var crc = UInt32(n)
        for _ in 0..<8 { crc = crc & 1 == 0 ? crc >> 1 : (crc >> 1) ^ 0xEDB88320 }
        return crc
    }
    private static func crc32(_ data: Data) -> UInt32 { data.reduce(UInt32.max) { table[Int(($0 ^ UInt32($1)) & 0xFF)] ^ ($0 >> 8) } ^ UInt32.max }
}
