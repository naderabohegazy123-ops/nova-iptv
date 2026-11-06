
class XtreamAccount {
  const XtreamAccount({
    required this.server,
    required this.username,
    required this.password,
  });

  final String server;
  final String username;
  final String password;

  String get normalizedServer {
    var value = server.trim();

    if (value.isEmpty) {
      throw const FormatException('Server URL is empty');
    }

    // Add HTTP automatically if no protocol was entered.
    if (!value.startsWith(RegExp(r'^https?://', caseSensitive: false))) {
      value = 'http://$value';
    }

    final uri = Uri.tryParse(value);

    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Invalid server URL');
    }

    return uri.replace(
      path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
      query: null,
      fragment: null,
    ).toString().replaceFirst(RegExp(r'/+$'), '');
  }

  Uri get apiUri {
    final base = Uri.parse(normalizedServer);

    return base.replace(
      path: '${base.path}/player_api.php',
      query: null,
      fragment: null,
    );
  }
}
