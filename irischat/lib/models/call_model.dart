class CallModel {
  final String callId;
  final String callerId;
  final String receiverId;
  final String status;

  final dynamic offer;
  final dynamic answer;

  CallModel({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.status,
    this.offer,
    this.answer,
  });

  factory CallModel.fromMap(Map<dynamic, dynamic> map) {
    return CallModel(
      callId: map['callId'] ?? '',
      callerId: map['callerId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      status: map['status'] ?? '',
      offer: map['offer'],
      answer: map['answer'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'status': status,
      'offer': offer,
      'answer': answer,
    };
  }
}
