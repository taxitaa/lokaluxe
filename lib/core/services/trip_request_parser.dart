class TripRequest {
  final String? destination;
  final DateTime? startDate;
  final int? durationDays;
  final int? travelerCount;
  final double? budget;

  const TripRequest({
    this.destination,
    this.startDate,
    this.durationDays,
    this.travelerCount,
    this.budget,
  });

  TripRequest merge(TripRequest other) => TripRequest(
    destination: other.destination ?? destination,
    startDate: other.startDate ?? startDate,
    durationDays: other.durationDays ?? durationDays,
    travelerCount: other.travelerCount ?? travelerCount,
    budget: other.budget ?? budget,
  );

  List<String> get missingFields => [
    if (destination == null) 'tujuan',
    if (startDate == null) 'tanggal mulai',
    if (durationDays == null) 'durasi perjalanan',
    if (travelerCount == null) 'jumlah orang',
    if (budget == null) 'total budget',
  ];
}

TripRequest parseTripRequest(String text) => TripRequest(
  destination: _parseDestination(text),
  startDate: _parseDate(text),
  durationDays: _parseInteger(text, r'(\d{1,2})\s*hari\b'),
  travelerCount: _parseTravelerCount(text),
  budget: _parseBudget(text),
);

int? _parseTravelerCount(String text) {
  final labeled = RegExp(
    r'(?:jumlah\s+orang|jumlah\s+peserta|peserta)\s*[:=]?\s*(\d{1,3})',
    caseSensitive: false,
  ).firstMatch(text);
  return int.tryParse(
    labeled?.group(1) ??
        _parseInteger(
          text,
          r'(\d{1,3})\s*(?:orang|org|peserta|traveler|travellers)\b',
        )?.toString() ??
        '',
  );
}

String? _parseDestination(String text) {
  final labeled = RegExp(
    r'(?:tujuan(?:nya)?|destinasi)\s*[:=]\s*([^,;|]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (labeled != null) return _cleanDestination(labeled.group(1)!);

  final phrase = RegExp(
    r"\b(?:ke|di)\s+([a-z][a-z .'-]*?)(?=\s*(?:[,;|]|\b(?:tanggal|mulai|budget|anggaran|dana|biaya|rp|selama|\d+\s*(?:hari|orang|org))\b)|$)",
    caseSensitive: false,
  ).firstMatch(text);
  if (phrase != null) return _cleanDestination(phrase.group(1)!);

  final firstPart = text.split(RegExp(r'[,;|\n]')).first.trim();
  if (RegExp(r'^(?:[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})$').hasMatch(firstPart) &&
      !const {
        'ya',
        'iya',
        'mau',
        'boleh',
        'oke',
        'ok',
        'setuju',
        'tolong',
        'buat',
        'buatkan',
        'itinerary',
        'itenerary',
        'lanjut',
      }.contains(firstPart.toLowerCase())) {
    return _cleanDestination(firstPart);
  }
  return null;
}

String? _cleanDestination(String value) {
  final cleaned = value
      .replaceAll(
        RegExp(
          r'^(?:tujuan(?:nya)?|destinasi)\s*[:=]\s*',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  return cleaned.isEmpty ? null : cleaned;
}

DateTime? _parseDate(String text) {
  final iso = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b').firstMatch(text);
  if (iso != null) {
    return _validDate(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }

  final numeric = RegExp(r'\b(\d{1,2})[/. -](\d{1,2})[/. -](\d{4})\b')
      .firstMatch(text);
  if (numeric != null) {
    return _validDate(
      int.parse(numeric.group(3)!),
      int.parse(numeric.group(2)!),
      int.parse(numeric.group(1)!),
    );
  }

  const monthNumbers = {
    'januari': 1,
    'jan': 1,
    'februari': 2,
    'feb': 2,
    'maret': 3,
    'mar': 3,
    'april': 4,
    'apr': 4,
    'mei': 5,
    'juni': 6,
    'jun': 6,
    'juli': 7,
    'jul': 7,
    'agustus': 8,
    'agu': 8,
    'agust': 8,
    'september': 9,
    'sep': 9,
    'oktober': 10,
    'okt': 10,
    'november': 11,
    'nov': 11,
    'desember': 12,
    'des': 12,
  };
  final named = RegExp(
    r'\b(\d{1,2})\s+([a-zA-Z]+)(?:\s+(\d{4}))?\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (named == null) return null;
  final month = monthNumbers[named.group(2)!.toLowerCase()];
  if (month == null) return null;
  final now = DateTime.now();
  var year = int.tryParse(named.group(3) ?? '') ?? now.year;
  var date = _validDate(year, month, int.parse(named.group(1)!));
  if (date != null &&
      named.group(3) == null &&
      date.isBefore(DateTime(now.year, now.month, now.day))) {
    year++;
    date = _validDate(year, month, int.parse(named.group(1)!));
  }
  return date;
}

DateTime? _validDate(int year, int month, int day) {
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

int? _parseInteger(String text, String pattern) {
  final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
  return match == null ? null : int.tryParse(match.group(1)!);
}

double? _parseBudget(String text) {
  final match = RegExp(
    r'(?:budget|anggaran|dana|biaya|rp\.?)\s*(?:trip|perjalanan|sekitar|adalah|:)?\s*(?:rp\.?\s*)?(\d[\d.,]*)\s*(juta|jt|miliar|ribu|rb)?\b',
    caseSensitive: false,
  ).firstMatch(text);
  final fallback =
      match ??
      RegExp(
        r'\b(\d[\d.,]*)\s*(juta|jt|miliar|ribu|rb)\b',
        caseSensitive: false,
      ).firstMatch(text);
  if (fallback == null) return null;

  final rawAmount = match == null ? fallback.group(1)! : fallback.group(1)!;
  final scale = match == null ? fallback.group(2) : fallback.group(2);
  final normalized = RegExp(r'^\d{1,3}(?:[.,]\d{3})+$').hasMatch(rawAmount)
      ? rawAmount.replaceAll(RegExp(r'[.,]'), '')
      : rawAmount.replaceAll(',', '.');
  final amount = double.tryParse(normalized);
  if (amount == null) return null;

  final multiplier = switch (scale?.toLowerCase()) {
    'juta' || 'jt' => 1000000,
    'miliar' => 1000000000,
    'ribu' || 'rb' => 1000,
    _ => 1,
  };
  final budget = amount * multiplier;
  return budget.isFinite && budget > 0 ? budget : null;
}
