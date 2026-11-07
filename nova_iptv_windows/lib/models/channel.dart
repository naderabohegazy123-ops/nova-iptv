
class Channel {
  const Channel({
    required this.name,
    required this.url,
    this.logo,
    this.group = 'Other',
    this.tvgId,
    this.id,
    this.categoryId,
    this.extension,
    this.contentType = 'live',
  });

  final String name;
  final String url;
  final String? logo;
  final String group;
  final String? tvgId;

  // Content information
  final String? id;
  final String? categoryId;
  final String? extension;

  // live, movie, episode, or m3u
  final String contentType;

  String get uniqueKey {
    if (id != null && id!.isNotEmpty) {
      return '$contentType:$id';
    }

    return '$contentType:${url.hashCode}';
  }
}
