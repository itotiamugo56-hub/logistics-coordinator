import 'package:flutter/material.dart';

class FlareModel {
  final String id;
  String status;
  String? assignedBranchId;
  DateTime? assignedAt;  // ADD THIS FIELD
  DateTime serverReceivedTime;
  int retryQueuePosition;
  int? etaSeconds;
  
  FlareModel({
    required this.id,
    required this.status,
    this.assignedBranchId,
    this.assignedAt,  // ADD THIS PARAMETER
    required this.serverReceivedTime,
    required this.retryQueuePosition,
    this.etaSeconds,
  });
  
  factory FlareModel.fromJson(Map<String, dynamic> json) {
    return FlareModel(
      id: json['flare_id'],
      status: json['status'] ?? 'queued',
      assignedBranchId: json['assigned_branch_id'],
      assignedAt: json['assigned_at'] != null ? DateTime.tryParse(json['assigned_at']) : null,  // ADD THIS
      serverReceivedTime: DateTime.tryParse(json['server_received_time'] ?? '') ?? DateTime.now(),
      retryQueuePosition: json['retry_queue_position'] ?? 0,
      etaSeconds: json['eta_seconds'],
    );
  }
  
  void updateFromJson(Map<String, dynamic> json) {
    status = json['status'] ?? status;
    assignedBranchId = json['assigned_branch_id'] ?? assignedBranchId;
    if (json['assigned_at'] != null) {
      assignedAt = DateTime.tryParse(json['assigned_at']);
    }
    etaSeconds = json['eta_seconds'] ?? etaSeconds;
  }
  
  bool get isQueued => status == 'queued';
  bool get isDispatched => status == 'dispatched';
  bool get isEnRoute => status == 'en_route';
  bool get isCompleted => status == 'completed';
  bool get isExpired => status == 'expired';
  
  Color get statusColor {
    switch (status) {
      case 'queued': return Colors.orange;
      case 'dispatched': return Colors.blue;
      case 'en_route': return Colors.green;
      case 'completed': return Colors.grey;
      case 'expired': return Colors.red;
      default: return Colors.grey;
    }
  }
}