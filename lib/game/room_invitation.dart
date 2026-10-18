/// Invitations contain only a room identifier; identities never travel in links.
String roomCodeFromInvitation(String input) {
  final text = input.trim();
  final plain = text.toUpperCase();
  if (RegExp(r'^([UH][A-Z]{6}|[A-Z0-9]{6})$').hasMatch(plain)) return plain;
  final uri = Uri.tryParse(text);
  const paths = {'/stones/', '/stones', '/'};
  const hosts = {'www.douglastkaiser.com', 'douglastkaiser.com', 'douglastkaiser.github.io'};
  if (uri == null || uri.userInfo.isNotEmpty || uri.hasPort ||
      (uri.hasAuthority && (uri.scheme != 'https' || !hosts.contains(uri.host))) ||
      (!uri.hasAuthority && (uri.scheme.isNotEmpty || !text.startsWith('/'))) ||
      !paths.contains(uri.path) || uri.fragment.isNotEmpty) {
    throw StateError('Paste a Stones invitation link or enter its room code.');
  }
  final codes = uri.queryParametersAll['room'];
  if (codes == null || codes.length != 1) {
    throw StateError('This invitation needs one room code. Ask your friend for a new link.');
  }
  final code = codes.single.toUpperCase();
  if (!RegExp(r'^([UH][A-Z]{6}|[A-Z0-9]{6})$').hasMatch(code)) {
    throw StateError('This room code is not valid. Check it with your friend.');
  }
  return code;
}

Uri roomInvitation(String code) => Uri.https('www.douglastkaiser.com',
    '/stones/', {'room': roomCodeFromInvitation(code)});
