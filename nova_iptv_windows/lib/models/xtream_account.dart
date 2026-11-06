class XtreamAccount {
  const XtreamAccount({
    required this.server,
    required this.username,
    required this.password,
  });

  final String server;
  final String username;
  final String password;

  Uri get apiUri => Uri.parse(
    '${server.replaceAll(RegExp(r'/+$'), '')}/player_api.php',
  );
}
