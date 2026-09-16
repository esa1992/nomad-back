/// Allow-listed parlor avatar presets (PROF-03 / D-76). Server validates the same ids.
const List<String> kAvatarPresets = <String>[
  'avatar_01',
  'avatar_02',
  'avatar_03',
  'avatar_04',
  'avatar_05',
  'avatar_06',
  'avatar_07',
  'avatar_08',
];

const String kDefaultAvatarPreset = 'avatar_01';

String avatarAssetPath(String presetId) {
  final String id =
      kAvatarPresets.contains(presetId) ? presetId : kDefaultAvatarPreset;
  return 'assets/avatars/$id.png';
}
