import 'dart:convert';

import 'package:apidash_design_system/apidash_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'agentic_mcp_app_view.dart';
import 'dashbot_action.dart';

class ChatBubble extends ConsumerWidget {
  final String message;
  final MessageRole role;
  final String? promptOverride;
  final List<ChatAction>? actions;
  final bool isLoading;

  const ChatBubble({
    super.key,
    required this.message,
    required this.role,
    this.promptOverride,
    this.actions,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = message.length > 100
        ? '${message.substring(0, 100)}...'
        : message;
    debugPrint(
      '[ChatBubble] Actions count: ${actions?.length ?? 0} | msg: $preview',
    );
    if (promptOverride != null &&
        role == MessageRole.user &&
        message == promptOverride) {
      return SizedBox.shrink();
    }
    if (message.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Column(
          children: [
            kVSpacer8,
            DashbotIcons.getDashbotIcon1(width: 42),
            kVSpacer8,
            _buildLoadingPill(context, 'DashBot is thinking...'),
          ],
        ),
      );
    }
    // Parse agent JSON when role is system and show only the "explanation" field.
    String renderedMessage = message;
    Map<String, dynamic>? mcpAppPayload;
    if (role == MessageRole.system) {
      try {
        final Map<String, dynamic> parsed = MessageJson.safeParse(message);
        if (parsed.containsKey('explanation')) {
          final exp = parsed['explanation'];
          if (exp is String && exp.isNotEmpty) {
            renderedMessage = exp;
          }
        }
        final mcpRaw = parsed['mcp_app'];
        if (mcpRaw is Map<String, dynamic>) {
          mcpAppPayload = mcpRaw;
        } else if (mcpRaw is Map) {
          mcpAppPayload = Map<String, dynamic>.from(mcpRaw);
        }
      } catch (_) {
        final extracted = _tryExtractExplanationFromJsonLike(message);
        if (extracted != null) {
          renderedMessage = extracted;
        }
      }
    }

    final effectiveActions = actions ?? const [];
    final isUser = role == MessageRole.user;
    final bubbleColor = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final bubbleTextColor = isUser
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurface;
    final roleLabel = isUser ? 'You' : 'DashBot';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            kVSpacer6,
            DashbotIcons.getDashbotIcon1(width: 42),
            kVSpacer8,
          ],
          if (isLoading) ...[
            _buildLoadingPill(context, renderedMessage),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              roleLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5.0),
            padding: const EdgeInsets.all(12.0),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: MarkdownBody(
              data: renderedMessage.isEmpty ? " " : renderedMessage,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: bubbleTextColor),
                  ),
            ),
          ),
          if (!isUser) ...[
            if (effectiveActions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in effectiveActions)
                    Builder(
                      builder: (context) {
                        final w = DashbotActionWidgetFactory.build(a);
                        if (w != null) return w;
                        return const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ],
            if (mcpAppPayload != null)
              DashbotAgenticMcpAppView(payload: mcpAppPayload!),
            const SizedBox(height: 4),
            ADIconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: renderedMessage));
              },
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              icon: Icons.copy_rounded,
              tooltip: "Copy",
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingPill(BuildContext context, String message) {
    final text = message.trim().isEmpty ? 'DashBot is thinking...' : message;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text, style: Theme.of(context).textTheme.labelMedium),
          ),
        ],
      ),
    );
  }

  String? _tryExtractExplanationFromJsonLike(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final match = RegExp(
      r'"explanation"\s*:\s*"((?:\\.|[^"\\])*)"',
    ).firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final captured = match.group(1);
    if (captured == null || captured.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode('"$captured"');
      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded.trim();
      }
    } catch (_) {}
    final bestEffort = captured
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .trim();
    return bestEffort.isEmpty ? null : bestEffort;
  }
}
