/// Сервис для работы с WebSocket соединением системы сообщений
///
/// Управляет WebSocket соединением для сообщений.
/// Поддерживает аутентификацию, переподключение и отправку сообщений.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:uuid/uuid.dart';
import 'package:kconnect_mobile/core/constants.dart';
import 'api_client/dio_client.dart';

/// Состояния WebSocket соединения
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Сообщение WebSocket
class WebSocketMessage {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  WebSocketMessage({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String,
      data: json,
      timestamp: DateTime.now(),
    );
  }
}

/// Сервис WebSocket для системы сообщений
class MessengerWebSocketService {
  static const String _wsUrl = 'wss://k-connect.ru/ws/messenger';

  final DioClient _dioClient;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<WebSocketMessage> _messageController = StreamController<WebSocketMessage>.broadcast();
  final StreamController<WebSocketConnectionState> _connectionController = StreamController<WebSocketConnectionState>.broadcast();

  WebSocketConnectionState _connectionState = WebSocketConnectionState.disconnected;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  String? _deviceId;
  String? _sessionKey;
  bool _isAuthenticated = false;
  final List<Map<String, dynamic>> _messageQueue = [];

  Stream<WebSocketMessage> get messages => _messageController.stream;
  Stream<WebSocketConnectionState> get connectionState => _connectionController.stream;
  WebSocketConnectionState get currentConnectionState => _connectionState;
  bool get isAuthenticated => _isAuthenticated;
  String? get currentDeviceId => _deviceId;

  MessengerWebSocketService(this._dioClient) {
    _generateDeviceId();
  }

  void _generateDeviceId() {
    const uuid = Uuid();
    _deviceId = uuid.v4().replaceAll('-', '').substring(0, 16);
  }

  Future<void> connect() async {
    if (_connectionState == WebSocketConnectionState.connecting ||
        _connectionState == WebSocketConnectionState.connected) {
      debugPrint('WebSocket: Already connecting/connected, skipping');
      return;
    }

    debugPrint('WebSocket: Starting connection...');
    _updateConnectionState(WebSocketConnectionState.connecting);

    try {
      debugPrint('WebSocket: Getting session key...');
      _sessionKey = await _dioClient.getSession();
      debugPrint('WebSocket: Session key: ${_sessionKey != null ? "present (${_sessionKey!.length} chars)" : "null"}');

      if (_sessionKey == null) {
        throw Exception('Session key is null');
      }

      debugPrint('WebSocket: Connecting to $_wsUrl...');
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      debugPrint('WebSocket: Waiting for connection ready...');
      await _channel!.ready;
      debugPrint('WebSocket: Connection established');

      _updateConnectionState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
      _isAuthenticated = false;
      _messageQueue.clear(); // Clear queue on new connection

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      debugPrint('WebSocket: Sending authentication message...');
      await _sendAuthMessage();

    } catch (e, stackTrace) {
      debugPrint('WebSocket: Connection failed: $e');
      debugPrint('WebSocket: Stack trace: $stackTrace');
      _updateConnectionState(WebSocketConnectionState.error);
      _scheduleReconnect();
    }
  }

  Future<void> _sendAuthMessage() async {
    if (_sessionKey == null || _deviceId == null) return;

    // Determine platform
    String platform;
    if (Platform.isIOS) {
      platform = 'iOS';
    } else if (Platform.isAndroid) {
      platform = 'Android';
    } else if (Platform.isWindows) {
      platform = 'Windows';
    } else if (Platform.isMacOS) {
      platform = 'macOS';
    } else if (Platform.isLinux) {
      platform = 'Linux';
    } else {
      platform = 'Unknown';
    }

    // Get device model (simplified)
    String device = platform;
    if (Platform.isAndroid) {
      device = 'Android Device';
    } else if (Platform.isIOS) {
      device = 'iOS Device';
    }

    final authMessage = {
      'type': 'auth',
      'token': _sessionKey, // API expects 'token', not 'session_key'
      'device_id': _deviceId,
      'client_info': {
        'platform': platform,
        'version': AppConstants.appVersion,
        'device': device,
      },
    };

    _sendMessage(authMessage);
  }

  void disconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _stopReconnectTimer();
    _subscription?.cancel();
    _channel?.sink.close(status.goingAway);
    _channel = null;
    _isAuthenticated = false;
    _messageQueue.clear(); // Clear queue on disconnect
    _updateConnectionState(WebSocketConnectionState.disconnected);
  }

  void _onMessage(dynamic message) {
    try {
      debugPrint('WebSocket: Received: $message');
      final Map<String, dynamic> jsonMessage = json.decode(message as String);
      final wsMessage = WebSocketMessage.fromJson(jsonMessage);

      if (wsMessage.type == 'connected') {
        debugPrint('WebSocket: Authentication successful');
        _isAuthenticated = true;
        // Don't start ping timer - server sends ping, we only respond with pong
        // Send queued messages after authentication
        _flushMessageQueue();
      } else if (wsMessage.type == 'ping') {
        // Respond to server ping with pong
        _sendPong(wsMessage.data);
      }

      _messageController.add(wsMessage);
    } catch (e, stackTrace) {
      debugPrint('WebSocket: Failed to parse message: $e');
      debugPrint('WebSocket: Message was: $message');
      debugPrint('WebSocket: Stack trace: $stackTrace');
    }
  }

  void _onError(Object error) {
    debugPrint('WebSocket: Connection error: $error');
    _updateConnectionState(WebSocketConnectionState.error);
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('WebSocket: Connection closed');
    _updateConnectionState(WebSocketConnectionState.disconnected);
    if (_connectionState != WebSocketConnectionState.disconnected) {
      _scheduleReconnect();
    }
  }

  void _updateConnectionState(WebSocketConnectionState state) {
    _connectionState = state;
    _connectionController.add(state);
  }

  // Ping/Pong: Server sends ping, client only responds with pong
  // No need to send ping from client

  void _sendPong(Map<String, dynamic> pingData) {
    if (_connectionState == WebSocketConnectionState.connected) {
      final pongMessage = {
        'type': 'pong',
        'timestamp': pingData['timestamp'] as num? ?? DateTime.now().millisecondsSinceEpoch,
        'ping_id': pingData['ping_id'] as String? ?? _generatePingId(),
      };
      _sendMessage(pongMessage);
    }
  }

  String _generatePingId() {
    return 'ping_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch % 1000}';
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _reconnectAttempts++;
    _stopReconnectTimer();
    _reconnectTimer = Timer(_reconnectDelay * _reconnectAttempts, () {
      connect();
    });
  }

  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_connectionState == WebSocketConnectionState.connected && _channel != null) {
      // If not authenticated and message requires auth, queue it
      if (!_isAuthenticated && _requiresAuth(message)) {
        debugPrint('WebSocket: Queueing message (not authenticated yet): ${message['type']}');
        _messageQueue.add(message);
        return;
      }

      final jsonMessage = json.encode(message);
      debugPrint('WebSocket: Sending: $jsonMessage');
      _channel!.sink.add(jsonMessage);
    } else {
      debugPrint('WebSocket: Cannot send message - not connected');
    }
  }

  bool _requiresAuth(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    // Auth and ping don't require authentication
    return type != 'auth' && type != 'ping';
  }

  void _flushMessageQueue() {
    if (_messageQueue.isEmpty) return;

    debugPrint('WebSocket: Flushing ${_messageQueue.length} queued messages');
    final messagesToSend = List<Map<String, dynamic>>.from(_messageQueue);
    _messageQueue.clear();

    for (final message in messagesToSend) {
      final jsonMessage = json.encode(message);
      debugPrint('WebSocket: Sending queued message: $jsonMessage');
      _channel?.sink.add(jsonMessage);
    }
  }

  void sendGetChatsMessage() {
    final message = {
      'type': 'get_chats',
      'device_id': _deviceId,
    };
    _sendMessage(message);
  }

  void sendMessage({
    required String content,
    required int chatId,
    required String clientMessageId,
    String? tempId,
    int? replyToId,
    int? forwardedFromId,
  }) {
    if (!_isAuthenticated) {
      debugPrint('WebSocket: Cannot send message - not authenticated');
      return;
    }

    final message = <String, dynamic>{
      'type': 'send_message',
      'chatId': chatId, // camelCase as per Swift implementation
      'text': content, // 'text' not 'content' as per Swift implementation
      'clientMessageId': clientMessageId,
    };

    if (tempId != null) {
      message['tempId'] = tempId;
    }

    if (replyToId != null) {
      message['replyToId'] = replyToId;
    }

    if (forwardedFromId != null) {
      message['forwarded_from_id'] = forwardedFromId;
    }

    _sendMessage(message);
  }

  void sendMarkChatAsRead(int chatId) {
    final message = {
      'type': 'mark_chat_read',
      'chat_id': chatId,
      'device_id': _deviceId,
    };
    _sendMessage(message);
  }

  void sendGetMessagesMessage({
    required int chatId,
    int? limit,
    int? beforeId,
    bool? forceRefresh,
  }) {
    final message = <String, dynamic>{
      'type': 'get_messages',
      'chat_id': chatId,
    };

    if (limit != null) {
      message['limit'] = limit;
    }

    if (beforeId != null) {
      message['before_id'] = beforeId;
    }

    if (forceRefresh != null) {
      message['force_refresh'] = forceRefresh;
    }

    _sendMessage(message);
  }

  void sendTypingStart(int chatId) {
    final message = {
      'type': 'typing_start',
      'chatId': chatId,
    };
    _sendMessage(message);
  }

  void sendTypingEnd(int chatId) {
    final message = {
      'type': 'typing_end',
      'chatId': chatId,
    };
    _sendMessage(message);
  }

  void sendDeliveryConfirmation({
    required String deliveryId,
    required int messageId,
    required int chatId,
  }) {
    final message = {
      'type': 'delivery_confirmation',
      'delivery_id': deliveryId,
      'messageId': messageId,
      'chatId': chatId,
    };
    _sendMessage(message);
  }

  void sendReadReceipt({
    required int messageId,
    required int chatId,
  }) {
    final message = {
      'type': 'read_receipt',
      'messageId': messageId,
      'chatId': chatId, // camelCase as per Swift implementation
    };
    _sendMessage(message);
  }

  /// Запросить статистику соединения
  ///
  /// Отправляет запрос `connection_stats` для получения статистики WebSocket соединения
  void requestConnectionStats() {
    if (_connectionState != WebSocketConnectionState.connected || !_isAuthenticated) {
      debugPrint('WebSocket: Cannot request connection stats - not connected or authenticated');
      return;
    }

    final message = {
      'type': 'connection_stats',
    };
    _sendMessage(message);
    debugPrint('WebSocket: Requested connection stats');
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
