# Phase 3: Private Rooms + Casual Reconnect - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-07
**Phase:** 3-Private Rooms + Casual Reconnect
**Areas discussed:** Код и лобби, Ход соперника

---

## Код и лобби

| Option | Description | Selected |
|--------|-------------|----------|
| Две кнопки на каталоге | «Создать комнату» и «Войти по коду» | ✓ |
| Один экран «С другом» | Код хоста сверху, поле ввода снизу | |
| Решите сами | | |

**User's choice:** Две кнопки на каталоге
**Notes:** Сложность бота остаётся на каталоге отдельно.

| Option | Description | Selected |
|--------|-------------|----------|
| Сразу при входе второго | Без Ready | |
| Хост жмёт «Начать» | Второй уже в лобби | |
| Оба жмут Ready | Затем старт | ✓ |
| Решите сами | | |

**User's choice:** Оба Ready

| Option | Description | Selected |
|--------|-------------|----------|
| Шаринг + копировать | System share sheet + Copy | ✓ |
| Только копировать | Без share sheet | |
| Только шаринг | Без Copy | |
| Решите сами | | |

**User's choice:** Шаринг + копировать

| Option | Description | Selected |
|--------|-------------|----------|
| Host-alive + 10 мин idle TTL | Хост вышел — код мёртв; 10 мин без Ready — закрыть | ✓ |
| Только host-alive | Без idle-таймера | |
| 10 мин даже в фоне | Код жив, хост свернул приложение | |
| Решите сами | | |

**User's choice:** Host-alive + 10 мин TTL

| Option | Description | Selected |
|--------|-------------|----------|
| Хост ходит первым | | |
| Вошедший ходит первым | | ✓ |
| Случайный выбор сервера | | |
| Решите сами | | |

**User's choice:** Вошедший первым

| Option | Description | Selected |
|--------|-------------|----------|
| Хост выбирает сложность на создании | | |
| Хост меняет в лобби до Ready | | |
| Всегда NORMAL (6 костей) | Чипы только для бота | ✓ |
| Решите сами | | |

**User's choice:** Всегда NORMAL

| Option | Description | Selected |
|--------|-------------|----------|
| Короткий текст ошибки | Выброс на каталог не уточнялся | |
| Текст + поле кода остаётся | Повторный ввод без каталога | ✓ |
| Решите сами | | |

**User's choice:** Поле остаётся

| Option | Description | Selected |
|--------|-------------|----------|
| Guest-XXXX | Последние 4 символа playerId | ✓ |
| «Хост» / «Игрок 2» | Без id | |
| Решите сами | | |

**User's choice:** Guest-XXXX

---

## Ход соперника

| Option | Description | Selected |
|--------|-------------|----------|
| Как бот, после броска | ThrowResolved → aim + hold + keyframes | ✓ |
| Живой прицел по WebSocket | | |
| Скрыт до отпускания | Сразу keyframes без зарядки | |
| Решите сами | | |

**User's choice:** Как бот

| Option | Description | Selected |
|--------|-------------|----------|
| Только часы, стрелки нет | | |
| Часы + статическая поза «целится» | Без угла | ✓ |
| Решите сами | | |

**User's choice:** Поза «целится»

| Option | Description | Selected |
|--------|-------------|----------|
| Свой preview, затем morph; соперник только keyframes | D-10 | ✓ |
| Оба только общий keyframe replay | | |
| Решите сами | | |

**User's choice:** Preview + morph для своего броска

| Option | Description | Selected |
|--------|-------------|----------|
| Две саки разного цвета | Ходит только своя | ✓ |
| Одна общая сака как vs бота | | |
| Решите сами | | |

**User's choice:** Две саки

---

## Claude's Discretion

User did not pick «Решите сами» on any asked question. Reconnect (30s), rematch windows, and PvP forfeit mapping were **not discussed**; CONTEXT.md D-41–D-44 lock FEATURES/REQUIREMENTS defaults (30s SESS-02, not research 60s; no private bot-fill; 10s dual rematch; bot one-tap Play again; leave → opponent win).

Gray areas offered but not selected in the first pass: reconnect UX, rematch/leave (user later chose “ready for CONTEXT” instead of discussing them).

## Deferred Ideas

None from discussion. Standard later-phase items noted in CONTEXT.md (Quick Match, Ranked reconnect, Stick Pull, chat).
