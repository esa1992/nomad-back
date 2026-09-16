# Nomad Games

## What This Is

Nomad Games — расширяемая мобильная игровая платформа (Android + iOS) с каталогом традиционных игр кочевых народов. Первый релиз — не один тайтл, а каркас, в который новые игры добавляются отдельными модулями. Главная игра MVP — Альчики; вторая — Перетягивание палки; остальные слоты каталога показывают Coming Soon.

Игрок может зайти гостем и сразу сыграть, позже привязать аккаунт (username/password), играть против бота, с другом по коду комнаты, через matchmaking и в рейтинге, смотреть профиль/статистику/лидерборд и покупать косметику за игровую валюту.

## Core Value

Короткая, честная и приятная на ощупь партия в Альчики: физика броска ощущается «настоящей», результат матча нельзя подделать с клиента, сессия занимает 2–5 минут.

## Business Context

- **Customer**: Игроки без привязки к стране; MVP на русском и английском; позже — казахский, кыргызский и другие тюркские языки
- **Revenue model**: Косметический магазин (цвета, материалы, орнаменты, эффекты). Реальные IAP (Google Play Billing / Apple IAP) — после MVP. Ranked не Pay-to-Win
- **Success metric**: Игрок проходит первую партию в Альчики против бота, понимает правила по статическим инструкциям и хочет ещё одну короткую сессию
- **Strategy notes**: Платформа важнее одиночной игры. Архитектура и каталог должны переживать добавление новых традиционных игр без переработки приложения и backend

## Requirements

### Validated

- ✓ Технический prototype физики Альчиков (PROTO-01/02) — v1.0
- ✓ Гостевой mint + каталог + первая партия Альчики vs bot (AUTH-01, ALCH-*, BOT-01/03, SESS-01, PRES-*) — v1.0
- ✓ Private rooms + Casual QM + reconnect + SoftElo profile (MODE-01…03/05, SESS-02/05, PROF-*) — v1.0
- ✓ Economy COINS/GEMS + presentation-only cosmetics (ECON-01…05) — v1.0
- ✓ Stick Pull PLAYABLE (CAT-02, STICK-*, BOT-02, SESS-04) — v1.0
- ✓ Bind username/password same playerId, never-sum adopt (AUTH-02…04) — v1.0
- ✓ Ranked Glicko-2 + skill boards season/all-time + ranked reconnect (MODE-04, SESS-03, LEAD-*) — v1.0
- ✓ ANLT-01 EventSink + GHA CI + compose.prod — v1.0

### Active

- [ ] Real IAP (Google Play / App Store) wired to empty `purchases` UNIQUE shell
- [ ] Additional Turkic locales (kk, ky, …) on existing i18n keys
- [ ] Third catalog title beyond Coming Soon
- [ ] Nyquist validate-phase for phases 1–4 and 6 (tech debt from v1.0 audit)

### Out of Scope

- Реальные платежи Google Play / App Store в MVP — пользователь явно отложил IAP; магазин работает на игровой валюте
- Microservices и Kubernetes — нет объективной необходимости; MVP = modular monolith
- ML/нейросеть для ботов — достаточно детерминированных уровней с естественными ошибками
- Лицензированные персонажи, бренды, чужие орнаменты без прав — только оригинальный дизайн
- Казахский, кыргызский и прочие тюркские языки в MVP — заложены как расширение, не блокер релиза
- Третья полноценная игра в MVP — только слот Coming Soon
- Email/OAuth/телефон как обязательный вход — гость + username/password
- Динамический интерактивный туториал с анимированными подсказками — достаточно статических инструкций
- Отдельный git-репозиторий для nomad-game — владелец оставил историю в родительском репозитории `Documents/проекты`

## Current State

**Shipped:** v1.0 Parlor MVP (2026-09-15) — 7 phases, 59 plans, 46/46 requirements.

**Codebase:** ~7.2k Java (Spring Boot 4.1 + Modulith + dyn4j) + ~16.8k Dart (Flutter 3.47 + Flame 1.38 + forge2d 0.14.2). PostgreSQL 18, Testcontainers ITs, GHA `ci.yml`, `compose.prod.yaml`.

**Stack locks:** Forge2D 0.14.2 / flame_forge2d 0.19.3+7 — do not upgrade without a new physics gate. Palette PRES-02 felt `#1B6B3A` / wood `#241810` / gold `#F0B429`.

## Next Milestone Goals

Define via `/gsd-new-milestone`. Likely candidates from Out of Scope / Active: real IAP, more locales, third title, Nyquist cleanup, observability (OTel later).

## Context

v1.0 shipped as a guest-first parlor: Alchiki (JVM-authoritative throws) + Stick Pull (stamina tug), private/casual/ranked modes, soft cosmetics, bind identity, Glicko boards, EventSink without analytics SaaS.

Родительский git worktree: `C:/Users/sergei.elistratov/Documents/проекты`. Planning-артефакты коммитятся туда как `nomad-game/.planning/…`.

## Constraints

- **Platform**: Android + iOS — один клиентский стек на обе платформы
- **Architecture**: Modular monolith; игровые модули независимы (`games/alchiki/`, `games/stick_pull/`)
- **Authority**: Backend is source of truth; клиент не определяет исход, очки, рейтинг, баланс, награды, покупки
- **Fairness**: Ranked без Pay-to-Win; косметика не даёт геймплейного преимущества
- **Session length**: Альчики ~2–5 мин; палка ~15–40 сек
- **Team**: Один разработчик + AI agents — сложность должна быть сопровождаемой
- **MVP first**: Не строить инфраструктуру раньше необходимости
- **Prototype gate**: Не разворачивать полный продукт, пока не доказан physics stack
- **Security**: password hashing, access/refresh + rotation, rate limit, WS auth, validation, anti-cheat, purchase verification (когда появятся IAP), защита экономики
- **Localization**: MVP EN+RU; ключи i18n сразу, чтобы добавить тюркские языки без переработки UI
- **Art**: Яркий традиционный азиатский/кочевой стиль; оригинальные темы Gold / Neon / Ice / Fire / Space / национальные орнаменты
- **Payments**: IAP вне MVP, но модель данных и idempotency заложить так, чтобы не переписывать экономику
- **Git**: Не создавать вложенный `.git` в nomad-game — история в родительском репозитории

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Платформа игр, не одиночный тайтл | Новые традиционные игры должны добавляться модулями | ✓ Good — Stick Pull landed as second module |
| Альчики = флагман MVP, палка = вторая игра | Физика Альчиков — главный технический риск и главная ценность | ✓ Good |
| Гостевой вход, аккаунт позже | Снижает трение до первой партии | ✓ Good — bind shipped Phase 7 |
| Локали MVP: EN + RU | Тюркские языки — следующим слоем | ✓ Good |
| Реальные IAP не в MVP | Soft currency first; empty IAP table ready | ✓ Good — still Out of Scope for next until chosen |
| Modular monolith, не microservices | Один разработчик | ✓ Good |
| Server-authoritative: input → server sim → keyframe replay | Client rest-poses = cheat | ✓ Good — SoftElo + Glicko + economy server SoT |
| Рейтинг: Glicko-2 vendored in-repo | Sparse Ranked; SoftElo stays Casual | ✓ Good |
| Клиент: Flutter 3.47 + Flame + Forge2D 0.14.2 | JVM authority; do not upgrade Forge2D casually | ✓ Good |
| Backend: Java 21 + Spring Boot 4.1 + Modulith; PG 18; no Redis day 1 | In-process queues | ✓ Good |
| Первая фаза = Alchiki Physics Prototype | Fail-fast | ✓ Good |
| Обучение = статические инструкции | Alchiki + Stick how-to | ✓ Good |
| Визуал PRES-02 felt/wood/gold | Cultural shell | ✓ Good |
| Коммиты в родительский `проекты` | Explicit owner choice | ✓ Good |

## Proposed Alchiki Mobile Rules (hypothesis)

Подлежит проверке на прототипе и в discuss-phase. Не священны.

- Поле: круг. В центре — N альчиков (ориентир 5–7). У каждого игрока свой сака.
- Ход: выбрать направление (жест/прицел) → удерживать бросок (сила) → отпустить.
- Очки: альчик, полностью вышедший за круг после успокоения физики, засчитывается ходившему. Сака, вышедшая за круг, не даёт очков и возвращается к игроку на следующий ход (или ход сжигается — уточнить на прототипе).
- Победа: первый набравший целевой счёт (ориентир 5) или лидер по очкам после лимита ходов / лимита времени 2–5 мин.
- Ничья: вне Ranked допустима; в Ranked — тай-брейк по последнему успешному выбиванию или оба получают ничейный rating update.
- Зрительная ясность важнее симуляции кости: коллайдеры могут быть упрощёнными (диск/капсула), если вращение и импульс читаются.

## Proposed Stick Pull Rules (hypothesis)

- 3-2-1-GO, затем тапы. Сервер принимает input rate с clamp и детектит нечеловеческий паттерн.
- Stamina: быстрые тапы расходуют запас, восстановление при паузе. Победа = вытолкнуть маркер палки до порога или лидер по позиции на timeout.
- Длительность 15–40 сек.

## Technical Unknowns (must resolve before full build)

Resolved in `.planning/research/` (2026-09-05). **Phase 1 prototype passed 2026-09-06**. **Phase 2 guest catalog + bot match passed 2026-09-07**. Physics stack stays locked; next work is private rooms + casual reconnect (Phase 3), not a stack reopen.

1. ~~Mobile/game stack~~ → Flutter + Flame + Forge2D
2. ~~2D / 2.5D / 3D~~ → 2.5D presentation, 2D physics
3. ~~Physics architecture~~ → client Forge2D for feel; server dyn4j burst-to-rest → keyframes; no lockstep
4. ~~Multiplayer architecture~~ → REST + raw WebSocket; `MatchSession` + `GameEngine` plugins; mode-specific reconnect
5. ~~Backend stack~~ → Java 21 / Spring Boot modular monolith / PostgreSQL / no Redis day one
6. MVP boundaries → see REQUIREMENTS.md; Ranked/leaderboards remain in v1 but after casual reconnect is stable

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-09-15 after v1.0 Parlor MVP milestone*
