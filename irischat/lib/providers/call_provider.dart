import 'package:flutter/material.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';

class CallProvider extends ChangeNotifier {
  final CallService _service = CallService();

  bool _isCalling = false;
  bool get isCalling => _isCalling;

  CallModel? _currentCall;
  CallModel? get currentCall => _currentCall;

  CallService getService() => _service;

  // Stream gọt giũa dữ liệu đẩy về cho HomeScreen nhận diện cuộc gọi đến
  Stream<CallModel> incomingCallStream(String uid) {
    return _service.listenIncomingCalls(uid).expand((event) {
      if (!event.snapshot.exists) return [];

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as dynamic);
      List<CallModel> calls = [];

      data.forEach((key, value) {
        final callMap = Map<String, dynamic>.from(value);
        final call = CallModel.fromMap(callMap);

        if (call.status == 'ringing') {
          _currentCall = call;
          _isCalling = true;
        } else if (call.status == 'accepted') {
          _currentCall = call;
          _isCalling = true;
        } else if (call.status == 'ended' || call.status == 'rejected') {
          _isCalling = false;
          _currentCall = null;
        }

        calls.add(call);
      });

      notifyListeners();
      return calls;
    });
  }

  // Người gọi bắt đầu ấn nút gọi
  Future<void> startCall({
    required String callerId,
    required String receiverId,
  }) async {
    _isCalling = true;
    notifyListeners();

    // Tạo node cuộc gọi mới trên Firebase và kích hoạt bắt tay ngầm WebRTC
    String callId = await _service.createCall(
      callerId: callerId,
      receiverId: receiverId,
    );

    // Tạo một model giả lập trạng thái ban đầu của người gọi để quản lý
    _currentCall = CallModel(
      callId: callId,
      callerId: callerId,
      receiverId: receiverId,
      status: 'ringing',
    );
    notifyListeners();
  }

  // Người nhận bấm nút Accept từ Dialog/Notification
  Future<void> acceptCall(String callId) async {
    await _service.answerCall(callId: callId);
    if (_currentCall != null) {
      _currentCall = CallModel(
        callId: _currentCall!.callId,
        callerId: _currentCall!.callerId,
        receiverId: _currentCall!.receiverId,
        status: 'accepted',
      );
    }
    notifyListeners();
  }

  // Dọn dẹp bộ nhớ khi cuộc gọi kết thúc
  Future<void> endCall() async {
    if (_currentCall != null) {
      await _service.cleanUpCall(_currentCall!.callId);
    }
    _currentCall = null;
    _isCalling = false;
    notifyListeners();
  }
}
