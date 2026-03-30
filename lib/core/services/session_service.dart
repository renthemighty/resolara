import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import '../models/extraction_result.dart';
import '../storage/app_database.dart';

// Cost rates (USD)
const _claudeInputCostPerM  = 3.0;   // $3 per 1M input tokens
const _claudeOutputCostPerM = 15.0;  // $15 per 1M output tokens
const _imageGenerationCost  = 0.040; // $0.040 per gpt-image-1 image

const _uuid = Uuid();

class SessionService {
  final AppDatabase _db;
  SessionService(this._db);

  // ── Create ────────────────────────────────────────────────────────────────

  Future<String> createSession({
    required List<Finding> findings,
    int tokensIn = 0,
    int tokensOut = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final regions = findings.map((f) => f.bodyRegion).toSet().join(',');

    await _db.insertSession(SessionsCompanion(
      id: Value(id),
      status: const Value('generating'),
      findingsJson: Value(_encodeFindings(findings)),
      bodyRegions: Value(regions),
      findingCount: Value(findings.length),
      startedAt: Value(now),
      updatedAt: Value(now),
      tokensIn: Value(tokensIn),
      tokensOut: Value(tokensOut),
    ));

    return id;
  }

  // ── Update viz job ID (set once generation is submitted) ──────────────────

  Future<void> setVizJobId(String sessionId, String vizJobId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.updateSession(SessionsCompanion(
      id: Value(sessionId),
      vizJobId: Value(vizJobId),
      updatedAt: Value(now),
    ));
  }

  // ── Mark completed ────────────────────────────────────────────────────────

  Future<void> completeSession(String sessionId, {
    required String imageUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Do NOT update tokensIn/tokensOut here — they were saved at createSession
    // from extraction and must not be overwritten with zeros.
    await _db.updateSession(SessionsCompanion(
      id: Value(sessionId),
      status: const Value('completed'),
      imageUrl: Value(imageUrl),
      updatedAt: Value(now),
    ));
  }

  // ── Mark failed ───────────────────────────────────────────────────────────

  Future<void> failSession(String sessionId, String error) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.updateSession(SessionsCompanion(
      id: Value(sessionId),
      status: const Value('failed'),
      errorMessage: Value(error),
      updatedAt: Value(now),
    ));
  }

  // ── Update token counts after extraction ──────────────────────────────────

  Future<void> updateTokens(String sessionId, int tokensIn, int tokensOut) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.updateSession(SessionsCompanion(
      id: Value(sessionId),
      tokensIn: Value(tokensIn),
      tokensOut: Value(tokensOut),
      updatedAt: Value(now),
    ));
  }

  // ── Cost estimate helpers ─────────────────────────────────────────────────

  /// Estimated USD cost for a session based on token usage.
  static double estimateCost(Session session) {
    final inputCost  = (session.tokensIn  / 1_000_000) * _claudeInputCostPerM;
    final outputCost = (session.tokensOut / 1_000_000) * _claudeOutputCostPerM;
    final imageCost  = session.status == 'completed' ? _imageGenerationCost : 0.0;
    return inputCost + outputCost + imageCost;
  }

  static String formatCost(Session session) {
    final cost = estimateCost(session);
    if (cost < 0.001) return '< \$0.001';
    return '\$${cost.toStringAsFixed(3)}';
  }

  static String formatTokens(Session session) {
    final total = session.tokensIn + session.tokensOut;
    if (total == 0) return '—';
    if (total >= 1000) return '${(total / 1000).toStringAsFixed(1)}k tokens';
    return '$total tokens';
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  static String _encodeFindings(List<Finding> findings) {
    return jsonEncode(findings.map((f) => {
      'id': f.id,
      'body_region': f.bodyRegion,
      'finding': f.text,
      'layman_term': f.laymanTerm,
      'confidence': f.confidence,
      'pii_risk': f.piiRisk,
    }).toList());
  }

  static List<Finding> decodeFindings(String json) {
    final list = jsonDecode(json) as List;
    return list.map((j) => Finding.fromJson(j as Map<String, dynamic>)).toList();
  }
}
