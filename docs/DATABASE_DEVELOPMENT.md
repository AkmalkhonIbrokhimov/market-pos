# Разработка базы данных

## Требования

- Node.js 20 или новее;
- Docker с запущенным Docker Engine;
- зависимости проекта, установленные через `npm ci`.

Supabase CLI закреплён в `devDependencies`. Глобальная установка CLI не
требуется.

## Локальный запуск

Запустите локальный Supabase stack:

```bash
npm run db:start
```

Полностью пересоздайте локальную базу и примените все migrations:

```bash
npm run db:reset
```

Запустите pgTAP tests:

```bash
npm run db:test
```

Проверьте схему встроенным database linter:

```bash
npm run db:lint
```

Команда полного цикла выполняет reset, pgTAP tests и database lint:

```bash
npm run db:verify
```

После работы остановите локальный stack:

```bash
npm run db:stop
```

## Правила безопасности

Команды из этого документа работают только с локальным Supabase stack.
Использование `--linked`, `db push` и любых production credentials запрещено
без отдельного явно согласованного решения.

- **Local** предназначен для разработки, полного reset и автоматических tests.
- **Staging** является отдельным удалённым окружением для интеграционной
  проверки согласованных migrations.
- **Production** содержит рабочие данные; локальные reset-команды к нему
  неприменимы.

Новая migration не принимается без успешного clean reset локальной базы,
pgTAP tests и database lint.
