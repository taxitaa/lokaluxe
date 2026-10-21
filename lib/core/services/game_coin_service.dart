import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk menyimpan dan mengambil data koin game LokaCatch secara lokal
///
/// Menggunakan SharedPreferences sebagai penyimpanan ringan untuk:
/// - Total koin yang dimiliki pemain
/// - Jumlah sesi yang telah dimainkan
/// - Apakah ini kali pertama pencapaian 10 item
class GameCoinService {
  // Kunci SharedPreferences
  static const String _totalCoinsKey = 'lokacatch_total_coins';
  static const String _totalSessionsKey = 'lokacatch_total_sessions';
  static const String _highScoreKey = 'lokacatch_high_score';

  // Reward koin (sesuai spesifikasi)
  static const int _firstAchievementReward = 50; // Pencapaian pertama
  static const int _subsequentReward = 20;        // Pencapaian berikutnya

  /// Mendapatkan total koin saat ini
  static Future<int> getTotalCoins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_totalCoinsKey) ?? 0;
    } catch (e) {
      debugPrint('[GameCoinService] Gagal membaca koin: $e');
      return 0;
    }
  }

  /// Mendapatkan total sesi yang telah dimainkan
  static Future<int> getTotalSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_totalSessionsKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Mendapatkan skor tertinggi (jumlah item tangkap terbanyak dalam satu sesi)
  static Future<int> getHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_highScoreKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Memberikan reward koin saat pemain berhasil menangkap 10 item.
  ///
  /// Mengembalikan jumlah koin yang diberikan pada sesi ini.
  /// Koin pertama = 50, berikutnya = 20.
  static Future<int> awardCoinsForCompletion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = prefs.getInt(_totalSessionsKey) ?? 0;
      final currentCoins = prefs.getInt(_totalCoinsKey) ?? 0;

      // Tentukan reward berdasarkan jumlah sesi sebelumnya
      final reward = sessions == 0 ? _firstAchievementReward : _subsequentReward;
      final newTotal = currentCoins + reward;
      final newSessions = sessions + 1;

      // Simpan ke SharedPreferences
      await prefs.setInt(_totalCoinsKey, newTotal);
      await prefs.setInt(_totalSessionsKey, newSessions);

      debugPrint('[GameCoinService] +$reward koin. Total: $newTotal (sesi #$newSessions)');
      return reward;
    } catch (e) {
      debugPrint('[GameCoinService] Gagal memberikan reward: $e');
      return 0;
    }
  }

  /// Memperbarui high score jika skor saat ini lebih tinggi
  static Future<void> updateHighScore(int score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_highScoreKey) ?? 0;
      if (score > current) {
        await prefs.setInt(_highScoreKey, score);
        debugPrint('[GameCoinService] High score baru: $score');
      }
    } catch (e) {
      debugPrint('[GameCoinService] Gagal update high score: $e');
    }
  }

  /// Reset semua data game (untuk testing)
  static Future<void> resetAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_totalCoinsKey);
      await prefs.remove(_totalSessionsKey);
      await prefs.remove(_highScoreKey);
    } catch (_) {}
  }
}
