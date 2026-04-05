import '../error/chat_failure.dart';
import 'chat_message.dart';
import 'agent_loop_session.dart';

class ChatState {
  final Map<String, List<ChatMessage>> chatSessions; // requestId -> messages
  final Map<String, AgentLoopSession> loopSessions; // requestId -> agent loop
  final bool isGenerating;
  final String currentStreamingResponse;
  final String? currentRequestId;
  final ChatFailure? lastError;

  const ChatState({
    this.chatSessions = const {},
    this.loopSessions = const {},
    this.isGenerating = false,
    this.currentStreamingResponse = '',
    this.currentRequestId,
    this.lastError,
  });

  ChatState copyWith({
    Map<String, List<ChatMessage>>? chatSessions,
    Map<String, AgentLoopSession>? loopSessions,
    bool? isGenerating,
    String? currentStreamingResponse,
    String? currentRequestId,
    ChatFailure? lastError,
  }) {
    return ChatState(
      chatSessions: chatSessions ?? this.chatSessions,
      loopSessions: loopSessions ?? this.loopSessions,
      isGenerating: isGenerating ?? this.isGenerating,
      currentStreamingResponse:
          currentStreamingResponse ?? this.currentStreamingResponse,
      currentRequestId: currentRequestId ?? this.currentRequestId,
      lastError: lastError ?? this.lastError,
    );
  }
}
