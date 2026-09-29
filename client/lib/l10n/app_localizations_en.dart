// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get playAlchiki => 'Play Alchiki';

  @override
  String get playStickPull => 'Play Stick Pull';

  @override
  String get createStickPullRoom => 'Create Stick Pull room';

  @override
  String get holdThrow => 'Hold Throw';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get backToMatch => 'Back to match';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get howToPlay => 'How to play';

  @override
  String get leaveMatch => 'Leave match';

  @override
  String get stay => 'Stay';

  @override
  String get backToCatalog => 'Back to catalog';

  @override
  String get retry => 'Retry';

  @override
  String get appTitle => 'Nomad Games';

  @override
  String get langEn => 'EN';

  @override
  String get langRu => 'RU';

  @override
  String get alchikiTitle => 'Alchiki';

  @override
  String get stickPullTitle => 'Stick Pull';

  @override
  String get moreGamesTitle => 'More games';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get diffEasy => 'Easy';

  @override
  String get diffNormal => 'Normal';

  @override
  String get diffHard => 'Hard';

  @override
  String get howtoCircleTitle => 'The circle';

  @override
  String get howtoCircleBody =>
      'Knock the tan bones fully outside the green circle with your bright saka.';

  @override
  String get howtoAimTitle => 'Aim';

  @override
  String get howtoAimBody =>
      'Drag around the saka to rotate the arrow. The arrow length does not change.';

  @override
  String get howtoHoldTitle => 'Hold to throw';

  @override
  String get howtoHoldBody =>
      'Press Hold Throw to charge power, then release. A longer hold is a stronger throw.';

  @override
  String get howtoScoreTitle => 'Out is one point';

  @override
  String get howtoScoreBody =>
      'After the bones stop, each target fully outside the circle scores 1 and leaves the table. If the saka leaves, you score 0 and it comes back.';

  @override
  String get howtoWinTitle => 'Clear the circle';

  @override
  String get howtoWinBody =>
      'Knock every bone fully outside. When the circle is empty or the match clock ends, the higher score wins.';

  @override
  String get howtoStickSitTitle => 'Sit opposite';

  @override
  String get howtoStickSitBody =>
      'Sit across from your opponent. You share one stick.';

  @override
  String get howtoStickGoTitle => 'Wait for GO';

  @override
  String get howtoStickGoBody =>
      'Wait for 3-2-1-GO. Taps before GO do not pull.';

  @override
  String get howtoStickTapTitle => 'Tap in rhythm';

  @override
  String get howtoStickTapBody =>
      'Tap the stick zone in a steady rhythm to pull the marker your way.';

  @override
  String get howtoStickStaminaTitle => 'Watch stamina';

  @override
  String get howtoStickStaminaBody =>
      'Do not mash. When stamina empties, your pull weakens and the marker slips.';

  @override
  String get howtoStickWinTitle => 'Pull it over';

  @override
  String get howtoStickWinBody =>
      'Pull the marker past the line on your side — or lead when the clock hits 0.';

  @override
  String get countdown3 => '3';

  @override
  String get countdown2 => '2';

  @override
  String get countdown1 => '1';

  @override
  String get countdownGo => 'GO';

  @override
  String stickClock(String ss) {
    return '${ss}s';
  }

  @override
  String get falseStartToast => 'Too early — wait for GO';

  @override
  String get stickTapHint => 'Tap';

  @override
  String get stickWaitGo => 'Wait for GO';

  @override
  String get stickPullNow => 'Pull!';

  @override
  String get errorStickPullStart => 'Stick Pull did not start. Tap Retry.';

  @override
  String get you => 'You';

  @override
  String get bot => 'Bot';

  @override
  String get firstToFive => 'Clear circle';

  @override
  String get yourTurn => 'Your turn';

  @override
  String get botsTurn => 'Bot\'s turn';

  @override
  String previewHud(int n) {
    return 'preview $n';
  }

  @override
  String scoredHud(int n) {
    return 'scored $n';
  }

  @override
  String get scoredDash => 'scored —';

  @override
  String get sakaOutLine => 'saka out · 0';

  @override
  String get plusOne => '+1';

  @override
  String turnClock(String ss) {
    return 'turn $ss';
  }

  @override
  String matchClock(int m, String ss) {
    return 'match $m:$ss';
  }

  @override
  String get turnTimeout => 'Time is up. This throw scores 0.';

  @override
  String get emptyCatalogTitle => 'No games yet';

  @override
  String get emptyCatalogBody => 'Catalog did not list any tables. Tap Retry.';

  @override
  String get errorGuestMint =>
      'Can\'t start as guest. Check the connection, then tap Retry.';

  @override
  String get errorCatalog => 'Catalog did not load. Tap Retry.';

  @override
  String get errorMatchStart =>
      'Match did not start. Tap Retry or return to the catalog.';

  @override
  String get errorThrow => 'Throw was not scored. Tap Retry to send it again.';

  @override
  String get youWin => 'You win';

  @override
  String get botWins => 'Bot wins';

  @override
  String get draw => 'Draw';

  @override
  String get leaveTitle => 'Leave this match?';

  @override
  String get leaveBody =>
      'You will return to the catalog. This bot match will end.';

  @override
  String get createRoom => 'Create room';

  @override
  String get joinByCode => 'Join by code';

  @override
  String get joinRoom => 'Join room';

  @override
  String get ready => 'Ready';

  @override
  String get shareCode => 'Share code';

  @override
  String get copyCode => 'Copy code';

  @override
  String get copied => 'Copied';

  @override
  String get leaveLobby => 'Leave lobby';

  @override
  String get playAgain => 'Play again';

  @override
  String get rematchAgain => 'Again?';

  @override
  String get rejoinMatch => 'Rejoin match';

  @override
  String shareSheetText(String code) {
    return 'Nomad Alchiki code: $code';
  }

  @override
  String get privateRoomTitle => 'Private room';

  @override
  String get roomCodeLabel => 'Room code';

  @override
  String guestLabel(String xxxx) {
    return 'Guest-$xxxx';
  }

  @override
  String get waitingForFriend => 'Waiting for a friend';

  @override
  String waitingForName(String name) {
    return 'Waiting for $name';
  }

  @override
  String get youAreReady => 'You are ready';

  @override
  String theyAreReady(String name) {
    return '$name is ready';
  }

  @override
  String get startingMatch => 'Starting…';

  @override
  String get loadingLobby => 'Loading…';

  @override
  String get opponent => 'Opponent';

  @override
  String get opponentsTurn => 'Opponent\'s turn';

  @override
  String get opponentWins => 'Opponent wins';

  @override
  String reconnecting(String ss) {
    return 'Reconnecting… $ss';
  }

  @override
  String opponentReconnecting(String ss) {
    return 'Opponent reconnecting… $ss';
  }

  @override
  String get opponentDisconnected => 'Opponent disconnected';

  @override
  String staminaA11y(int n) {
    return 'Stamina $n percent';
  }

  @override
  String rematchClock(String ss) {
    return 'again $ss';
  }

  @override
  String get emptyLobbyBody => 'Waiting for a friend. Share or copy the code.';

  @override
  String get emptyJoinBody => 'Enter the 4–6 character code.';

  @override
  String get errorNoSuchRoom => 'No such room. Check the code and try again.';

  @override
  String get errorAlreadyStarted =>
      'That room already started. Enter another code.';

  @override
  String get errorHostLeft => 'Host left. That code no longer works.';

  @override
  String get hostLeftTitle => 'Host left';

  @override
  String get hostLeftBody => 'The room closed. Tap Back to catalog.';

  @override
  String get roomClosedTitle => 'Room closed';

  @override
  String get roomClosedBody => 'Nobody was ready in time. Tap Back to catalog.';

  @override
  String get errorRoomCreate => 'Room did not create. Tap Retry.';

  @override
  String get errorReady => 'Ready did not send. Tap Retry.';

  @override
  String get errorRematch =>
      'Rematch did not start. Tap Retry or return to the catalog.';

  @override
  String get errorRejoin =>
      'Could not rejoin. Tap Rejoin match or wait for the timer.';

  @override
  String get leaveBodyPrivate =>
      'You will return to the catalog. Your opponent will win.';

  @override
  String get leaveRankedBody => 'Leave this match? It counts as a rated loss.';

  @override
  String get pauseBudgetGone => 'No reconnect left — forfeit if you drop';

  @override
  String get leaveLobbyTitle => 'Leave this room?';

  @override
  String get leaveLobbyBodyHost => 'The join code will stop working.';

  @override
  String get shop => 'Shop';

  @override
  String get owned => 'Owned';

  @override
  String get buyItem => 'Buy item';

  @override
  String get equipItem => 'Equip item';

  @override
  String get equipped => 'Equipped';

  @override
  String get backToShop => 'Back to shop';

  @override
  String get coins => 'COINS';

  @override
  String get gems => 'GEMS';

  @override
  String walletA11y(int coins, int gems) {
    return '$coins COINS, $gems GEMS';
  }

  @override
  String walletHint(int coins, int gems) {
    return 'Gold · coins (soft currency): $coins\nBlue · gems (premium): $gems\nTap Shop to spend them.';
  }

  @override
  String rewardCoins(int n) {
    return '+$n COINS';
  }

  @override
  String rewardGems(int m) {
    return '+$m GEMS';
  }

  @override
  String priceCoins(int n) {
    return '$n COINS';
  }

  @override
  String priceGems(int m) {
    return '$m GEMS';
  }

  @override
  String get priceFree => 'Free';

  @override
  String get shopTitle => 'Shop';

  @override
  String get catSakaColor => 'Saka color';

  @override
  String get catSakaMaterial => 'Saka material';

  @override
  String get catSakaOrnament => 'Saka ornament';

  @override
  String get catTrail => 'Trail';

  @override
  String get catTableFx => 'Table effects';

  @override
  String get catVictory => 'Victory animation';

  @override
  String get catStickPull => 'Stick Pull skins';

  @override
  String get emptyShopTitle => 'No items here';

  @override
  String get emptyShopBody => 'The shop did not list items. Tap Retry.';

  @override
  String get emptyOwnedTitle => 'Nothing owned yet';

  @override
  String get emptyOwnedBody =>
      'Win matches for COINS, then buy an item in Shop.';

  @override
  String get errorWallet => 'Balances did not load. Tap Retry.';

  @override
  String get errorShop => 'Shop did not load. Tap Retry.';

  @override
  String get errorPurchase => 'Purchase did not finish. Tap Retry.';

  @override
  String get errorInsufficientFunds =>
      'Not enough COINS or GEMS. Play a match to earn more.';

  @override
  String get errorEquip => 'Equip did not save. Tap Retry.';

  @override
  String get alreadyOwned => 'You already own this';

  @override
  String get skuSakaColorDefault => 'Default color';

  @override
  String get skuSakaColorGold => 'Gold color';

  @override
  String get skuSakaColorNeon => 'Neon color';

  @override
  String get skuSakaMaterialDefault => 'Default material';

  @override
  String get skuSakaMaterialIce => 'Ice material';

  @override
  String get skuSakaMaterialFire => 'Fire material';

  @override
  String get skuSakaOrnamentDefault => 'Default ornament';

  @override
  String get skuSakaOrnamentSpace => 'Space ornament';

  @override
  String get skuSakaOrnamentKnot => 'Knot ornament';

  @override
  String get skuTrailDefault => 'Default trail';

  @override
  String get skuTrailGold => 'Gold trail';

  @override
  String get skuTableFxDefault => 'Default table FX';

  @override
  String get skuTableFxNeon => 'Neon table FX';

  @override
  String get skuVictoryDefault => 'Default victory';

  @override
  String get skuVictoryFire => 'Fire victory';

  @override
  String get skuStickPullDefault => 'Default Stick Pull';

  @override
  String get skuStickPullIce => 'Ice Stick Pull';

  @override
  String get quickMatch => 'Quick Match';

  @override
  String get cancelSearch => 'Cancel search';

  @override
  String get searchingTitle => 'Searching…';

  @override
  String get searchingBody => 'Looking for an opponent';

  @override
  String get errorQuickMatch => 'Quick Match did not start. Tap Retry.';

  @override
  String get fallbackTitle => 'No opponent yet';

  @override
  String get fallbackBody => 'Play a bot or invite a friend';

  @override
  String get playVsBot => 'Play vs bot';

  @override
  String get inviteFriend => 'Invite friend';

  @override
  String get errorQueueLeft =>
      'Left the queue. Tap Retry or return to the catalog.';

  @override
  String get rematchWaitingTitle => 'Waiting for rematch';

  @override
  String get cancelRematch => 'Cancel rematch';

  @override
  String get openProfileA11y => 'Open profile';

  @override
  String get profileTitle => 'Profile';

  @override
  String get guestDisplay => 'Guest';

  @override
  String get saveAvatar => 'Save avatar';

  @override
  String levelLabel(int n) {
    return 'Level $n';
  }

  @override
  String xpProgress(int current, int next) {
    return '$current / $next XP';
  }

  @override
  String get statMatches => 'Matches';

  @override
  String get statWins => 'Wins';

  @override
  String get statLosses => 'Losses';

  @override
  String get statWinRate => 'Win rate';

  @override
  String statWinRateValue(int n) {
    return '$n%';
  }

  @override
  String get statRating => 'Rating';

  @override
  String get statBestRating => 'Best';

  @override
  String get cosmeticsSection => 'Selected cosmetics';

  @override
  String get cosmeticsDefault => 'Default loadout';

  @override
  String get avatarSection => 'Avatar';

  @override
  String get avatarCustomA11y => 'Add photo from gallery';

  @override
  String get errorAvatarPick =>
      'Could not open the gallery. Check permission and try again.';

  @override
  String get statsAlchiki => 'Alchiki';

  @override
  String get statsStickPull => 'Stick Pull';

  @override
  String get noMatchesYet => 'No matches yet';

  @override
  String get errorProfileTitle => 'Profile did not load';

  @override
  String get errorProfileBody => 'Tap Retry to load your stats.';

  @override
  String get errorAvatarSave => 'Avatar did not save. Tap Retry.';

  @override
  String get bindNow => 'Bind now';

  @override
  String get notNow => 'Not now';

  @override
  String get bindAccount => 'Bind account';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInInstead => 'Sign in instead';

  @override
  String get bindThisGuest => 'Bind this guest';

  @override
  String get bindSheetTitle => 'Keep your progress';

  @override
  String get bindSheetBody =>
      'Bind a username and password to keep cosmetics, wallets, and stats on this account.';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordRule => 'At least 8 characters';

  @override
  String get usernameTakenTitle => 'Username taken';

  @override
  String get usernameTakenBody =>
      'Sign in to that account, or choose another username. Progress is never summed across accounts.';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInBody => 'Use your bound username and password.';

  @override
  String get guestBindHelper => 'Guest — bind to unlock Ranked and Boards';

  @override
  String get boundLabel => 'Bound';

  @override
  String get errorBind =>
      'Could not bind. Check username and password, then tap Retry.';

  @override
  String get logOut => 'Log out';

  @override
  String get logOutTitle => 'Log out?';

  @override
  String get logOutBody =>
      'You will return to guest play on this device. Bound progress stays on the server.';

  @override
  String get replaceGuestTitle => 'Replace guest progress?';

  @override
  String get replaceGuestBody =>
      'Signing in keeps the bound account as-is. Guest progress on this device will be dropped.';

  @override
  String get signInAnyway => 'Sign in anyway';

  @override
  String get errorSignIn =>
      'Could not sign in. Check username and password, then tap Retry.';

  @override
  String get ranked => 'Ranked';

  @override
  String get boards => 'Boards';

  @override
  String get rankedLockTitle => 'Ranked needs an account';

  @override
  String get rankedLockBody =>
      'Bind a username to play Ranked. Casual, bots, and private rooms stay open.';

  @override
  String get boardsLockTitle => 'Boards need an account';

  @override
  String get boardsLockBody =>
      'Bind a username to view skill boards. Guests are not ranked.';

  @override
  String get rankedSearchingBody => 'Looking for a Ranked opponent';

  @override
  String get findRankedMatch => 'Find Ranked match';

  @override
  String get boardsTitle => 'Boards';

  @override
  String get boardsSeason => 'Season';

  @override
  String get boardsAllTime => 'All-time';

  @override
  String get boardsRank => 'Rank';

  @override
  String get boardsPlayer => 'Player';

  @override
  String get boardsEmptyTitle => 'No ranked players yet';

  @override
  String get boardsEmptyBody => 'Play a Ranked match to appear here.';

  @override
  String get errorBoards => 'Boards did not load. Tap Retry.';
}
