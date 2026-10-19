class TripModel {
  final int? id;
  final String destination;
  final String destinationTitle;
  final String dates;
  final String duration;
  final String currency;
  final double targetBudget;
  final double transportAllocation;
  final double hotelAllocation;
  final double culinaryAllocation;
  final double activityAllocation;
  final String status;

  TripModel({
    this.id,
    required this.destination,
    required this.destinationTitle,
    required this.dates,
    required this.duration,
    this.currency = 'IDR',
    required this.targetBudget,
    required this.transportAllocation,
    required this.hotelAllocation,
    required this.culinaryAllocation,
    required this.activityAllocation,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'destination': destination,
      'destinationTitle': destinationTitle,
      'dates': dates,
      'duration': duration,
      'currency': currency,
      'targetBudget': targetBudget,
      'transportAllocation': transportAllocation,
      'hotelAllocation': hotelAllocation,
      'culinaryAllocation': culinaryAllocation,
      'activityAllocation': activityAllocation,
      'status': status,
    };
  }

  factory TripModel.fromMap(Map<String, dynamic> map) {
    return TripModel(
      id: map['id'] as int?,
      destination: map['destination'] ?? '',
      destinationTitle: map['destinationTitle'] ?? '',
      dates: map['dates'] ?? '',
      duration: map['duration'] ?? '',
      currency: map['currency'] ?? 'IDR',
      targetBudget: (map['targetBudget'] as num?)?.toDouble() ?? 0.0,
      transportAllocation: (map['transportAllocation'] as num?)?.toDouble() ?? 0.0,
      hotelAllocation: (map['hotelAllocation'] as num?)?.toDouble() ?? 0.0,
      culinaryAllocation: (map['culinaryAllocation'] as num?)?.toDouble() ?? 0.0,
      activityAllocation: (map['activityAllocation'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'active',
    );
  }
}
