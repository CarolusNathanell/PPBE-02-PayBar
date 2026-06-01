import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CurrencyService {
  static const _baseUrl = 'https://api.frankfurter.app';

  static const List<String> supportedCurrencies = [
    'IDR', 'USD', 'EUR', 'SGD', 'MYR', 'JPY', 'AUD', 'GBP',
  ];

  static const Map<String, String> currencySymbols = {
    'IDR': 'Rp',
    'USD': '\$',
    'EUR': '€',
    'SGD': 'S\$',
    'MYR': 'RM',
    'JPY': '¥',
    'AUD': 'A\$',
    'GBP': '£',
  };

  // Konversi amount ke IDR via Frankfurter API (gratis, no key)
  Future<double> convertToIdr(double amount, String fromCurrency) async {
    if (fromCurrency == 'IDR') return amount;

    final response = await http
        .get(Uri.parse('$_baseUrl/latest?from=$fromCurrency&to=IDR'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) throw Exception('API error');

    final data = json.decode(response.body) as Map<String, dynamic>;
    final rate = (data['rates']['IDR'] as num).toDouble();
    return amount * rate;
  }

  // Format angka untuk display: "Rp 150.000", "$ 10.00", dll
  static String formatCurrency(double amount, String currency) {
    switch (currency) {
      case 'IDR':
        return 'Rp ${NumberFormat('#,###', 'id_ID').format(amount.round())}';
      case 'JPY':
        return '¥ ${NumberFormat('#,###').format(amount.round())}';
      default:
        final symbol = currencySymbols[currency] ?? currency;
        return '$symbol ${NumberFormat('#,##0.00').format(amount)}';
    }
  }
}
