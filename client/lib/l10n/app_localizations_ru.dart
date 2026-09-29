// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get playAlchiki => 'Играть в Альчики';

  @override
  String get playStickPull => 'Играть в Перетягивание';

  @override
  String get createStickPullRoom => 'Создать комнату палки';

  @override
  String get holdThrow => 'Держать бросок';

  @override
  String get skip => 'Пропустить';

  @override
  String get next => 'Далее';

  @override
  String get backToMatch => 'К матчу';

  @override
  String get pause => 'Пауза';

  @override
  String get resume => 'Продолжить';

  @override
  String get howToPlay => 'Как играть';

  @override
  String get leaveMatch => 'Покинуть матч';

  @override
  String get stay => 'Остаться';

  @override
  String get backToCatalog => 'В каталог';

  @override
  String get retry => 'Повторить';

  @override
  String get appTitle => 'Nomad Games';

  @override
  String get langEn => 'EN';

  @override
  String get langRu => 'RU';

  @override
  String get alchikiTitle => 'Альчики';

  @override
  String get stickPullTitle => 'Перетягивание палки';

  @override
  String get moreGamesTitle => 'Ещё игры';

  @override
  String get comingSoon => 'Скоро';

  @override
  String get diffEasy => 'Легко';

  @override
  String get diffNormal => 'Норма';

  @override
  String get diffHard => 'Сложно';

  @override
  String get howtoCircleTitle => 'Круг';

  @override
  String get howtoCircleBody =>
      'Выбей светлые кости своим ярким сакой полностью за зелёный круг.';

  @override
  String get howtoAimTitle => 'Прицел';

  @override
  String get howtoAimBody =>
      'Веди пальцем вокруг саки, чтобы повернуть стрелку. Длина стрелки не меняется.';

  @override
  String get howtoHoldTitle => 'Удерживай бросок';

  @override
  String get howtoHoldBody =>
      'Зажми «Держать бросок», чтобы набрать силу, затем отпусти. Чем дольше держишь — тем сильнее бросок.';

  @override
  String get howtoScoreTitle => 'За кругом — одно очко';

  @override
  String get howtoScoreBody =>
      'Когда кости остановились, каждая цель полностью за кругом даёт 1 и уходит со стола. Если сака вышла — 0, и она вернётся.';

  @override
  String get howtoWinTitle => 'Очисти круг';

  @override
  String get howtoWinBody =>
      'Выбей все сохи за круг. Когда круг пуст или кончилось время — побеждает больший счёт.';

  @override
  String get howtoStickSitTitle => 'Напротив';

  @override
  String get howtoStickSitBody => 'Сядьте напротив. У вас одна общая палка.';

  @override
  String get howtoStickGoTitle => 'Жди GO';

  @override
  String get howtoStickGoBody => 'Жди 3-2-1-GO. Нажатия до GO не тянут.';

  @override
  String get howtoStickTapTitle => 'Ритм';

  @override
  String get howtoStickTapBody =>
      'Жми зону палки ровным ритмом, чтобы тянуть маркер к себе.';

  @override
  String get howtoStickStaminaTitle => 'Выносливость';

  @override
  String get howtoStickStaminaBody =>
      'Не долби без паузы. Без выносливости тяга слабеет, и маркер ускользает.';

  @override
  String get howtoStickWinTitle => 'Перетяни';

  @override
  String get howtoStickWinBody =>
      'Перетяни маркер за свою черту — или веди, когда часы дойдут до 0.';

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
    return '$ssс';
  }

  @override
  String get falseStartToast => 'Рано — жди GO';

  @override
  String get stickTapHint => 'Жми';

  @override
  String get stickWaitGo => 'Жди GO';

  @override
  String get stickPullNow => 'Тяни!';

  @override
  String get stickSettlingResult => 'Ожидайте… подсчитываем результат';

  @override
  String apiLatencyMs(int ms) => 'Бэк $ms мс';

  @override
  String get errorStickPullStart =>
      'Не удалось начать Перетягивание. Нажми «Повторить».';

  @override
  String get you => 'Ты';

  @override
  String get bot => 'Бот';

  @override
  String get firstToFive => 'Очисти круг';

  @override
  String get yourTurn => 'Твой ход';

  @override
  String get botsTurn => 'Ход бота';

  @override
  String previewHud(int n) {
    return 'оценка $n';
  }

  @override
  String scoredHud(int n) {
    return 'счёт $n';
  }

  @override
  String get scoredDash => 'счёт —';

  @override
  String get sakaOutLine => 'сака за кругом · 0';

  @override
  String get plusOne => '+1';

  @override
  String turnClock(String ss) {
    return 'ход $ss';
  }

  @override
  String matchClock(int m, String ss) {
    return 'матч $m:$ss';
  }

  @override
  String get turnTimeout => 'Время вышло. Этот бросок даёт 0.';

  @override
  String get emptyCatalogTitle => 'Игр пока нет';

  @override
  String get emptyCatalogBody => 'Каталог не показал столы. Нажми «Повторить».';

  @override
  String get errorGuestMint =>
      'Не удалось войти как гость. Проверь связь и нажми «Повторить».';

  @override
  String get errorCatalog => 'Каталог не загрузился. Нажми «Повторить».';

  @override
  String get errorMatchStart =>
      'Матч не начался. Нажми «Повторить» или вернись в каталог.';

  @override
  String get errorThrow =>
      'Бросок не засчитан. Нажми «Повторить», чтобы отправить снова.';

  @override
  String get youWin => 'Победа';

  @override
  String get botWins => 'Поражение';

  @override
  String get draw => 'Ничья';

  @override
  String get leaveTitle => 'Покинуть матч?';

  @override
  String get leaveBody =>
      'Ты вернёшься в каталог. Эта партия с ботом закончится.';

  @override
  String get createRoom => 'Создать комнату';

  @override
  String get joinByCode => 'Войти по коду';

  @override
  String get joinRoom => 'Войти в комнату';

  @override
  String get ready => 'Готов';

  @override
  String get shareCode => 'Поделиться кодом';

  @override
  String get copyCode => 'Копировать код';

  @override
  String get copied => 'Скопировано';

  @override
  String get leaveLobby => 'Покинуть комнату';

  @override
  String get playAgain => 'Играть снова';

  @override
  String get rematchAgain => 'Ещё раз?';

  @override
  String get rejoinMatch => 'Вернуться в матч';

  @override
  String shareSheetText(String code) {
    return 'Код Nomad Альчики: $code';
  }

  @override
  String get privateRoomTitle => 'Комната';

  @override
  String get roomCodeLabel => 'Код комнаты';

  @override
  String guestLabel(String xxxx) {
    return 'Guest-$xxxx';
  }

  @override
  String get waitingForFriend => 'Ждём друга';

  @override
  String waitingForName(String name) {
    return 'Ждём $name';
  }

  @override
  String get youAreReady => 'Ты готов';

  @override
  String theyAreReady(String name) {
    return '$name готов';
  }

  @override
  String get startingMatch => 'Начинаем…';

  @override
  String get loadingLobby => 'Загрузка…';

  @override
  String get loadingCatalog => 'Загрузка каталога…';

  @override
  String get checkingApi => 'Проверка связи…';

  @override
  String get opponent => 'Соперник';

  @override
  String get opponentsTurn => 'Ход соперника';

  @override
  String get opponentWins => 'Соперник победил';

  @override
  String reconnecting(String ss) {
    return 'Переподключение… $ss';
  }

  @override
  String opponentReconnecting(String ss) {
    return 'Соперник переподключается… $ss';
  }

  @override
  String get opponentDisconnected => 'Соперник отключился';

  @override
  String staminaA11y(int n) {
    return 'Выносливость $n процентов';
  }

  @override
  String rematchClock(String ss) {
    return 'ещё $ss';
  }

  @override
  String get emptyLobbyBody => 'Ждём друга. Поделись кодом или скопируй его.';

  @override
  String get emptyJoinBody => 'Введи код из 4–6 символов.';

  @override
  String get errorNoSuchRoom =>
      'Нет такой комнаты. Проверь код и попробуй снова.';

  @override
  String get errorAlreadyStarted => 'Комната уже играет. Введи другой код.';

  @override
  String get errorHostLeft => 'Хост вышел. Код больше не действует.';

  @override
  String get hostLeftTitle => 'Хост вышел';

  @override
  String get hostLeftBody => 'Комната закрыта. Нажми «В каталог».';

  @override
  String get roomClosedTitle => 'Комната закрыта';

  @override
  String get roomClosedBody =>
      'Никто не нажал «Готов» вовремя. Нажми «В каталог».';

  @override
  String get errorRoomCreate => 'Комната не создалась. Нажми «Повторить».';

  @override
  String get errorReady => 'Готовность не отправилась. Нажми «Повторить».';

  @override
  String get errorRematch =>
      'Не удалось начать ещё одну партию. Нажми «Повторить» или вернись в каталог.';

  @override
  String get errorRejoin =>
      'Не удалось вернуться. Нажми «Вернуться в матч» или дождись таймера.';

  @override
  String get leaveBodyPrivate => 'Ты вернёшься в каталог. Соперник победит.';

  @override
  String get leaveRankedBody => 'Покинуть матч? Это рейтинговое поражение.';

  @override
  String get pauseBudgetGone =>
      'Переподключений не осталось — отключение = поражение';

  @override
  String get leaveLobbyTitle => 'Покинуть комнату?';

  @override
  String get leaveLobbyBodyHost => 'Код сразу перестанет работать.';

  @override
  String get shop => 'Магазин';

  @override
  String get owned => 'Моё';

  @override
  String get buyItem => 'Купить';

  @override
  String get equipItem => 'Надеть';

  @override
  String get equipped => 'Надето';

  @override
  String get backToShop => 'В магазин';

  @override
  String get coins => 'МОНЕТЫ';

  @override
  String get gems => 'САМОЦВЕТЫ';

  @override
  String walletA11y(int coins, int gems) {
    return '$coins МОНЕТЫ, $gems САМОЦВЕТЫ';
  }

  @override
  String walletHint(int coins, int gems) {
    return 'Золотой · монеты (мягкая валюта): $coins\nСиний · самоцветы (премиум): $gems\nПотратить можно в Магазине.';
  }

  @override
  String rewardCoins(int n) {
    return '+$n МОНЕТЫ';
  }

  @override
  String rewardGems(int m) {
    return '+$m САМОЦВЕТЫ';
  }

  @override
  String priceCoins(int n) {
    return '$n МОНЕТЫ';
  }

  @override
  String priceGems(int m) {
    return '$m САМОЦВЕТЫ';
  }

  @override
  String get priceFree => 'Бесплатно';

  @override
  String get shopTitle => 'Магазин';

  @override
  String get catSakaColor => 'Цвет саки';

  @override
  String get catSakaMaterial => 'Материал саки';

  @override
  String get catSakaOrnament => 'Орнамент саки';

  @override
  String get catTrail => 'След';

  @override
  String get catTableFx => 'Эффекты стола';

  @override
  String get catVictory => 'Победа';

  @override
  String get catStickPull => 'Скины палки';

  @override
  String get emptyShopTitle => 'Здесь пока пусто';

  @override
  String get emptyShopBody => 'Магазин не показал товары. Нажми «Повторить».';

  @override
  String get emptyOwnedTitle => 'Пока ничего нет';

  @override
  String get emptyOwnedBody =>
      'Выиграй партии за МОНЕТЫ, затем купи вещь в «Магазин».';

  @override
  String get errorWallet => 'Баланс не загрузился. Нажми «Повторить».';

  @override
  String get errorShop => 'Магазин не загрузился. Нажми «Повторить».';

  @override
  String get errorPurchase => 'Покупка не завершилась. Нажми «Повторить».';

  @override
  String get errorInsufficientFunds =>
      'Не хватает МОНЕТ или САМОЦВЕТОВ. Сыграй партию, чтобы заработать.';

  @override
  String get errorEquip => 'Не удалось надеть. Нажми «Повторить».';

  @override
  String get alreadyOwned => 'Уже куплено';

  @override
  String get skuSakaColorDefault => 'Цвет по умолчанию';

  @override
  String get skuSakaColorGold => 'Золотой цвет';

  @override
  String get skuSakaColorNeon => 'Неоновый цвет';

  @override
  String get skuSakaMaterialDefault => 'Материал по умолчанию';

  @override
  String get skuSakaMaterialIce => 'Ледяной материал';

  @override
  String get skuSakaMaterialFire => 'Огненный материал';

  @override
  String get skuSakaOrnamentDefault => 'Орнамент по умолчанию';

  @override
  String get skuSakaOrnamentSpace => 'Космический орнамент';

  @override
  String get skuSakaOrnamentKnot => 'Узор-узел';

  @override
  String get skuTrailDefault => 'След по умолчанию';

  @override
  String get skuTrailGold => 'Золотой след';

  @override
  String get skuTableFxDefault => 'Эффект стола по умолчанию';

  @override
  String get skuTableFxNeon => 'Неоновый эффект стола';

  @override
  String get skuVictoryDefault => 'Победа по умолчанию';

  @override
  String get skuVictoryFire => 'Огненная победа';

  @override
  String get skuStickPullDefault => 'Палка по умолчанию';

  @override
  String get skuStickPullIce => 'Ледяная палка';

  @override
  String get quickMatch => 'Быстрая игра';

  @override
  String get cancelSearch => 'Отменить поиск';

  @override
  String get searchingTitle => 'Ищем…';

  @override
  String get searchingBody => 'Ищем соперника';

  @override
  String get errorQuickMatch => 'Быстрая игра не началась. Нажми «Повторить».';

  @override
  String get fallbackTitle => 'Пока нет соперника';

  @override
  String get fallbackBody => 'Сыграй с ботом или пригласи друга';

  @override
  String get playVsBot => 'Играть с ботом';

  @override
  String get inviteFriend => 'Пригласить друга';

  @override
  String get errorQueueLeft =>
      'Очередь покинута. Нажми «Повторить» или вернись в каталог.';

  @override
  String get rematchWaitingTitle => 'Ждём реванш';

  @override
  String get cancelRematch => 'Отменить реванш';

  @override
  String get openProfileA11y => 'Открыть профиль';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get guestDisplay => 'Guest';

  @override
  String get saveAvatar => 'Сохранить аватар';

  @override
  String levelLabel(int n) {
    return 'Уровень $n';
  }

  @override
  String xpProgress(int current, int next) {
    return '$current / $next опыта';
  }

  @override
  String get statMatches => 'Партии';

  @override
  String get statWins => 'Победы';

  @override
  String get statLosses => 'Поражения';

  @override
  String get statWinRate => 'Винрейт';

  @override
  String statWinRateValue(int n) {
    return '$n%';
  }

  @override
  String get statRating => 'Рейтинг';

  @override
  String get statBestRating => 'Лучший';

  @override
  String get cosmeticsSection => 'Выбранные косметики';

  @override
  String get cosmeticsDefault => 'Стандартный набор';

  @override
  String get avatarSection => 'Аватар';

  @override
  String get avatarCustomA11y => 'Добавить фото из галереи';

  @override
  String get errorAvatarPick =>
      'Не удалось открыть галерею. Проверь доступ и попробуй снова.';

  @override
  String get statsAlchiki => 'Альчики';

  @override
  String get statsStickPull => 'Тяни палку';

  @override
  String get noMatchesYet => 'Пока нет партий';

  @override
  String get errorProfileTitle => 'Профиль не загрузился';

  @override
  String get errorProfileBody =>
      'Нажми «Повторить», чтобы загрузить статистику.';

  @override
  String get errorAvatarSave => 'Аватар не сохранился. Нажми «Повторить».';

  @override
  String get bindNow => 'Привязать аккаунт';

  @override
  String get notNow => 'Не сейчас';

  @override
  String get bindAccount => 'Привязать аккаунт';

  @override
  String get signIn => 'Войти';

  @override
  String get signInInstead => 'Войти вместо этого';

  @override
  String get bindThisGuest => 'Привязать этого гостя';

  @override
  String get bindSheetTitle => 'Сохрани прогресс';

  @override
  String get bindSheetBody =>
      'Привяжи имя и пароль, чтобы сохранить косметику, кошельки и статистику на этом аккаунте.';

  @override
  String get usernameLabel => 'Имя';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get passwordRule => 'Не меньше 8 символов';

  @override
  String get usernameTakenTitle => 'Имя занято';

  @override
  String get usernameTakenBody =>
      'Войди в тот аккаунт или выбери другое имя. Прогресс аккаунтов никогда не суммируется.';

  @override
  String get signInTitle => 'Войти';

  @override
  String get signInBody => 'Введи привязанные имя и пароль.';

  @override
  String get guestBindHelper =>
      'Гость — привяжи аккаунт для Рейтинга и Таблицы';

  @override
  String get boundLabel => 'Привязан';

  @override
  String get errorBind =>
      'Не удалось привязать. Проверь имя и пароль, затем нажми «Повторить».';

  @override
  String get logOut => 'Выйти';

  @override
  String get logOutTitle => 'Выйти?';

  @override
  String get logOutBody =>
      'Вернёшься к гостевой игре на этом устройстве. Привязанный прогресс останется на сервере.';

  @override
  String get replaceGuestTitle => 'Заменить гостевой прогресс?';

  @override
  String get replaceGuestBody =>
      'Вход сохраняет привязанный аккаунт как есть. Гостевой прогресс на этом устройстве будет удалён.';

  @override
  String get signInAnyway => 'Всё равно войти';

  @override
  String get errorSignIn =>
      'Не удалось войти. Проверь имя и пароль, затем нажми «Повторить».';

  @override
  String get ranked => 'Рейтинг';

  @override
  String get boards => 'Таблица';

  @override
  String get rankedLockTitle => 'Для рейтинга нужен аккаунт';

  @override
  String get rankedLockBody =>
      'Привяжи имя, чтобы играть рейтинг. Казуал, боты и комнаты остаются открытыми.';

  @override
  String get boardsLockTitle => 'Для таблицы нужен аккаунт';

  @override
  String get boardsLockBody =>
      'Привяжи имя, чтобы смотреть таблицу. Гости не попадают в рейтинг.';

  @override
  String get rankedSearchingBody => 'Ищем рейтингового соперника';

  @override
  String get findRankedMatch => 'Искать рейтинговый матч';

  @override
  String get boardsTitle => 'Таблица';

  @override
  String get boardsSeason => 'Сезон';

  @override
  String get boardsAllTime => 'За всё время';

  @override
  String get boardsRank => 'Место';

  @override
  String get boardsPlayer => 'Игрок';

  @override
  String get boardsEmptyTitle => 'Пока нет игроков рейтинга';

  @override
  String get boardsEmptyBody =>
      'Сыграй рейтинговый матч, чтобы появиться здесь.';

  @override
  String get errorBoards => 'Таблица не загрузилась. Нажми «Повторить».';
}
