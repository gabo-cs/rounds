import 'package:intl/intl.dart';

import 'app_localizations.dart';

class AppLocalizationsEs extends AppLocalizations {
  @override
  String get localeName => 'es';

  // ── Navigation ───────────────────────────────────────────────────────────────

  @override
  String get navRound => 'RONDA';
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
  @override
  String get genericErrorMessage => 'Algo salió mal. Inténtalo de nuevo.';

  // ── Due-date helpers ─────────────────────────────────────────────────────────

  @override
  String dueThe(int day) => 'Vence el $day';

  @override
  String overdueSince(int day) => 'Venció el $day';

  @override
  String overdueSinceDate(DateTime date) =>
      'Venció el ${DateFormat.MMMd('es').format(date)}';

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
  String get noRoundRecordedTitle => 'Sin ronda registrada';
  @override
  String get noRoundRecordedSubtitle =>
      'Rounds solo guarda los meses en los que estuvo abierta. Puedes armar '
      'esta con tus facturas tal como están hoy y luego marcar lo que pagaste.';
  @override
  String get buildRoundButton => 'Armar esta ronda';
  @override
  String get roundMenuTooltip => 'Opciones de la ronda';
  @override
  String get markAllPaidAction => 'Marcar todas como pagadas';
  @override
  String get markAllPaidDialogTitle => '¿Marcar la ronda como pagada?';
  @override
  String markAllPaidCurrentMessage(int count) => count == 1
      ? 'La factura que sigue abierta en esta ronda quedará registrada como '
            'pagada hoy. Después puedes abrirla para agregar el monto o el '
            'método.'
      : 'Las $count facturas que siguen abiertas en esta ronda quedarán '
            'registradas como pagadas hoy. Después puedes abrir cualquiera '
            'para agregar el monto o el método.';
  @override
  String markAllPaidPastMessage(int count) => count == 1
      ? 'La factura que sigue abierta quedará registrada como pagada en su '
            'propia fecha de vencimiento, porque la ronda ya pasó. Después '
            'puedes abrirla para ajustar los detalles.'
      : 'Las $count facturas que siguen abiertas quedarán registradas como '
            'pagadas en sus propias fechas de vencimiento, porque la ronda ya '
            'pasó. Después puedes abrir cualquiera para ajustar los detalles.';
  @override
  String get markAllPaidConfirm => 'Marcar todas';
  @override
  String markAllPaidDone(int count) => count == 1
      ? '1 factura marcada como pagada'
      : '$count facturas marcadas como pagadas';
  @override
  String get todayButton => 'Hoy';
  @override
  String get previousMonthTooltip => 'Mes anterior';
  @override
  String get nextMonthTooltip => 'Mes siguiente';
  @override
  String roundNumber(int month) => 'ronda $month';
  @override
  String paidOfTotal(int paid, int total) => '$paid de $total pagadas';
  @override
  String overdueCount(int count) =>
      count == 1 ? '1 vencida' : '$count vencidas';

  // ── Bills screen ─────────────────────────────────────────────────────────────

  @override
  String get billsTitle => 'Facturas';
  @override
  String get billsScreenHint =>
      'Tus facturas recurrentes y su configuración: nombre, monto y día de '
      'vencimiento. El estado de cada mes (pagada, pendiente, vencida) está '
      'en la pestaña Ronda.';
  @override
  String get archivedLabel => 'Archivadas';
  @override
  String billsCount(int count) => count == 1 ? '1 factura' : '$count facturas';
  @override
  String get addFirstBillBillsSubtitle =>
      'Agrega tus facturas recurrentes para comenzar.';
  @override
  String get deleteBillDialogTitle => '¿Eliminar factura?';
  @override
  String get archiveInsteadHint =>
      '¿Quieres conservar el historial? Archivar oculta esta factura de los '
      'próximos meses pero mantiene todo lo ya registrado — y puedes '
      'desarchivarla cuando quieras.';
  @override
  String get archiveInsteadButton => 'Mejor archivar';
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
      'Recibe notificaciones antes del vencimiento, el día del vencimiento y mientras esté vencida';
  @override
  String get notificationDenied =>
      'Permiso de notificaciones denegado. Actívalo en la configuración del sistema.';
  @override
  String get dataSection => 'Datos';
  @override
  String get exportDataTitle => 'Exportar datos';
  @override
  String get exportDataSubtitle =>
      'Guarda una copia de seguridad JSON o compártela';
  @override
  String get importDataTitle => 'Importar datos';
  @override
  String get importDataSubtitle =>
      'Restaurar desde una copia de seguridad JSON';
  @override
  String get backupInfoTooltip => 'Sobre las copias';
  @override
  String get backupInfoTitle => 'Sobre las copias';
  @override
  String get backupInfoIntro =>
      'Exportar escribe todo lo que Rounds sabe en un solo archivo que tú '
      'guardas. Importar lo vuelve a leer.';
  @override
  String get backupInfoWhatTitle => 'Es un archivo JSON';
  @override
  String get backupInfoWhatBody =>
      'JSON es un formato de texto plano para intercambiar datos: abierto, '
      'muy usado y que no pertenece a ninguna empresa. Puedes abrir el '
      'archivo con cualquier editor de texto. Son simplemente tus datos '
      'escritos ahí, así que nada queda encerrado dentro de Rounds.';
  @override
  String get backupInfoContentsTitle => 'Qué contiene';
  @override
  String get backupInfoContentsBody =>
      'Cada factura, cada mes de tus rondas y cada pago que registraste, con '
      'montos, fechas, métodos y notas. Rounds escribe el archivo y lo '
      'vuelve a leer, así que una exportación siempre se importa sin '
      'problemas en otra instalación.';
  @override
  String get backupInfoImportTitle => 'Importar reemplaza todo';
  @override
  String get backupInfoImportBody =>
      'Una copia se restaura tal cual encima de tus datos actuales: nunca se '
      'combinan. Después se reconstruyen los recordatorios, así que un '
      'teléfono restaurado vuelve a avisarte a tiempo.';
  @override
  String get backupInfoTip =>
      'Rounds funciona sin conexión, así que ese archivo es tu única copia. '
      'Expórtalo cada pocos meses y guárdalo donde no lo pierdas.';
  @override
  String get currencyInfoTooltip => 'Sobre la moneda';
  @override
  String get currencyInfoTitle => 'Sobre la moneda';
  @override
  String get currencyInfoIntro =>
      'Define cómo se escriben los montos: el símbolo y los separadores. '
      'Eso es todo lo que hace.';
  @override
  String get currencyInfoDisplayTitle => 'Solo apariencia';
  @override
  String get currencyInfoDisplayBody =>
      'Los montos se guardan como números simples. Cambiar de moneda cambia '
      'cómo se leen — 1,500 o 1.500 — nunca los números en sí, así que nada '
      'de tu historial se reescribe.';
  @override
  String get currencyInfoNoRatesTitle => 'No convierte ni usa tasas';
  @override
  String get currencyInfoNoRatesBody =>
      'Rounds funciona sin conexión y no conoce tasas de cambio: 1.500 sigue '
      'siendo 1.500 con cualquier moneda que elijas. Es una sola elección '
      'para toda la app — una factura no puede tener su propia moneda.';
  @override
  String get currencyInfoTip =>
      'La muestra junto a cada código es exactamente cómo se verán tus '
      'montos. Elige la que se parezca a como los escribes.';
  @override
  String get infoSheetDismiss => 'Entendido';
  @override
  String get aboutSection => 'Acerca de';
  @override
  String get appVersionLabel => 'Versión 1.0.0';

  // ── FAQ screen ───────────────────────────────────────────────────────────────

  @override
  String get faqTitle => 'Preguntas frecuentes';
  @override
  String get faqSettingsSubtitle =>
      'Recordatorios, privacidad, batería, respaldos';
  @override
  String get faqSectionBasics => 'Lo básico';
  @override
  String get faqSectionReminders => 'Recordatorios y batería';
  @override
  String get faqSectionData => 'Tus datos';
  @override
  String get faqSectionProject => 'El proyecto';
  @override
  String get faqQWhatIsRound => '¿Qué es una "ronda"?';
  @override
  String get faqAWhatIsRound =>
      'Cada mes es una nueva ronda de las mismas facturas. La pestaña Ronda '
      'muestra cómo va el mes actual — qué está pagado, pendiente o vencido — '
      'mientras que Facturas contiene el conjunto recurrente: nombres, montos '
      'y días de vencimiento.';
  @override
  String get faqQOffline => '¿Rounds usa internet?';
  @override
  String get faqAOffline =>
      'No. Rounds funciona completamente sin conexión: sin cuentas, sin nube '
      'y sin rastreo. Todo vive en una base de datos en este teléfono y nada '
      'sale de aquí a menos que tú mismo lo exportes.';
  @override
  String get faqQHowReminders => '¿Cómo funcionan los recordatorios?';
  @override
  String get faqAHowReminders =>
      'Los recordatorios se entregan a Android por adelantado como alarmas '
      'exactas, así que el sistema los muestra por sí solo — sin internet y '
      'sin trabajo en segundo plano. Cada factura pendiente te recuerda un '
      'día antes, el día del vencimiento y durante los tres días siguientes; '
      'una vez vencida, Rounds insiste a diario hasta que la marques como '
      'pagada. Marcarla como pagada detiene sus recordatorios de inmediato.';
  @override
  String get faqQNoReminders => 'No me llegan los recordatorios';
  @override
  String get faqANoReminders =>
      'Dos permisos del sistema importan: las notificaciones y las "Alarmas '
      'y recordatorios" (alarmas exactas). El botón de abajo revisa ambos. '
      'Algunos teléfonos además cierran apps agresivamente para ahorrar '
      'batería — si aun así se pierden recordatorios, permite que Rounds '
      'funcione sin restricciones en los ajustes de batería.';
  @override
  String get faqCheckNotifButton => 'Revisar ajustes de notificaciones';
  @override
  String get faqNotifOk => 'Las notificaciones están listas.';
  @override
  String get faqNotifIssue =>
      'Revisa las notificaciones y las "Alarmas y recordatorios" de Rounds '
      'en los ajustes del sistema.';
  @override
  String get faqQBattery => '¿Rounds gasta batería?';
  @override
  String get faqABattery =>
      'No. Rounds no ejecuta servicios en segundo plano ni trabajo '
      'periódico — el sistema dispara los recordatorios por su cuenta y la '
      'app actualiza su programación en el momento en que la dejas. Si tu '
      'teléfono llega a forzar el cierre de la app, basta con abrirla de '
      'nuevo para reparar todo.';
  @override
  String get faqQBackup => '¿Y si pierdo o cambio de teléfono?';
  @override
  String get faqABackup =>
      'Como Rounds es offline, no hay copia en la nube — tus datos existen '
      'solo en este dispositivo. Exporta un respaldo desde Ajustes cada '
      'pocos meses (es un archivo pequeño que puedes guardar donde quieras) '
      'e impórtalo en un teléfono nuevo para continuar justo donde ibas, '
      'recordatorios incluidos.';
  @override
  String get faqQJsonFile => '¿Qué es exactamente el archivo de copia?';
  @override
  String get faqAJsonFile =>
      'Un archivo JSON: texto plano en un formato de intercambio abierto y '
      'muy usado, que cualquier editor de texto puede abrir y que no '
      'pertenece a ninguna empresa. Contiene tus facturas, tus rondas y tus '
      'pagos, y es Rounds quien lo escribe y lo vuelve a leer — así que un '
      'archivo exportado aquí siempre se importa sin problemas en otro '
      'lado. Guárdalo donde quieras; es tuyo.';
  @override
  String get faqQHistory => '¿El historial se acumula para siempre?';
  @override
  String get faqAHistory =>
      'Sí, a propósito — las rondas pasadas son tu registro de pagos, y la '
      'pestaña Historial se construye con ellas. En almacenamiento es '
      'insignificante: un año completo de facturas pesa unos pocos '
      'kilobytes, así que incluso una década de historial sigue siendo '
      'ligerísima. Eliminar una factura es lo único que borra su historial; '
      'por eso archivar suele ser la mejor opción.';
  @override
  String get faqQOpenSource => '¿Puedo pedir funciones o ver el código?';
  @override
  String get faqAOpenSource =>
      'Rounds es de código abierto. Ideas, reportes de errores y forks son '
      'bienvenidos — el proyecto vive en GitHub.';
  @override
  String get faqOpenRepoButton => 'Abrir en GitHub';

  // ── Onboarding ───────────────────────────────────────────────────────────────

  @override
  String get onboardTitle1 => 'Cada mes es una ronda';
  @override
  String get onboardBody1 =>
      'Tus facturas se repiten: arriendo, internet, streaming. Rounds sigue '
      'cada mes como una ronda: ve de un vistazo qué está pagado, pendiente '
      'o vencido, y toca una factura para marcarla pagada.';
  @override
  String get onboardTitle2 => 'Configura tus facturas una vez';
  @override
  String get onboardBody2 =>
      'Agrega cada factura recurrente con su día de vencimiento — el monto '
      'es opcional. La pestaña Facturas guarda el conjunto; cada mes nuevo '
      'arma su ronda a partir de él. Archiva en lugar de eliminar para '
      'conservar tu historial.';
  @override
  String get onboardTitle3 => 'Recordatorios que simplemente funcionan';
  @override
  String get onboardBody3 =>
      'Totalmente offline y a cargo del propio teléfono: un aviso el día '
      'anterior, el día del vencimiento y a diario una vez vencida — hasta '
      'que la marques pagada. Permite las notificaciones para que puedan '
      'llegarte.';
  @override
  String get onboardNext => 'Siguiente';
  @override
  String get onboardEnableReminders => 'Activar recordatorios';
  @override
  String get onboardSkip => 'Quizás luego';
  @override
  String get onboardSampleRent => 'Arriendo';
  @override
  String get onboardSampleSchool => 'Colegio';
  @override
  String get onboardSampleSchoolCategory => 'Educación';
  @override
  String get onboardSampleCreditCard => 'Tarjeta de crédito';
  @override
  String get importDataDialogTitle => '¿Importar datos?';
  @override
  String get importDataDialogContent =>
      'Esto reemplazará TODOS los datos actuales con el contenido del '
      'archivo de respaldo. No se puede deshacer.';
  @override
  String get importAndReplaceButton => 'Importar y reemplazar';
  @override
  String importSuccessSummary(int bills, int records) {
    final verb = bills == 1 && records == 1 ? 'Se importó' : 'Se importaron';
    final recordsLabel = records == 1
        ? '1 registro de pago'
        : '$records registros de pago';
    return '$verb ${billsCount(bills)} y $recordsLabel.';
  }

  @override
  String get importErrorInvalidFile =>
      'El archivo no es una copia de seguridad válida de Rounds.';
  @override
  String get importErrorUnsupportedVersion =>
      'Esta copia de seguridad fue creada por una versión más reciente de Rounds.';
  @override
  String get importErrorReadFailed => 'No se pudo leer el archivo.';
  @override
  String get importErrorGeneric => 'Error al importar.';
  @override
  String get languageSection => 'Idioma';
  @override
  String get englishLanguage => 'Inglés';
  @override
  String get spanishLanguage => 'Español';

  @override
  String get currencySection => 'Moneda';

  @override
  String get testNotificationTitle => 'Enviar notificación de prueba';
  @override
  String get testNotificationSubtitle =>
      'Usa la última factura — se envía en 10 segundos';
  @override
  String get noBillsThisMonth => 'No hay facturas para este mes';
  @override
  String testNotificationScheduled(String name) =>
      'La notificación de prueba para "$name" se envía en 10 segundos';
  @override
  String testNotificationFailed(String e) => 'Error: $e';

  // ── Notifications ──────────────────────────────────────────────────────────────

  @override
  String get notificationDueToday => 'vence hoy';
  @override
  String get notificationTomorrow => 'vence mañana';
  @override
  String get notificationBillLabel => 'Factura';
  @override
  String get monthlyReminderTitle => 'Una nueva ronda de facturas';
  @override
  String get monthlyReminderBody =>
      'Comienza un nuevo mes — prepárate para otra ronda de facturas.';
  @override
  String get snooze30Min => '30 min';
  @override
  String get snooze1Hour => '1 hora';
  @override
  String get snooze3Hours => '3 horas';
  @override
  String reminderRescheduledFor(String time) =>
      'Recordatorio reprogramado para $time';

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
