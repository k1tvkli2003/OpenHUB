String formatCompactNumber(num? value) {
  if (value == null) {
    return '—';
  }
  final absolute = value.abs();
  if (absolute >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1)}B';
  }
  if (absolute >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (absolute >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value is int ? value.toString() : value.toStringAsFixed(1);
}

String formatPercent(num? value) {
  if (value == null) {
    return '—';
  }
  return '${value.clamp(0, 100).toStringAsFixed(value % 1 == 0 ? 0 : 1)}%';
}

String formatMoney(double value, String currency) {
  final symbol = currency.toUpperCase() == 'USD'
      ? r'$'
      : '${currency.toUpperCase()} ';
  return '$symbol${value.toStringAsFixed(value < 10 ? 2 : 1)}';
}

String formatTimestamp(DateTime? value) {
  if (value == null) {
    return 'Never';
  }
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String formatRelative(DateTime? value, {DateTime? now}) {
  if (value == null) {
    return 'never';
  }
  final reference = (now ?? DateTime.now()).toUtc();
  final target = value.toUtc();
  final difference = reference.difference(target);
  if (difference.isNegative) {
    final future = target.difference(reference);
    if (future.inMinutes < 1) {
      return 'in ${future.inSeconds.clamp(1, 59)}s';
    }
    if (future.inHours < 1) {
      return 'in ${future.inMinutes}m';
    }
    if (future.inDays < 1) {
      return 'in ${future.inHours}h';
    }
    return 'in ${future.inDays}d';
  }
  if (difference.inSeconds < 5) {
    return 'just now';
  }
  if (difference.inMinutes < 1) {
    return '${difference.inSeconds}s ago';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }
  return '${difference.inDays}d ago';
}

String formatResetCountdown(DateTime? value, {DateTime? now}) {
  if (value == null) {
    return 'Not reported';
  }
  final current = (now ?? DateTime.now()).toUtc();
  final difference = value.toUtc().difference(current);
  if (difference <= Duration.zero) {
    return 'Due now';
  }
  if (difference < const Duration(minutes: 1)) {
    return '${difference.inSeconds.clamp(1, 59)}s';
  }
  if (difference < const Duration(hours: 1)) {
    return '${difference.inMinutes.toString().padLeft(2, '0')}m';
  }
  if (difference < const Duration(days: 1)) {
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}h '
        '${minutes.toString().padLeft(2, '0')}m';
  }
  final days = difference.inDays;
  final hours = difference.inHours.remainder(24);
  return '${days}d ${hours.toString().padLeft(2, '0')}h';
}
