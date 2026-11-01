import '../game/result_share_data.dart' show stonesPlayUrl;

/// Keep About navigation in a web preview, while native installs use production.
Uri sharingKitUrl({Uri? webBase}) => webBase != null
    ? webBase.resolve('share/')
    : Uri.parse('${stonesPlayUrl}share/');
