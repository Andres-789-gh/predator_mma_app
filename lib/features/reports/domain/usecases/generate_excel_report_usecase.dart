import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/repositories/reports_repository.dart';

class GenerateExcelReportUseCase {
  final ReportsRepository _repository;

  GenerateExcelReportUseCase(this._repository);

  Future<void> execute({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // obtiene datos
    final sales = await _repository.getSalesByDateRange(startDate, endDate);

    if (sales.isEmpty) {
      throw Exception('No hay ventas en el rango seleccionado');
    }

    // crea excel en memoria
    var excel = Excel.createExcel();

    // captura hoja por defecto creada por el sistema
    String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

    // renombra hoja
    excel.rename(defaultSheet, 'Reporte Ventas');

    // abrir hoja al iniciar
    excel.setDefaultSheet('Reporte Ventas');

    Sheet sheet = excel['Reporte Ventas'];

    CellStyle headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.blueGrey200,
    );

    CellStyle titleStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      fontSize: 14,
    );

    CellStyle currencyStyle = CellStyle(
      numberFormat: NumFormat.custom(formatCode: r'$#,##0.00'),
    );

    // formateo fechas
    final dateStrFormat = DateFormat('dd/MM/yyyy');
    final startStr = dateStrFormat.format(startDate);
    final endStr = dateStrFormat.format(endDate);

    // titulo
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0),
      customValue: TextCellValue('Reporte Financiero del $startStr al $endStr'),
    );
    var titleCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    titleCell.cellStyle = titleStyle;

    // nombres columnas
    List<String> headers = [
      'Fecha',
      'Tipo',
      'Item',
      'Cliente',
      'Método Pago',
      'Cant.',
      'Precio Unit.',
      'Costo Unit.',
      'Total Venta',
      'Ganancia Neta',
    ];

    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    double totalRevenue = 0;
    double totalProfit = 0;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // llena filas con los datos de ventas
    for (int i = 0; i < sales.length; i++) {
      final sale = sales[i];
      final row = i + 2;

      totalRevenue += sale.totalPrice;
      double currentNetProfit =
          sale.totalPrice - (sale.productUnitCost * sale.quantity);
      totalProfit += currentNetProfit;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(
        dateFormat.format(sale.saleDate),
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(
        sale.isService ? 'PLAN/SERVICIO' : 'PRODUCTO',
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(
        sale.productName,
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(
        sale.buyerName ?? 'Anónimo',
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = TextCellValue(
        sale.paymentMethod,
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = IntCellValue(
        sale.quantity,
      );

      // formato moneda
      var priceCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
      );
      priceCell.value = DoubleCellValue(sale.productUnitPrice);
      priceCell.cellStyle = currencyStyle;

      var costCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row),
      );
      costCell.value = DoubleCellValue(sale.productUnitCost);
      costCell.cellStyle = currencyStyle;

      var totalCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row),
      );
      totalCell.value = DoubleCellValue(sale.totalPrice);
      totalCell.cellStyle = currencyStyle;

      var profitCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row),
      );
      profitCell.value = DoubleCellValue(currentNetProfit);
      profitCell.cellStyle = currencyStyle;
    }

    // totales
    int totalRow = sales.length + 3;

    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: totalRow))
        .value = TextCellValue(
      "TOTALES:",
    );

    // ganancia bruta
    var revenueCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: totalRow),
    );
    revenueCell.value = DoubleCellValue(totalRevenue);
    revenueCell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.green200,
      numberFormat: NumFormat.custom(formatCode: r'$#,##0.00'),
    );

    // ganancia neta
    var finalProfitCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: totalRow),
    );
    finalProfitCell.value = DoubleCellValue(totalProfit);
    finalProfitCell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.yellow200,
      numberFormat: NumFormat.custom(formatCode: r'$#,##0.00'),
    );

    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20.0);
    }

    // convierte a bytes
    final List<int>? fileBytes = excel.save();

    if (fileBytes != null) {
      // ubica directorio temporal
      final directory = await getApplicationDocumentsDirectory();

      // nombre archivo con fechas
      final safeStart = DateFormat('dd-MM-yyyy').format(startDate);
      final safeEnd = DateFormat('dd-MM-yyyy').format(endDate);
      final String fileName = 'Reporte_Predator_${safeStart}_al_$safeEnd.xlsx';
      final File file = File('${directory.path}/$fileName');

      // guarda archivo fisico
      await file.writeAsBytes(fileBytes, flush: true);

      // opciones de compartir
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Reporte Financiero ($safeStart al $safeEnd)');
    }
  }
}
