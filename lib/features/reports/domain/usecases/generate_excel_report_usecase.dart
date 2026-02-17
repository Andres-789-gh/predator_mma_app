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

    // renombra hoja
    Sheet sheet = excel['Sheet1'];
    excel.rename('Sheet1', 'Reporte Ventas');

    // estilos basicos
    CellStyle headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.blueGrey200,
    );

    // encabezados
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
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // llena datos y calcula totales
    double totalRevenue = 0;
    double totalProfit = 0;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    for (int i = 0; i < sales.length; i++) {
      final sale = sales[i];
      final row = i + 1;

      totalRevenue += sale.totalPrice;
      totalProfit += sale.netProfit;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(
        dateFormat.format(sale.saleDate),
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(
        sale.isService ? 'PLAN' : 'PRODUCTO',
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

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          .value = DoubleCellValue(
        sale.productUnitPrice,
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          .value = DoubleCellValue(
        sale.productUnitCost,
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
          .value = DoubleCellValue(
        sale.totalPrice,
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
          .value = DoubleCellValue(
        sale.netProfit,
      );
    }

    // fila de totales
    int totalRow = sales.length + 2;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: totalRow))
        .value = TextCellValue(
      "TOTALES:",
    );

    var revenueCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: totalRow),
    );
    revenueCell.value = DoubleCellValue(totalRevenue);
    revenueCell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.green200,
    );

    var profitCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: totalRow),
    );
    profitCell.value = DoubleCellValue(totalProfit);
    profitCell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.yellow200,
    );

    // auto ajusta columnas
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20.0);
    }

    // guarda y comparte
    final List<int>? fileBytes = excel.save();

    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String fileName =
          'Reporte_Predator_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final File file = File('${directory.path}/$fileName');

      await file.writeAsBytes(fileBytes, flush: true);

      // comparte archivo
      await Share.shareXFiles([XFile(file.path)], text: 'Reporte Predator MMA');
    }
  }
}
