// Asset table for the cabinet.
//
// The relay boot on android-gray-part imports this file and precaches
// [logoAsset], [bgHorizon], [bgFruit] and [bgViolet] by those names.
// Keep the four names pointed at real files in this pack.

const logoAsset = 'assets/branding/wordmark.webp';
const appIconAsset = 'assets/branding/app_icon.webp';

const loadingPortrait = 'assets/loading/portrait.webp';
const loadingLandscape = 'assets/loading/landscape.webp';

const cabinetBackdrop = 'assets/cabinet/backdrop.webp';
const reelFrameAsset = 'assets/cabinet/reel_frame.webp';
const playAsset = 'assets/cabinet/play.webp';
const stakeOnAsset = 'assets/cabinet/stake_on.webp';
const stakeOffAsset = 'assets/cabinet/stake_off.webp';

const bgHorizon = cabinetBackdrop;
const bgFruit = reelFrameAsset;
const bgViolet = 'assets/symbols/seven.webp';

const framePixelWidth = 2138.0;
const framePixelHeight = 1283.0;
const frameAspect = framePixelWidth / framePixelHeight;

/// Centers of the 5×3 windows, as fractions of [reelFrameAsset].
const reelCenterX = <double>[0.1878, 0.3431, 0.4991, 0.6546, 0.8120];
const rowCenterY = <double>[0.2521, 0.4965, 0.7366];
const cellWidthFactor = 0.124;
const cellHeightFactor = 0.198;
