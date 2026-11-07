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
    this.year,
    this.rating,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.duration,
    this.backdrop,
  });

  final String name;
  final String url;
  final String? logo;
  final String group;
  final String? tvgId;

  final String? id;
  final String? categoryId;
  final String? extension;

  // live, movie, episode, or m3u
  final String contentType;

  // Additional movie and series information
  final String? year;
  final String? rating;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? duration;
  final String? backdrop;

  String get uniqueKey {
    if (id != null && id!.isNotEmpty) {
      return '$contentType:$id';
    }

    var hash = 0x811c9dc5;

    for (final codeUnit in url.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    return '$contentType:${hash.toRadixString(16)}';
  }
}
