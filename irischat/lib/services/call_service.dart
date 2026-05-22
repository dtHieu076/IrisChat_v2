import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  RTCPeerConnection? peerConnection;
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  MediaStream? localStream;

  // Quản lý các Stream để có thể hủy khi cúp máy (Tránh rò rỉ bộ nhớ)
  List<dynamic> _databaseSubscriptions = [];
  final Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': 'stun:stun.l.google.com:19302',
      }, // STUN server miễn phí của Google
    ],
  };

  // Khởi tạo renderers (Phải gọi hàm này trước khi vào màn hình Call)
  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  // Khởi tạo Peer Connection và cấu hình ICE Candidate
  Future<void> initPeer(String callId, String role) async {
    peerConnection = await createPeerConnection(configuration);

    //🔴 BƯỚC 3: Mở Camera/Micro và add vào kết nối
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true, // Đổi thành false nếu chỉ muốn gọi thoại
    });
    localRenderer.srcObject = localStream; // Hiển thị camera mình lên màn hình

    // Truyền các track (luồng) media này sang cho đối phương
    localStream!.getTracks().forEach((track) {
      peerConnection!.addTrack(track, localStream!);
    });

    //🔴 BƯỚC 3: Lắng nghe khi nhận được luồng Video/Audio từ đối phương
    peerConnection!.onAddStream = (stream) {
      remoteRenderer.srcObject = stream;
    };

    // 🔴 BƯỚC 2: Khi thiết bị tìm thấy đường mạng (Candidate) của mình, đẩy lên Firebase
    peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _db.child('calls/$callId/${role}Candidates').push().set({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
  }

  // ==========================================
  // LOGIC PHÍA NGƯỜI GỌI (CALLER)
  // ==========================================
  Future<String> createCall({
    required String callerId,
    required String receiverId,
  }) async {
    final ref = _db.child('calls').push();
    final callId = ref.key!;

    await initPeer(callId, 'caller');

    // Tạo Offer cứu vãn cấu hình Media
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    await ref.set({
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'status': 'ringing',
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });

    // 🔴 BƯỚC 1: Người gọi lắng nghe xem Người nhận có "Chấp nhận" (Answer) không
    final answerSub = _db.child('calls/$callId/answer').onValue.listen((
      event,
    ) async {
      if (!event.snapshot.exists) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      // Nạp mã Answer của đối phương vào máy mình để thông luồng Handshake
      await peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );
    });
    _databaseSubscriptions.add(answerSub);

    // Lắng nghe mạng (Candidates) từ phía Người nhận gửi lên
    _listenRemoteCandidates(callId, 'receiver');

    return callId;
  }

  // ==========================================
  // LOGIC PHÍA NGƯỜI NHẬN (RECEIVER)
  // ==========================================
  Future<void> answerCall({required String callId}) async {
    await initPeer(callId, 'receiver');

    final snapshot = await _db.child('calls/$callId').get();
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final offer = data['offer'];

    // Thiết lập mã nhận diện của đối phương
    await peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    // Tạo mã phản hồi (Answer)
    RTCSessionDescription answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    // Cập nhật trạng thái cuộc gọi lên Firebase
    await _db.child('calls/$callId').update({
      'status': 'accepted',
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });

    // Lắng nghe mạng (Candidates) từ phía Người gọi gửi lên
    _listenRemoteCandidates(callId, 'caller');
  }

  // Hàm dùng chung để lắng nghe danh sách mạng của đối phương
  void _listenRemoteCandidates(String callId, String remoteRole) {
    final candidateSub = _db
        .child('calls/$callId/${remoteRole}Candidates')
        .onChildAdded
        .listen((event) {
          if (!event.snapshot.exists) return;
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);

          // Thêm thông tin mạng của đối phương vào thực thể kết nối WebRTC hiện tại
          peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        });
    _databaseSubscriptions.add(candidateSub);
  }

  // Hàm lắng nghe các cuộc gọi đến thô từ Firebase
  Stream<DatabaseEvent> listenIncomingCalls(String currentUid) {
    return _db
        .child('calls')
        .orderByChild('receiverId')
        .equalTo(currentUid)
        .onValue;
  }

  // Trong lib/services/call_service.dart
  Future<void> cleanUpCall(String callId) async {
    try {
      // 🔥 ĐÚNG QUY TẮC: Mọi tác vụ với FirebaseDatabase nằm ở tầng Service
      await _db.child('calls/$callId').update({'status': 'ended'});
    } catch (e) {
      print("[CallService] Không thể cập nhật status ended: $e");
    }

    // Sau đó tiến hành dọn dẹp cục bộ như code cũ của bạn:
    for (var sub in _databaseSubscriptions) {
      sub.cancel();
    }
    _databaseSubscriptions.clear();

    // Tắt camera và mic
    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();

    // Giải phóng bộ render
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    await peerConnection?.close();
    peerConnection = null;
  }
}
