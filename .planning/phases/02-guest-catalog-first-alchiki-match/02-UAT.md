---
status: complete
phase: 02-guest-catalog-first-alchiki-match
source: [02-VERIFICATION.md]
started: 2026-09-07T03:45:00Z
updated: 2026-09-07T04:16:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Первая партия EASY до 3 минут (BOT-03)
expected: Холодный старт без поля имени → каталог EN/RU → «Играть в Альчики» → пропуск или пять карточек → матч EASY до конца. Победа или завершённый матч < 3 мин; бот ходит видимо (прицел + заряд + settle), не мгновенным popup счёта.
result: pass

### 2. NORMAL / HARD и Coming Soon
expected: С каталога Норма и Сложно — стол с 6 / 7 костями, бот ошибается по-разному. Плитки «Перетягивание палки» и «Ещё игры» не открывают игру. Нет магазина, кода комнаты, Rematch.
result: pass

### 3. Палитра PRES-02
expected: Каталог, how-to, стол, пауза и результат: войлок #1B6B3A, дерево #241810, золото только на зарезервированных CTA (Play Alchiki, Hold Throw, выбранная сложность, Resume).
result: pass

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
