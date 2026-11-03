/// الخطوط المتاحة للتطبيق. [family] = اسم العائلة في pubspec (null = خط النظام).
class AppFont {
  final String id, label;
  final String? family;
  /// معامل تكبير للخطوط الصغيرة بصرياً (الخطوط الخطية).
  final double adjust;
  /// خط عرض ثقيل: يناسب العناوين أكثر من النص الطويل.
  final bool display;
  const AppFont(this.id, this.label, this.family,
      {this.adjust = 1, this.display = false});
}

const appFonts = <AppFont>[
  AppFont('system', 'خط النظام (افتراضي)', null),
  AppFont('cairo', 'Cairo', 'Cairo'),
  AppFont('mbold', 'Mohammad Bold Normal', 'MohammadBold', display: true),
  AppFont('mhead', 'Mohammad Head', 'MohammadHead', display: true),
  AppFont('mlaha', 'Mohammad Laha', 'MohammadLaha', display: true),
  AppFont('aldhabi', 'Aldhabi (الذهبي)', 'Aldhabi', adjust: 1.25),
  AppFont('arabtype', 'Arabic Typesetting', 'ArabicTypesetting', adjust: 1.25),
];

AppFont fontById(String id) =>
    appFonts.firstWhere((f) => f.id == id, orElse: () => appFonts.first);
