import 'dart:ui';

const gp = 'assets/Bright_Horizon_gameplay_assets/';
const extra = 'assets/Bright_Horizon_additional_assets/';

const logoAsset = '${extra}Game_Name.webp';
const loadingLandscape = '${extra}Horizontal_Loading_Screen.webp';
const loadingPortrait = '${extra}Vertical_Loading_Screen.webp';
const noticeLandscape = '${extra}Horizontal_Notifications_Screen.webp';
const noticePortrait = '${extra}Vertical_Notifications_Screen.webp';

const bgHorizon = '${gp}Horizon_Hall_bg_asset.webp';
const bgFruit = '${gp}Fruit_Chamber_bg_asset.webp';
const bgViolet = '${gp}Violet_Room_bg_asset.webp';
const bgR = '${gp}R_Chamber_bg_asset.webp';
const bgGarden = '${gp}Violet_Garden_bg_asset.webp';
const bgAtrium = '${gp}Golden_Atrium_bg_asset.webp';

class Frame {
  final String asset;
  final Rect src;

  const Frame(this.asset, this.src);

  double get aspect => src.width / src.height;

  static const sheetW = 1584.0;
  static const sheetH = 672.0;
}

Frame _f(String file, double l, double t, double r, double b) {
  return Frame('$gp$file', Rect.fromLTRB(l, t, r, b));
}

final coinFrame = _f('Golden_Coin_asset.webp', 444, 36, 1132, 612);
final starDiscFrame = _f('Flying_Coins_Set_asset.webp', 104, 172, 392, 472);
final diamondFrame = _f('Flying_Coins_Set_asset.webp', 484, 168, 736, 496);
final burstFrame = _f('Flying_Coins_Set_asset.webp', 824, 172, 1120, 488);
final hexFrame = _f('Flying_Coins_Set_asset.webp', 1208, 196, 1468, 476);

final appleFrame = _f('Fruit_Set_asset.webp', 56, 136, 388, 508);
final orangeFrame = _f('Fruit_Set_asset.webp', 440, 180, 764, 504);
final grapesFrame = _f('Fruit_Set_asset.webp', 828, 100, 1152, 520);
final cherriesFrame = _f('Fruit_Set_asset.webp', 1204, 184, 1524, 524);

final appleStreakFrame = _f('Moving_Fruits_Set_asset.webp', 380, 60, 756, 308);
final orangeStreakFrame = _f('Moving_Fruits_Set_asset.webp', 840, 76, 1264, 320);
final grapeStreakFrame = _f('Moving_Fruits_Set_asset.webp', 348, 332, 724, 600);
final cherryStreakFrame = _f('Moving_Fruits_Set_asset.webp', 920, 332, 1280, 588);

final starFrame = _f('Purple_Star_asset.webp', 540, 80, 1060, 588);
final spiralStarFrame = _f('Rare_Stars_Set_asset.webp', 400, 20, 728, 332);
final coreStarFrame = _f('Rare_Stars_Set_asset.webp', 884, 28, 1208, 336);
final latticeStarFrame = _f('Rare_Stars_Set_asset.webp', 384, 332, 704, 640);
final tideStarFrame = _f('Rare_Stars_Set_asset.webp', 856, 332, 1184, 644);

final sevenFrame = _f('Purple_Seven_asset.webp', 580, 52, 1036, 616);
final crestSevenFrame = _f('Rare_Sevens_Set_asset.webp', 92, 76, 384, 560);
final pillarSevenFrame = _f('Rare_Sevens_Set_asset.webp', 464, 112, 752, 560);
final curlSevenFrame = _f('Rare_Sevens_Set_asset.webp', 844, 120, 1128, 556);
final shardSevenFrame = _f('Rare_Sevens_Set_asset.webp', 1244, 108, 1528, 576);

final letterFrame = _f('Main_R_Object_asset.webp', 512, 28, 1068, 664);
final orbFrame = _f('Observation_Light_Orb_asset.webp', 576, 96, 1008, 580);
final spawnZoneFrame = _f('Object_Spawn_Zone_asset.webp', 436, 36, 1112, 628);
final rZoneFrame = _f('R_Zone_asset.webp', 248, 20, 1328, 664);
final platformFrame = _f('Central_Light_Platform_asset.webp', 380, 12, 1208, 648);
final pedestalFrame = _f('Collection_Pedestal_asset.webp', 328, 28, 1268, 660);

final colTaperFrame = _f('Decorative_Columns_Set_asset.webp', 124, 44, 372, 632);
final colCurveFrame = _f('Decorative_Columns_Set_asset.webp', 476, 32, 732, 620);
final colGothicFrame = _f('Decorative_Columns_Set_asset.webp', 852, 40, 1120, 632);
final colFlutedFrame = _f('Decorative_Columns_Set_asset.webp', 1244, 52, 1500, 636);

final wallFrame = _f('Architectural_Elements_Set_asset.webp', 52, 156, 412, 528);
final archFrame = _f('Architectural_Elements_Set_asset.webp', 448, 100, 820, 568);
final shrineFrame = _f('Architectural_Elements_Set_asset.webp', 876, 60, 1176, 504);
final railFrame = _f('Architectural_Elements_Set_asset.webp', 1236, 264, 1492, 576);

final bloomFrame = _f('Violet_Garden_Elements_Set_asset.webp', 72, 80, 380, 584);
final lampVineFrame = _f('Violet_Garden_Elements_Set_asset.webp', 464, 68, 736, 588);
final urnFrame = _f('Violet_Garden_Elements_Set_asset.webp', 788, 96, 1148, 588);
final bushFrame = _f('Violet_Garden_Elements_Set_asset.webp', 1176, 192, 1504, 560);

final lanternFrame = _f('Golden_Atrium_Elements_Set_asset.webp', 136, 92, 412, 556);
final daisFrame = _f('Golden_Atrium_Elements_Set_asset.webp', 600, 36, 944, 360);
final goldArchFrame = _f('Golden_Atrium_Elements_Set_asset.webp', 1004, 172, 1508, 620);
final medallionFrame = _f('Golden_Atrium_Elements_Set_asset.webp', 540, 388, 964, 664);

final panelDiamondFrame = _f('Glowing_Panels_Set_asset.webp', 208, 28, 790, 334);
final panelCircleFrame = _f('Glowing_Panels_Set_asset.webp', 792, 34, 1272, 334);
final panelHexFrame = _f('Glowing_Panels_Set_asset.webp', 368, 336, 790, 644);
final panelPlankFrame = _f('Glowing_Panels_Set_asset.webp', 792, 336, 1364, 616);

final pickupFrame = _f('Collectible_Pickup_VFX_asset.webp', 528, 72, 1096, 636);
final spawnFxFrame = _f('Object_Spawn_VFX_asset.webp', 168, 24, 1392, 648);
final disappearFrame = _f('Object_Disappear_VFX_asset.webp', 260, 116, 1324, 592);
final rActivateFrame = _f('R_Activation_VFX_asset.webp', 196, 76, 1376, 616);
final rareFxFrame = _f('Rare_Event_VFX_asset.webp', 120, 108, 1480, 640);

final dioramaSkyFrame = _f('Room_Set_asset.webp', 8, 4, 784, 332);
final dioramaFruitFrame = _f('Room_Set_asset.webp', 804, 4, 1572, 332);
final dioramaVioletFrame = _f('Room_Set_asset.webp', 8, 340, 784, 668);
final dioramaEmberFrame = _f('Room_Set_asset.webp', 804, 340, 1572, 668);
