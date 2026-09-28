import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @playAlchiki.
  ///
  /// In en, this message translates to:
  /// **'Play Alchiki'**
  String get playAlchiki;

  /// No description provided for @playStickPull.
  ///
  /// In en, this message translates to:
  /// **'Play Stick Pull'**
  String get playStickPull;

  /// No description provided for @createStickPullRoom.
  ///
  /// In en, this message translates to:
  /// **'Create Stick Pull room'**
  String get createStickPullRoom;

  /// No description provided for @holdThrow.
  ///
  /// In en, this message translates to:
  /// **'Hold Throw'**
  String get holdThrow;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @backToMatch.
  ///
  /// In en, this message translates to:
  /// **'Back to match'**
  String get backToMatch;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @howToPlay.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get howToPlay;

  /// No description provided for @leaveMatch.
  ///
  /// In en, this message translates to:
  /// **'Leave match'**
  String get leaveMatch;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @backToCatalog.
  ///
  /// In en, this message translates to:
  /// **'Back to catalog'**
  String get backToCatalog;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Nomad Games'**
  String get appTitle;

  /// No description provided for @langEn.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get langEn;

  /// No description provided for @langRu.
  ///
  /// In en, this message translates to:
  /// **'RU'**
  String get langRu;

  /// No description provided for @alchikiTitle.
  ///
  /// In en, this message translates to:
  /// **'Alchiki'**
  String get alchikiTitle;

  /// No description provided for @stickPullTitle.
  ///
  /// In en, this message translates to:
  /// **'Stick Pull'**
  String get stickPullTitle;

  /// No description provided for @moreGamesTitle.
  ///
  /// In en, this message translates to:
  /// **'More games'**
  String get moreGamesTitle;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @diffEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get diffEasy;

  /// No description provided for @diffNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get diffNormal;

  /// No description provided for @diffHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get diffHard;

  /// No description provided for @howtoCircleTitle.
  ///
  /// In en, this message translates to:
  /// **'The circle'**
  String get howtoCircleTitle;

  /// No description provided for @howtoCircleBody.
  ///
  /// In en, this message translates to:
  /// **'Knock the tan bones fully outside the green circle with your bright saka.'**
  String get howtoCircleBody;

  /// No description provided for @howtoAimTitle.
  ///
  /// In en, this message translates to:
  /// **'Aim'**
  String get howtoAimTitle;

  /// No description provided for @howtoAimBody.
  ///
  /// In en, this message translates to:
  /// **'Drag around the saka to rotate the arrow. The arrow length does not change.'**
  String get howtoAimBody;

  /// No description provided for @howtoHoldTitle.
  ///
  /// In en, this message translates to:
  /// **'Hold to throw'**
  String get howtoHoldTitle;

  /// No description provided for @howtoHoldBody.
  ///
  /// In en, this message translates to:
  /// **'Press Hold Throw to charge power, then release. A longer hold is a stronger throw.'**
  String get howtoHoldBody;

  /// No description provided for @howtoScoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Out is one point'**
  String get howtoScoreTitle;

  /// No description provided for @howtoScoreBody.
  ///
  /// In en, this message translates to:
  /// **'After the bones stop, each target fully outside the circle scores 1 and leaves the table. If the saka leaves, you score 0 and it comes back.'**
  String get howtoScoreBody;

  /// No description provided for @howtoWinTitle.
  ///
  /// In en, this message translates to:
  /// **'First to 5'**
  String get howtoWinTitle;

  /// No description provided for @howtoWinBody.
  ///
  /// In en, this message translates to:
  /// **'Reach 5 points to win. If time or turns run out, the higher score wins.'**
  String get howtoWinBody;

  /// No description provided for @howtoStickSitTitle.
  ///
  /// In en, this message translates to:
  /// **'Sit opposite'**
  String get howtoStickSitTitle;

  /// No description provided for @howtoStickSitBody.
  ///
  /// In en, this message translates to:
  /// **'Sit across from your opponent. You share one stick.'**
  String get howtoStickSitBody;

  /// No description provided for @howtoStickGoTitle.
  ///
  /// In en, this message translates to:
  /// **'Wait for GO'**
  String get howtoStickGoTitle;

  /// No description provided for @howtoStickGoBody.
  ///
  /// In en, this message translates to:
  /// **'Wait for 3-2-1-GO. Taps before GO do not pull.'**
  String get howtoStickGoBody;

  /// No description provided for @howtoStickTapTitle.
  ///
  /// In en, this message translates to:
  /// **'Tap in rhythm'**
  String get howtoStickTapTitle;

  /// No description provided for @howtoStickTapBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the stick zone in a steady rhythm to pull the marker your way.'**
  String get howtoStickTapBody;

  /// No description provided for @howtoStickStaminaTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch stamina'**
  String get howtoStickStaminaTitle;

  /// No description provided for @howtoStickStaminaBody.
  ///
  /// In en, this message translates to:
  /// **'Do not mash. When stamina empties, your pull weakens and the marker slips.'**
  String get howtoStickStaminaBody;

  /// No description provided for @howtoStickWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull it over'**
  String get howtoStickWinTitle;

  /// No description provided for @howtoStickWinBody.
  ///
  /// In en, this message translates to:
  /// **'Pull the marker past the line on your side — or lead when the clock hits 0.'**
  String get howtoStickWinBody;

  /// No description provided for @countdown3.
  ///
  /// In en, this message translates to:
  /// **'3'**
  String get countdown3;

  /// No description provided for @countdown2.
  ///
  /// In en, this message translates to:
  /// **'2'**
  String get countdown2;

  /// No description provided for @countdown1.
  ///
  /// In en, this message translates to:
  /// **'1'**
  String get countdown1;

  /// No description provided for @countdownGo.
  ///
  /// In en, this message translates to:
  /// **'GO'**
  String get countdownGo;

  /// No description provided for @stickClock.
  ///
  /// In en, this message translates to:
  /// **'{ss}s'**
  String stickClock(String ss);

  /// No description provided for @falseStartToast.
  ///
  /// In en, this message translates to:
  /// **'Too early — wait for GO'**
  String get falseStartToast;

  /// No description provided for @stickTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap'**
  String get stickTapHint;

  /// No description provided for @errorStickPullStart.
  ///
  /// In en, this message translates to:
  /// **'Stick Pull did not start. Tap Retry.'**
  String get errorStickPullStart;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @bot.
  ///
  /// In en, this message translates to:
  /// **'Bot'**
  String get bot;

  /// No description provided for @firstToFive.
  ///
  /// In en, this message translates to:
  /// **'First to 5'**
  String get firstToFive;

  /// No description provided for @yourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your turn'**
  String get yourTurn;

  /// No description provided for @botsTurn.
  ///
  /// In en, this message translates to:
  /// **'Bot\'s turn'**
  String get botsTurn;

  /// No description provided for @previewHud.
  ///
  /// In en, this message translates to:
  /// **'preview {n}'**
  String previewHud(int n);

  /// No description provided for @scoredHud.
  ///
  /// In en, this message translates to:
  /// **'scored {n}'**
  String scoredHud(int n);

  /// No description provided for @scoredDash.
  ///
  /// In en, this message translates to:
  /// **'scored —'**
  String get scoredDash;

  /// No description provided for @sakaOutLine.
  ///
  /// In en, this message translates to:
  /// **'saka out · 0'**
  String get sakaOutLine;

  /// No description provided for @plusOne.
  ///
  /// In en, this message translates to:
  /// **'+1'**
  String get plusOne;

  /// No description provided for @turnClock.
  ///
  /// In en, this message translates to:
  /// **'turn {ss}'**
  String turnClock(String ss);

  /// No description provided for @matchClock.
  ///
  /// In en, this message translates to:
  /// **'match {m}:{ss}'**
  String matchClock(int m, String ss);

  /// No description provided for @turnTimeout.
  ///
  /// In en, this message translates to:
  /// **'Time is up. This throw scores 0.'**
  String get turnTimeout;

  /// No description provided for @emptyCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'No games yet'**
  String get emptyCatalogTitle;

  /// No description provided for @emptyCatalogBody.
  ///
  /// In en, this message translates to:
  /// **'Catalog did not list any tables. Tap Retry.'**
  String get emptyCatalogBody;

  /// No description provided for @errorGuestMint.
  ///
  /// In en, this message translates to:
  /// **'Can\'t start as guest. Check the connection, then tap Retry.'**
  String get errorGuestMint;

  /// No description provided for @errorCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog did not load. Tap Retry.'**
  String get errorCatalog;

  /// No description provided for @errorMatchStart.
  ///
  /// In en, this message translates to:
  /// **'Match did not start. Tap Retry or return to the catalog.'**
  String get errorMatchStart;

  /// No description provided for @errorThrow.
  ///
  /// In en, this message translates to:
  /// **'Throw was not scored. Tap Retry to send it again.'**
  String get errorThrow;

  /// No description provided for @youWin.
  ///
  /// In en, this message translates to:
  /// **'You win'**
  String get youWin;

  /// No description provided for @botWins.
  ///
  /// In en, this message translates to:
  /// **'Bot wins'**
  String get botWins;

  /// No description provided for @draw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get draw;

  /// No description provided for @leaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this match?'**
  String get leaveTitle;

  /// No description provided for @leaveBody.
  ///
  /// In en, this message translates to:
  /// **'You will return to the catalog. This bot match will end.'**
  String get leaveBody;

  /// No description provided for @createRoom.
  ///
  /// In en, this message translates to:
  /// **'Create room'**
  String get createRoom;

  /// No description provided for @joinByCode.
  ///
  /// In en, this message translates to:
  /// **'Join by code'**
  String get joinByCode;

  /// No description provided for @joinRoom.
  ///
  /// In en, this message translates to:
  /// **'Join room'**
  String get joinRoom;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @shareCode.
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get shareCode;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @leaveLobby.
  ///
  /// In en, this message translates to:
  /// **'Leave lobby'**
  String get leaveLobby;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get playAgain;

  /// No description provided for @rematchAgain.
  ///
  /// In en, this message translates to:
  /// **'Again?'**
  String get rematchAgain;

  /// No description provided for @rejoinMatch.
  ///
  /// In en, this message translates to:
  /// **'Rejoin match'**
  String get rejoinMatch;

  /// No description provided for @shareSheetText.
  ///
  /// In en, this message translates to:
  /// **'Nomad Alchiki code: {code}'**
  String shareSheetText(String code);

  /// No description provided for @privateRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Private room'**
  String get privateRoomTitle;

  /// No description provided for @roomCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Room code'**
  String get roomCodeLabel;

  /// No description provided for @guestLabel.
  ///
  /// In en, this message translates to:
  /// **'Guest-{xxxx}'**
  String guestLabel(String xxxx);

  /// No description provided for @waitingForFriend.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a friend'**
  String get waitingForFriend;

  /// No description provided for @waitingForName.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name}'**
  String waitingForName(String name);

  /// No description provided for @youAreReady.
  ///
  /// In en, this message translates to:
  /// **'You are ready'**
  String get youAreReady;

  /// No description provided for @theyAreReady.
  ///
  /// In en, this message translates to:
  /// **'{name} is ready'**
  String theyAreReady(String name);

  /// No description provided for @startingMatch.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get startingMatch;

  /// No description provided for @loadingLobby.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingLobby;

  /// No description provided for @opponent.
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get opponent;

  /// No description provided for @opponentsTurn.
  ///
  /// In en, this message translates to:
  /// **'Opponent\'s turn'**
  String get opponentsTurn;

  /// No description provided for @opponentWins.
  ///
  /// In en, this message translates to:
  /// **'Opponent wins'**
  String get opponentWins;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting… {ss}'**
  String reconnecting(String ss);

  /// No description provided for @opponentReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Opponent reconnecting… {ss}'**
  String opponentReconnecting(String ss);

  /// No description provided for @opponentDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Opponent disconnected'**
  String get opponentDisconnected;

  /// No description provided for @staminaA11y.
  ///
  /// In en, this message translates to:
  /// **'Stamina {n} percent'**
  String staminaA11y(int n);

  /// No description provided for @rematchClock.
  ///
  /// In en, this message translates to:
  /// **'again {ss}'**
  String rematchClock(String ss);

  /// No description provided for @emptyLobbyBody.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a friend. Share or copy the code.'**
  String get emptyLobbyBody;

  /// No description provided for @emptyJoinBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4–6 character code.'**
  String get emptyJoinBody;

  /// No description provided for @errorNoSuchRoom.
  ///
  /// In en, this message translates to:
  /// **'No such room. Check the code and try again.'**
  String get errorNoSuchRoom;

  /// No description provided for @errorAlreadyStarted.
  ///
  /// In en, this message translates to:
  /// **'That room already started. Enter another code.'**
  String get errorAlreadyStarted;

  /// No description provided for @errorHostLeft.
  ///
  /// In en, this message translates to:
  /// **'Host left. That code no longer works.'**
  String get errorHostLeft;

  /// No description provided for @hostLeftTitle.
  ///
  /// In en, this message translates to:
  /// **'Host left'**
  String get hostLeftTitle;

  /// No description provided for @hostLeftBody.
  ///
  /// In en, this message translates to:
  /// **'The room closed. Tap Back to catalog.'**
  String get hostLeftBody;

  /// No description provided for @roomClosedTitle.
  ///
  /// In en, this message translates to:
  /// **'Room closed'**
  String get roomClosedTitle;

  /// No description provided for @roomClosedBody.
  ///
  /// In en, this message translates to:
  /// **'Nobody was ready in time. Tap Back to catalog.'**
  String get roomClosedBody;

  /// No description provided for @errorRoomCreate.
  ///
  /// In en, this message translates to:
  /// **'Room did not create. Tap Retry.'**
  String get errorRoomCreate;

  /// No description provided for @errorReady.
  ///
  /// In en, this message translates to:
  /// **'Ready did not send. Tap Retry.'**
  String get errorReady;

  /// No description provided for @errorRematch.
  ///
  /// In en, this message translates to:
  /// **'Rematch did not start. Tap Retry or return to the catalog.'**
  String get errorRematch;

  /// No description provided for @errorRejoin.
  ///
  /// In en, this message translates to:
  /// **'Could not rejoin. Tap Rejoin match or wait for the timer.'**
  String get errorRejoin;

  /// No description provided for @leaveBodyPrivate.
  ///
  /// In en, this message translates to:
  /// **'You will return to the catalog. Your opponent will win.'**
  String get leaveBodyPrivate;

  /// No description provided for @leaveRankedBody.
  ///
  /// In en, this message translates to:
  /// **'Leave this match? It counts as a rated loss.'**
  String get leaveRankedBody;

  /// No description provided for @pauseBudgetGone.
  ///
  /// In en, this message translates to:
  /// **'No reconnect left — forfeit if you drop'**
  String get pauseBudgetGone;

  /// No description provided for @leaveLobbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this room?'**
  String get leaveLobbyTitle;

  /// No description provided for @leaveLobbyBodyHost.
  ///
  /// In en, this message translates to:
  /// **'The join code will stop working.'**
  String get leaveLobbyBodyHost;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get owned;

  /// No description provided for @buyItem.
  ///
  /// In en, this message translates to:
  /// **'Buy item'**
  String get buyItem;

  /// No description provided for @equipItem.
  ///
  /// In en, this message translates to:
  /// **'Equip item'**
  String get equipItem;

  /// No description provided for @equipped.
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get equipped;

  /// No description provided for @backToShop.
  ///
  /// In en, this message translates to:
  /// **'Back to shop'**
  String get backToShop;

  /// No description provided for @coins.
  ///
  /// In en, this message translates to:
  /// **'COINS'**
  String get coins;

  /// No description provided for @gems.
  ///
  /// In en, this message translates to:
  /// **'GEMS'**
  String get gems;

  /// No description provided for @walletA11y.
  ///
  /// In en, this message translates to:
  /// **'{coins} COINS, {gems} GEMS'**
  String walletA11y(int coins, int gems);

  /// No description provided for @walletHint.
  ///
  /// In en, this message translates to:
  /// **'Gold · coins (soft currency): {coins}\nBlue · gems (premium): {gems}\nTap Shop to spend them.'**
  String walletHint(int coins, int gems);

  /// No description provided for @rewardCoins.
  ///
  /// In en, this message translates to:
  /// **'+{n} COINS'**
  String rewardCoins(int n);

  /// No description provided for @rewardGems.
  ///
  /// In en, this message translates to:
  /// **'+{m} GEMS'**
  String rewardGems(int m);

  /// No description provided for @priceCoins.
  ///
  /// In en, this message translates to:
  /// **'{n} COINS'**
  String priceCoins(int n);

  /// No description provided for @priceGems.
  ///
  /// In en, this message translates to:
  /// **'{m} GEMS'**
  String priceGems(int m);

  /// No description provided for @priceFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get priceFree;

  /// No description provided for @shopTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shopTitle;

  /// No description provided for @catSakaColor.
  ///
  /// In en, this message translates to:
  /// **'Saka color'**
  String get catSakaColor;

  /// No description provided for @catSakaMaterial.
  ///
  /// In en, this message translates to:
  /// **'Saka material'**
  String get catSakaMaterial;

  /// No description provided for @catSakaOrnament.
  ///
  /// In en, this message translates to:
  /// **'Saka ornament'**
  String get catSakaOrnament;

  /// No description provided for @catTrail.
  ///
  /// In en, this message translates to:
  /// **'Trail'**
  String get catTrail;

  /// No description provided for @catTableFx.
  ///
  /// In en, this message translates to:
  /// **'Table effects'**
  String get catTableFx;

  /// No description provided for @catVictory.
  ///
  /// In en, this message translates to:
  /// **'Victory animation'**
  String get catVictory;

  /// No description provided for @catStickPull.
  ///
  /// In en, this message translates to:
  /// **'Stick Pull skins'**
  String get catStickPull;

  /// No description provided for @emptyShopTitle.
  ///
  /// In en, this message translates to:
  /// **'No items here'**
  String get emptyShopTitle;

  /// No description provided for @emptyShopBody.
  ///
  /// In en, this message translates to:
  /// **'The shop did not list items. Tap Retry.'**
  String get emptyShopBody;

  /// No description provided for @emptyOwnedTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing owned yet'**
  String get emptyOwnedTitle;

  /// No description provided for @emptyOwnedBody.
  ///
  /// In en, this message translates to:
  /// **'Win matches for COINS, then buy an item in Shop.'**
  String get emptyOwnedBody;

  /// No description provided for @errorWallet.
  ///
  /// In en, this message translates to:
  /// **'Balances did not load. Tap Retry.'**
  String get errorWallet;

  /// No description provided for @errorShop.
  ///
  /// In en, this message translates to:
  /// **'Shop did not load. Tap Retry.'**
  String get errorShop;

  /// No description provided for @errorPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase did not finish. Tap Retry.'**
  String get errorPurchase;

  /// No description provided for @errorInsufficientFunds.
  ///
  /// In en, this message translates to:
  /// **'Not enough COINS or GEMS. Play a match to earn more.'**
  String get errorInsufficientFunds;

  /// No description provided for @errorEquip.
  ///
  /// In en, this message translates to:
  /// **'Equip did not save. Tap Retry.'**
  String get errorEquip;

  /// No description provided for @alreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'You already own this'**
  String get alreadyOwned;

  /// No description provided for @skuSakaColorDefault.
  ///
  /// In en, this message translates to:
  /// **'Default color'**
  String get skuSakaColorDefault;

  /// No description provided for @skuSakaColorGold.
  ///
  /// In en, this message translates to:
  /// **'Gold color'**
  String get skuSakaColorGold;

  /// No description provided for @skuSakaColorNeon.
  ///
  /// In en, this message translates to:
  /// **'Neon color'**
  String get skuSakaColorNeon;

  /// No description provided for @skuSakaMaterialDefault.
  ///
  /// In en, this message translates to:
  /// **'Default material'**
  String get skuSakaMaterialDefault;

  /// No description provided for @skuSakaMaterialIce.
  ///
  /// In en, this message translates to:
  /// **'Ice material'**
  String get skuSakaMaterialIce;

  /// No description provided for @skuSakaMaterialFire.
  ///
  /// In en, this message translates to:
  /// **'Fire material'**
  String get skuSakaMaterialFire;

  /// No description provided for @skuSakaOrnamentDefault.
  ///
  /// In en, this message translates to:
  /// **'Default ornament'**
  String get skuSakaOrnamentDefault;

  /// No description provided for @skuSakaOrnamentSpace.
  ///
  /// In en, this message translates to:
  /// **'Space ornament'**
  String get skuSakaOrnamentSpace;

  /// No description provided for @skuSakaOrnamentKnot.
  ///
  /// In en, this message translates to:
  /// **'Knot ornament'**
  String get skuSakaOrnamentKnot;

  /// No description provided for @skuTrailDefault.
  ///
  /// In en, this message translates to:
  /// **'Default trail'**
  String get skuTrailDefault;

  /// No description provided for @skuTrailGold.
  ///
  /// In en, this message translates to:
  /// **'Gold trail'**
  String get skuTrailGold;

  /// No description provided for @skuTableFxDefault.
  ///
  /// In en, this message translates to:
  /// **'Default table FX'**
  String get skuTableFxDefault;

  /// No description provided for @skuTableFxNeon.
  ///
  /// In en, this message translates to:
  /// **'Neon table FX'**
  String get skuTableFxNeon;

  /// No description provided for @skuVictoryDefault.
  ///
  /// In en, this message translates to:
  /// **'Default victory'**
  String get skuVictoryDefault;

  /// No description provided for @skuVictoryFire.
  ///
  /// In en, this message translates to:
  /// **'Fire victory'**
  String get skuVictoryFire;

  /// No description provided for @skuStickPullDefault.
  ///
  /// In en, this message translates to:
  /// **'Default Stick Pull'**
  String get skuStickPullDefault;

  /// No description provided for @skuStickPullIce.
  ///
  /// In en, this message translates to:
  /// **'Ice Stick Pull'**
  String get skuStickPullIce;

  /// No description provided for @quickMatch.
  ///
  /// In en, this message translates to:
  /// **'Quick Match'**
  String get quickMatch;

  /// No description provided for @cancelSearch.
  ///
  /// In en, this message translates to:
  /// **'Cancel search'**
  String get cancelSearch;

  /// No description provided for @searchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searchingTitle;

  /// No description provided for @searchingBody.
  ///
  /// In en, this message translates to:
  /// **'Looking for an opponent'**
  String get searchingBody;

  /// No description provided for @errorQuickMatch.
  ///
  /// In en, this message translates to:
  /// **'Quick Match did not start. Tap Retry.'**
  String get errorQuickMatch;

  /// No description provided for @fallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'No opponent yet'**
  String get fallbackTitle;

  /// No description provided for @fallbackBody.
  ///
  /// In en, this message translates to:
  /// **'Play a bot or invite a friend'**
  String get fallbackBody;

  /// No description provided for @playVsBot.
  ///
  /// In en, this message translates to:
  /// **'Play vs bot'**
  String get playVsBot;

  /// No description provided for @inviteFriend.
  ///
  /// In en, this message translates to:
  /// **'Invite friend'**
  String get inviteFriend;

  /// No description provided for @errorQueueLeft.
  ///
  /// In en, this message translates to:
  /// **'Left the queue. Tap Retry or return to the catalog.'**
  String get errorQueueLeft;

  /// No description provided for @rematchWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for rematch'**
  String get rematchWaitingTitle;

  /// No description provided for @cancelRematch.
  ///
  /// In en, this message translates to:
  /// **'Cancel rematch'**
  String get cancelRematch;

  /// No description provided for @openProfileA11y.
  ///
  /// In en, this message translates to:
  /// **'Open profile'**
  String get openProfileA11y;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @guestDisplay.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guestDisplay;

  /// No description provided for @saveAvatar.
  ///
  /// In en, this message translates to:
  /// **'Save avatar'**
  String get saveAvatar;

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String levelLabel(int n);

  /// No description provided for @xpProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {next} XP'**
  String xpProgress(int current, int next);

  /// No description provided for @statMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get statMatches;

  /// No description provided for @statWins.
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get statWins;

  /// No description provided for @statLosses.
  ///
  /// In en, this message translates to:
  /// **'Losses'**
  String get statLosses;

  /// No description provided for @statWinRate.
  ///
  /// In en, this message translates to:
  /// **'Win rate'**
  String get statWinRate;

  /// No description provided for @statWinRateValue.
  ///
  /// In en, this message translates to:
  /// **'{n}%'**
  String statWinRateValue(int n);

  /// No description provided for @statRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get statRating;

  /// No description provided for @statBestRating.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get statBestRating;

  /// No description provided for @cosmeticsSection.
  ///
  /// In en, this message translates to:
  /// **'Selected cosmetics'**
  String get cosmeticsSection;

  /// No description provided for @cosmeticsDefault.
  ///
  /// In en, this message translates to:
  /// **'Default loadout'**
  String get cosmeticsDefault;

  /// No description provided for @avatarSection.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get avatarSection;

  /// No description provided for @avatarCustomA11y.
  ///
  /// In en, this message translates to:
  /// **'Add photo from gallery'**
  String get avatarCustomA11y;

  /// No description provided for @errorAvatarPick.
  ///
  /// In en, this message translates to:
  /// **'Could not open the gallery. Check permission and try again.'**
  String get errorAvatarPick;

  /// No description provided for @statsAlchiki.
  ///
  /// In en, this message translates to:
  /// **'Alchiki'**
  String get statsAlchiki;

  /// No description provided for @statsStickPull.
  ///
  /// In en, this message translates to:
  /// **'Stick Pull'**
  String get statsStickPull;

  /// No description provided for @noMatchesYet.
  ///
  /// In en, this message translates to:
  /// **'No matches yet'**
  String get noMatchesYet;

  /// No description provided for @errorProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile did not load'**
  String get errorProfileTitle;

  /// No description provided for @errorProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Tap Retry to load your stats.'**
  String get errorProfileBody;

  /// No description provided for @errorAvatarSave.
  ///
  /// In en, this message translates to:
  /// **'Avatar did not save. Tap Retry.'**
  String get errorAvatarSave;

  /// No description provided for @bindNow.
  ///
  /// In en, this message translates to:
  /// **'Bind now'**
  String get bindNow;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @bindAccount.
  ///
  /// In en, this message translates to:
  /// **'Bind account'**
  String get bindAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInInstead.
  ///
  /// In en, this message translates to:
  /// **'Sign in instead'**
  String get signInInstead;

  /// No description provided for @bindThisGuest.
  ///
  /// In en, this message translates to:
  /// **'Bind this guest'**
  String get bindThisGuest;

  /// No description provided for @bindSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your progress'**
  String get bindSheetTitle;

  /// No description provided for @bindSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Bind a username and password to keep cosmetics, wallets, and stats on this account.'**
  String get bindSheetBody;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordRule.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordRule;

  /// No description provided for @usernameTakenTitle.
  ///
  /// In en, this message translates to:
  /// **'Username taken'**
  String get usernameTakenTitle;

  /// No description provided for @usernameTakenBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to that account, or choose another username. Progress is never summed across accounts.'**
  String get usernameTakenBody;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInBody.
  ///
  /// In en, this message translates to:
  /// **'Use your bound username and password.'**
  String get signInBody;

  /// No description provided for @guestBindHelper.
  ///
  /// In en, this message translates to:
  /// **'Guest — bind to unlock Ranked and Boards'**
  String get guestBindHelper;

  /// No description provided for @boundLabel.
  ///
  /// In en, this message translates to:
  /// **'Bound'**
  String get boundLabel;

  /// No description provided for @errorBind.
  ///
  /// In en, this message translates to:
  /// **'Could not bind. Check username and password, then tap Retry.'**
  String get errorBind;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @logOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logOutTitle;

  /// No description provided for @logOutBody.
  ///
  /// In en, this message translates to:
  /// **'You will return to guest play on this device. Bound progress stays on the server.'**
  String get logOutBody;

  /// No description provided for @replaceGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace guest progress?'**
  String get replaceGuestTitle;

  /// No description provided for @replaceGuestBody.
  ///
  /// In en, this message translates to:
  /// **'Signing in keeps the bound account as-is. Guest progress on this device will be dropped.'**
  String get replaceGuestBody;

  /// No description provided for @signInAnyway.
  ///
  /// In en, this message translates to:
  /// **'Sign in anyway'**
  String get signInAnyway;

  /// No description provided for @errorSignIn.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Check username and password, then tap Retry.'**
  String get errorSignIn;

  /// No description provided for @ranked.
  ///
  /// In en, this message translates to:
  /// **'Ranked'**
  String get ranked;

  /// No description provided for @boards.
  ///
  /// In en, this message translates to:
  /// **'Boards'**
  String get boards;

  /// No description provided for @rankedLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Ranked needs an account'**
  String get rankedLockTitle;

  /// No description provided for @rankedLockBody.
  ///
  /// In en, this message translates to:
  /// **'Bind a username to play Ranked. Casual, bots, and private rooms stay open.'**
  String get rankedLockBody;

  /// No description provided for @boardsLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Boards need an account'**
  String get boardsLockTitle;

  /// No description provided for @boardsLockBody.
  ///
  /// In en, this message translates to:
  /// **'Bind a username to view skill boards. Guests are not ranked.'**
  String get boardsLockBody;

  /// No description provided for @rankedSearchingBody.
  ///
  /// In en, this message translates to:
  /// **'Looking for a Ranked opponent'**
  String get rankedSearchingBody;

  /// No description provided for @findRankedMatch.
  ///
  /// In en, this message translates to:
  /// **'Find Ranked match'**
  String get findRankedMatch;

  /// No description provided for @boardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Boards'**
  String get boardsTitle;

  /// No description provided for @boardsSeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get boardsSeason;

  /// No description provided for @boardsAllTime.
  ///
  /// In en, this message translates to:
  /// **'All-time'**
  String get boardsAllTime;

  /// No description provided for @boardsRank.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get boardsRank;

  /// No description provided for @boardsPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get boardsPlayer;

  /// No description provided for @boardsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No ranked players yet'**
  String get boardsEmptyTitle;

  /// No description provided for @boardsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Play a Ranked match to appear here.'**
  String get boardsEmptyBody;

  /// No description provided for @errorBoards.
  ///
  /// In en, this message translates to:
  /// **'Boards did not load. Tap Retry.'**
  String get errorBoards;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
