import 'package:intl/intl.dart';

import 'app_localizations.dart';

class AppLocalizationsEs extends AppLocalizations {
  @override
  String get localeName => 'es';

  // ── Navigation ───────────────────────────────────────────────────────────────

  @override
  String get navHome => 'INICIO';
  @override
  String get navBills => 'FACTURAS';
  @override
  String get navHistory => 'HISTORIAL';
  @override
  String get navSettings => 'AJUSTES';

  // ── Common ───────────────────────────────────────────────────────────────────

  @override
  String get cancel => 'Cancelar';
  @override
  String get delete => 'Eliminar';
  @override
  String get edit => 'Editar';
  @override
  String get undo => 'Deshacer';
  @override
  String get archive => 'Archivar';
  @override
  String get unarchive => 'Desarchivar';
  @override
  String get paid => 'Pagado';

  @override
  String itemsCount(int count) =>
      count == 1 ? '1 elemento' : '$count elementos';

  // ── Due-date helpers ─────────────────────────────────────────────────────────

  @override
  String dueThe(int day) => 'Vence el $day';

  @override
  String overdueSince(int day) => 'Venció el $day';

  @override
  String dueDayOption(int day) => 'Día $day del mes';

  // ── Home screen ──────────────────────────────────────────────────────────────

  @override
  String get pending => 'Pendiente';
  @override
  String get overdue => 'Vencida';
  @override
  String get noBillsYet => 'Sin facturas';
  @override
  String get addFirstBill => 'Agrega tu primera factura';
  @override
  String get addFirstBillHomeSubtitle =>
      'Agrega tus facturas recurrentes para comenzar a rastrear tus pagos mensuales.';
  @override
  String errorLoadingBills(String e) => 'Error al cargar facturas: $e';

  // ── Bills screen ─────────────────────────────────────────────────────────────

  @override
  String get billsTitle => 'Facturas';
  @override
  String get active => 'Activas';
  @override
  String get archivedLabel => 'Archivadas';
  @override
  String get addFirstBillBillsSubtitle =>
      'Agrega tus facturas recurrentes para comenzar.';
  @override
  String get deleteBillDialogTitle => '¿Eliminar factura?';
  @override
  String deleteBillDialogContent(String name) =>
      '¿Eliminar "$name" permanentemente?\n\n'
      'Esto también borrará todo el historial de pagos de esta factura. '
      'No se puede deshacer.';
  @override
  String get deleteBillButton => 'Eliminar';

  // ── Bill form ─────────────────────────────────────────────────────────────────

  @override
  String get editBillTitle => 'Editar Factura';
  @override
  String get newBillTitle => 'Nueva Factura';
  @override
  String get thisArchivedBanner => 'Esta factura está archivada';
  @override
  String get billNameLabel => 'Nombre de la factura';
  @override
  String get billNameHint => 'p. ej. Internet, Alquiler, Netflix';
  @override
  String get billNameRequired => 'El nombre es requerido';
  @override
  String get billNameTooLong => 'El nombre es demasiado largo';
  @override
  String get amountLabel => 'Monto (opcional)';
  @override
  String get amountHint => 'Déjalo en blanco si varía';
  @override
  String get amountInvalid => 'Ingresa un monto válido mayor que 0';
  @override
  String get dueDayLabel => 'Día de vencimiento';
  @override
  String get categoryLabel => 'Categoría (opcional)';
  @override
  String get notesLabel => 'Notas (opcional)';
  @override
  String get notesHint => 'Cualquier detalle adicional sobre esta factura';
  @override
  String get saveChangesButton => 'Guardar cambios';
  @override
  String get addBillButton => 'Agregar factura';
  @override
  String failedToSave(String e) => 'Error al guardar: $e';
  @override
  String get archiveBillDialogTitle => '¿Archivar factura?';
  @override
  String archiveBillDialogContent(String name) =>
      '"$name" no aparecerá en meses futuros. '
      'El historial de pagos se conserva.';
  @override
  String get archiveButton => 'Archivar';
  @override
  String get customCategoryChip => 'Personalizada…';
  @override
  String get customCategoryHint => 'Escribe una categoría';
  @override
  String get billNotFound => 'Factura no encontrada';
  @override
  String get editBillTooltip => 'Editar factura';
  @override
  String get paymentHistoryTitle => 'Historial de pagos';
  @override
  String get noPaymentHistoryYet => 'Sin historial de pagos aún.';
  @override
  String get archivedChipLabel => 'Archivada';
  @override
  String dueOnDayEachMonth(int day) => 'Vence el día $day de cada mes';
  @override
  String get unpaid => 'Pendiente';

  // ── Mark paid sheet ───────────────────────────────────────────────────────────

  @override
  String get updatePaymentSubtitle => 'Actualizar pago';
  @override
  String get markAsPaidSubtitle => 'Marcar como pagado';
  @override
  String get datePaidLabel => 'Fecha de pago';
  @override
  String get amountPaidLabel => 'Monto pagado (opcional)';
  @override
  String get amountPaidHint => 'Déjalo en blanco si no registras montos';
  @override
  String get paymentMethodLabel => 'Método de pago (opcional)';
  @override
  String get referenceLabel => 'Referencia / nota (opcional)';
  @override
  String get referenceHint => 'ID de transacción, # de confirmación, etc.';
  @override
  String get updatePaymentButton => 'Actualizar Pago';
  @override
  String get confirmPaymentButton => 'Confirmar Pago';
  @override
  String get undoPaymentButton => 'Deshacer Pago';
  @override
  String get undoPaymentDialogTitle => '¿Deshacer pago?';
  @override
  String get undoPaymentDialogContent =>
      'Esto marcará la factura como no pagada y eliminará los detalles del pago.';
  @override
  String paidOnDate(DateTime date) =>
      'Pagado ${DateFormat.MMMd('es').format(date)}';

  @override
  String formatShortDate(DateTime date) => DateFormat.MMMd('es').format(date);

  // ── History screen ────────────────────────────────────────────────────────────

  @override
  String get historyTitle => 'Historial';
  @override
  String get exportDataTooltip => 'Exportar datos';
  @override
  String failedToLoadHistory(String e) => 'Error al cargar historial: $e';
  @override
  String billsPaidOf(int paid, int total) => '$paid de $total facturas pagadas';
  @override
  String get allPaid => 'Todo pagado';
  @override
  String pendingCount(int count) =>
      count == 1 ? '1 pendiente' : '$count pendientes';
  @override
  String get noHistoryYet => 'Sin historial';
  @override
  String get noHistorySubtitle =>
      'Los meses anteriores aparecerán aquí cuando comiences a rastrear pagos.';
  @override
  String exportFailed(String e) => 'Error al exportar: $e';
  @override
  String monthLabel(int year, int month) =>
      DateFormat.yMMMM('es').format(DateTime(year, month));

  // ── Settings screen ───────────────────────────────────────────────────────────

  @override
  String get settingsTitle => 'Ajustes';
  @override
  String get appearanceSection => 'Apariencia';
  @override
  String get lightTheme => 'Claro';
  @override
  String get systemTheme => 'Sistema';
  @override
  String get darkTheme => 'Oscuro';
  @override
  String get notificationsSection => 'Notificaciones';
  @override
  String get billRemindersTitle => 'Recordatorios de facturas';
  @override
  String get billRemindersSubtitle =>
      'Recibe notificaciones 2 días y 1 día antes del vencimiento';
  @override
  String get notificationDenied =>
      'Permiso de notificaciones denegado. Actívalo en la configuración del sistema.';
  @override
  String get dataSection => 'Datos';
  @override
  String get exportDataTitle => 'Exportar datos';
  @override
  String get exportDataSubtitle => 'Guarda una copia de seguridad JSON o compártela';
  @override
  String get importDataTitle => 'Importar datos';
  @override
  String get importDataSubtitle => 'Restaurar desde una copia de seguridad JSON';
  @override
  String get aboutSection => 'Acerca de';
  @override
  String get appVersionLabel => 'Versión 1.0.0';
  @override
  String get importDataDialogTitle => '¿Importar datos?';
  @override
  String get importDataDialogContent =>
      'Esto reemplazará TODOS los datos actuales con el contenido del '
      'archivo de respaldo. No se puede deshacer.';
  @override
  String get importAndReplaceButton => 'Importar y reemplazar';
  @override
  String get importInstructions =>
      'Para importar, comparte tu archivo JSON de respaldo a Rounds '
      'desde tu gestor de archivos u otra app.';
  @override
  String get languageSection => 'Idioma';
  @override
  String get englishLanguage => 'Inglés';
  @override
  String get spanishLanguage => 'Español';

  // ── Payment methods ────────────────────────────────────────────────────────────

  @override
  String get paymentCash => 'Efectivo';
  @override
  String get paymentBankTransfer => 'Transferencia bancaria';
  @override
  String get paymentCard => 'Tarjeta';
  @override
  String get paymentAutoDebit => 'Débito automático';
  @override
  String get paymentOther => 'Otro';

  // ── Categories ─────────────────────────────────────────────────────────────────

  @override
  String translateCategory(String key) => switch (key) {
        'Housing' => 'Vivienda',
        'Utilities' => 'Servicios públicos',
        'Internet & Phone' => 'Internet y teléfono',
        'Insurance' => 'Seguros',
        'Subscriptions' => 'Suscripciones',
        'Credit Card' => 'Tarjeta de crédito',
        'Loan' => 'Préstamo',
        'Transportation' => 'Transporte',
        'Other' => 'Otro',
        _ => key,
      };
}
