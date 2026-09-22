import 'package:audioplayers/audioplayers.dart';

class Sfx {
  static final Sfx instance = Sfx._();

  Sfx._();

  static const click = 'Button_Click_asset.mp3';
  static const menuOpen = 'Menu_Open_asset.mp3';
  static const menuClose = 'Menu_Close_asset.mp3';
  static const coin = 'Coin_Collect_asset.mp3';
  static const fruit = 'Fruit_Collect_asset.mp3';
  static const star = 'Purple_Star_Collect_asset.mp3';
  static const seven = 'Purple_Seven_Collect_asset.mp3';
  static const spawn = 'Object_Spawn_asset.mp3';
  static const disappear = 'Object_Disappear_asset.mp3';
  static const rOn = 'R_Activation_asset.mp3';
  static const rareOn = 'Rare_Event_Activation_asset.mp3';
  static const rareAlert = 'Rare_Object_Alert_asset.mp3';
  static const reward = 'Reward_Received_asset.mp3';
  static const done = 'Observation_Complete_asset.mp3';
  static const unlockItem = 'Collection_Unlock_asset.mp3';
  static const unlockRoom = 'New_Room_Unlock_asset.mp3';
  static const upgrade = 'Upgrade_Complete_asset.mp3';
  static const stream = 'Coin_Stream_Activation_asset.mp3';
  static const levelDone = 'Level_Complete_asset.mp3';

  final List<AudioPlayer> _voices = List.generate(5, (_) => AudioPlayer());
  final Set<AudioPlayer> _mixed = {};
  int _next = 0;
  bool enabled = true;

  static final AudioContext _mix = AudioContext(
    android: AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  void play(String file) {
    if (!enabled) return;
    final voice = _voices[_next];
    _next = (_next + 1) % _voices.length;
    final source = AssetSource('Bright_Horizon_sounds_assets/$file');
    final Future<void> started;
    if (_mixed.contains(voice)) {
      started = voice.play(source);
    } else {
      started = voice.setAudioContext(_mix).then((_) {
        _mixed.add(voice);
        return voice.play(source);
      });
    }
    started.then<void>((_) {}, onError: (Object _) {});
  }

  Future<void> dispose() async {
    for (final voice in _voices) {
      await voice.dispose();
    }
  }
}
