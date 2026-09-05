import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/app_stats.dart';

/// API Key 环境变量名（.env 与 --dart-define 均使用此名称）
const String kApiKeyEnvName = 'MODELSCOPE_API_KEY';

/// 编译期通过 --dart-define 注入的 Key（优先级最高）
/// 运行命令示例：flutter run --dart-define=MODELSCOPE_API_KEY=sk-xxx
const String _dartDefineApiKey = String.fromEnvironment(kApiKeyEnvName);

/// API Key 未配置异常 - UI 据此显示「请配置 API Key」
class AiConfigException implements Exception {
  final String message;
  AiConfigException(this.message);

  @override
  String toString() => message;
}

/// AI 模型配置 - 预留切换其他模型的接口
/// 注意：API Key 不存放在此配置中（避免硬编码），统一通过 _resolveApiKey 从环境读取
/// 新增模型时只需添加一个 AiModelConfig 常量，构造 AiAnalysisService 时传入即可
class AiModelConfig {
  final String name; // 模型名称（用于日志和错误提示）
  final String apiUrl; // API 地址（OpenAI 兼容格式）
  final String model; // 模型 ID

  const AiModelConfig({
    required this.name,
    required this.apiUrl,
    required this.model,
  });

  // ============ 预设配置 ============

  /// DeepSeek 官方 API（需 DeepSeek 平台的 Key）
  static const AiModelConfig deepseek = AiModelConfig(
    name: 'DeepSeek',
    apiUrl: 'https://api.deepseek.com/v1/chat/completions',
    model: 'deepseek-chat',
  );

  /// ModelScope 魔搭推理 API（ms- 开头的 Key 走这里）
  /// 选用 Qwen3 Instruct 指令型模型：无思考链、响应快、内容干净
  static const AiModelConfig modelscope = AiModelConfig(
    name: 'ModelScope',
    apiUrl: 'https://api-inference.modelscope.cn/v1/chat/completions',
    model: 'Qwen/Qwen3-235B-A22B-Instruct-2507',
  );

  // 示例：切换其他 OpenAI 兼容模型时，按此格式添加配置并传入构造函数
  // static const AiModelConfig openai = AiModelConfig(
  //   name: 'OpenAI',
  //   apiUrl: 'https://api.openai.com/v1/chat/completions',
  //   model: 'gpt-4o-mini',
  // );
}

/// AI 分析服务 - 调用大模型分析用户的刷手机数据，生成个性化建议
/// 相当于 MindSieve 的「AI 私人教练」：不只记录数据，而是理解使用习惯并给出可执行建议
class AiAnalysisService {
  final AiModelConfig _config;
  static const Duration _timeout = Duration(seconds: 30); // 超时时间

  AiAnalysisService({AiModelConfig config = AiModelConfig.modelscope})
    : _config = config;

  /// 解析 API Key，优先级：
  /// 1. --dart-define 命令行注入（编译期常量）
  /// 2. .env 文件（main.dart 启动时已加载）
  /// 3. 都没有 → 返回 null，由调用方提示配置
  String? _resolveApiKey() {
    if (_dartDefineApiKey.trim().isNotEmpty) {
      return _dartDefineApiKey.trim();
    }
    final envKey = dotenv.env[kApiKeyEnvName];
    if (envKey != null && envKey.trim().isNotEmpty) {
      return envKey.trim();
    }
    return null;
  }

  /// 判断 API Key 是否已配置（供 UI 提前检查）
  bool get isApiKeyConfigured => _resolveApiKey() != null;

  /// 分析今日使用数据
  /// 返回 AI 生成的建议文本；失败时抛出异常，由调用方降级显示本地建议
  Future<String> analyzeTodayUsage({
    required List<AppUsageStats> topApps,
    required List<HourlyStats> hourly,
    required int totalDuration,
    required int totalOpens,
  }) async {
    // Key 未配置时直接抛出配置异常，UI 显示「请配置 API Key」
    final apiKey = _resolveApiKey();
    if (apiKey == null) {
      // 控制台提示，方便开发时排查
      // ignore: avoid_print
      print(
        'MindSieve: 未配置 $kApiKeyEnvName，请通过 .env 文件或 '
        '--dart-define=$kApiKeyEnvName=sk-xxx 提供密钥',
      );
      throw AiConfigException('请配置 API Key');
    }

    final prompt = _buildPrompt(
      topApps: topApps,
      hourly: hourly,
      totalDuration: totalDuration,
      totalOpens: totalOpens,
    );
    final raw = await _chatCompletion(prompt, apiKey);
    return _cleanResponse(raw);
  }

  /// 把使用数据拼接成结构化的 prompt
  String _buildPrompt({
    required List<AppUsageStats> topApps,
    required List<HourlyStats> hourly,
    required int totalDuration,
    required int totalOpens,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('今日总使用时长：${_formatDuration(totalDuration)}');
    buffer.writeln('今日打开次数：$totalOpens 次');

    // 各 App 使用明细
    if (topApps.isEmpty) {
      buffer.writeln('今日暂无 App 使用记录');
    } else {
      buffer.writeln('各 App 使用情况（按时长排序）：');
      for (var i = 0; i < topApps.length; i++) {
        final app = topApps[i];
        buffer.writeln(
          '${i + 1}. ${app.appName}：${_formatDuration(app.totalDuration)}（打开 ${app.openCount} 次）',
        );
      }
    }

    // 时段分布
    if (hourly.isNotEmpty) {
      buffer.writeln('24小时时段分布：');
      for (final h in hourly) {
        buffer.writeln('- ${h.hour}时：${_formatDuration(h.duration)}');
      }
    }

    return buffer.toString();
  }

  /// 调用 Chat Completions API（OpenAI 兼容格式，DeepSeek 适用）
  Future<String> _chatCompletion(String userPrompt, String apiKey) async {
    const systemPrompt =
        '你是一位专注于数字健康的 AI 私人教练，'
        '负责分析用户的手机使用数据并给出改进建议。'
        '要求：\n'
        '1. 语气友好但直接，像关心朋友一样\n'
        '2. 给出 2-4 条具体、可执行的建议，每条一行，以「•」开头\n'
        '3. 建议要基于数据（如具体 App、具体时段），不要空泛\n'
        '4. 每条建议不超过 50 字，不要使用 markdown 格式\n'
        '5. 如果数据显示用户习惯很好，也要给予肯定和鼓励';

    final response = await http
        .post(
          Uri.parse(_config.apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': _config.model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': 0.7,
            'max_tokens': 500,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('${_config.name} API 请求失败: HTTP ${response.statusCode}');
    }

    // 解析 OpenAI 兼容格式的响应（注意用 utf8 解码中文）
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('AI 返回内容为空');
    }

    final message =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('AI 返回内容为空');
    }
    return content;
  }

  /// 清理 AI 返回的文本（去掉可能的 markdown 代码块标记）
  String _cleanResponse(String text) {
    return text.replaceAll('```', '').trim();
  }

  /// 把秒数格式化成 "X小时X分钟"
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    return '$minutes分钟';
  }
}
