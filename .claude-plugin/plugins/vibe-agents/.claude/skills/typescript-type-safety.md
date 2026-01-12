---
name: typescript-type-safety
description: TypeScript и типизация
agent: vibe-typescript
keywords:
  - типы
  - typescript
  - типизация
  - zod
  - interface
  - type
  - generic
  - type safety
  - строгая типизация
  - валидация
---

## Описание

Обеспечение строгой типизации в проекте Vibee. Работа с TypeScript типами, валидация через Zod, создание type-safe интерфейсов.

## Основные возможности

- **Строгая типизация**: Настройка strict mode TypeScript
- **Zod валидация**: Runtime валидация с type inference
- **Generic типы**: Создание переиспользуемых типовых конструкций
- **Type Guards**: Защита типов в runtime
- **Type Utilities**: Утилиты для работы с типами (Pick, Omit, Partial и т.д.)

## Примеры использования

- Исправление ошибок типов после проверки `tsc --noEmit`
- Создание типов для новых плагинов ElizaOS
- Настройка Zod схем для валидации данных
- Рефакторинг кода для улучшения type safety

## Связанные скиллы

- `coding-implementation` - написание type-safe кода
- `code-review` - проверка качества типизации
- `elizaos-plugin` - типизация плагинов

## Best Practices

- Всегда проверяй типы перед коммитом (`bun run typecheck`)
- Используй Zod для runtime валидации внешних данных
- Избегай `any` - используй `unknown` с type guards
- Документируй сложные generic типы
- Используй type utilities вместо дублирования типов
