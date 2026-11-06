import '../models/channel.dart';

class M3uParser {
  static List<Channel> parse(String content) {
    final result = <Channel>[];
    final lines = content.split(RegExp(r'\r?\n'));
    Map<String, String> meta = {};

    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('#EXTINF:')) {
        meta = {};
        for (final m in RegExp(r'''([\w-]+)="([^"]*)"''').allMatches(line)) {
          meta[m.group(1)!] = m.group(2)!;
        }
        final comma = line.lastIndexOf(',');
        meta['_name'] = comma >= 0 ? line.substring(comma + 1).trim() : '';
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        result.add(Channel(
          name: (meta['_name'] ?? '').isEmpty ? 'Unnamed channel' : meta['_name']!,
          url: line,
          logo: meta['tvg-logo'],
          group: meta['group-title'] ?? 'Other',
          tvgId: meta['tvg-id'],
        ));
        meta = {};
      }
    }
    return result;
  }
}
