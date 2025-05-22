class IncomingShareRequest {
  final String requestingUserId;
  final String requestingUserDisplayName;
  final String requestingUserEmail;
  final String status; // "pending", "accepted", "rejected"
  final int timestamp;

  IncomingShareRequest({
    required this.requestingUserId,
    required this.requestingUserDisplayName,
    required this.requestingUserEmail,
    required this.status,
    required this.timestamp,
  });

  factory IncomingShareRequest.fromMap(String id, Map<String, dynamic> map) {
    return IncomingShareRequest(
      requestingUserId: id, // The key of the request is the requestingUserId
      requestingUserDisplayName: map['requestingUserDisplayName'] ?? 'Unknown User',
      requestingUserEmail: map['requestingUserEmail'] ?? 'no-email',
      status: map['status'] ?? 'unknown',
      timestamp: map['timestamp'] is int ? map['timestamp'] : 0, // Handle potential non-int from Firebase
    );
  }
}