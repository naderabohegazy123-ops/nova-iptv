class Channel {
  const Channel({
    required this.name,
    required this.url,
    this.logo,
    this.group = 'Other',
    this.tvgId,
  });

  final String name;
  final String url;
  final String? logo;
  final String group;
  final String? tvgId;
}
