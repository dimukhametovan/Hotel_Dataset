# База данных - Сервис бронирования отелей

## Порядок выполнения SQL скриптов

**ВАЖНО:** Скрипты должны выполняться строго в указанном порядке!

### Для новой базы данных:

```bash
# 1. Создание базы данных
createdb -U postgres hotel_booking

# 2. Выполнение скриптов по порядку
psql -U postgres -d hotel_booking -f 01_migration_add_users.sql
psql -U postgres -d hotel_booking -f 02_triggers.sql
psql -U postgres -d hotel_booking -f 03_views.sql
psql -U postgres -d hotel_booking -f 04_functions.sql
psql -U postgres -d hotel_booking -f 05_test_data.sql
```

### Для существующей базы данных из DBeaver:

Если у вас уже есть база данных с данными:

```bash
# 1. Сначала выполните миграцию (добавит таблицу users и обновит структуру)
psql -U postgres -d hotel_booking -f 01_migration_add_users.sql

# 2. Добавьте триггеры
psql -U postgres -d hotel_booking -f 02_triggers.sql

# 3. Создайте представления
psql -U postgres -d hotel_booking -f 03_views.sql

# 4. Добавьте функции
psql -U postgres -d hotel_booking -f 04_functions.sql

# 5. Тестовые данные (опционально, если нужны дополнительные данные)
psql -U postgres -d hotel_booking -f 05_test_data.sql
```

## Описание скриптов

### 01_migration_add_users.sql
- Создает таблицу `users` с ролями и хешами паролей
- Добавляет необходимые поля в существующие таблицы
- Мигрирует данные из `guests` в `users`
- Создает тестовых пользователей с разными ролями

**Тестовые пользователи:**
- Email: `admin@hotel.com` | Пароль: `admin123` | Роль: Системный администратор
- Email: `admin.plaza@hotel.ru` | Пароль: `hotel123` | Роль: Администратор отеля
- Email: любой из `guests` | Пароль: `password123` | Роль: Гость

### 02_triggers.sql
- Автоматический расчет `total_price` при создании бронирования
- Проверка доступности номера перед бронированием
- Автоматическое обновление `updated_at` для всех таблиц
- Валидация прав на добавление отзывов
- Логирование изменений статусов бронирований

### 03_views.sql
Представления для удобных выборок:
- `v_hotels_full` - отели с рейтингами
- `v_rooms_full` - номера с удобствами
- `v_active_bookings` - активные бронирования
- `v_current_stays` - текущие проживания
- `v_reviews_full` - отзывы с деталями
- `v_hotel_statistics` - статистика по отелям
- `v_room_occupancy` - загрузка номеров
- `v_users_info` - информация о пользователях
- `v_available_rooms_today` - доступные номера

### 04_functions.sql
Функции и процедуры:
- `calculate_booking_price()` - расчет стоимости
- `check_room_availability()` - проверка доступности
- `get_available_rooms()` - поиск доступных номеров
- `get_hotel_occupancy_stats()` - статистика загрузки
- `get_hotel_average_rating()` - средний рейтинг
- `can_add_review()` - проверка прав на отзыв
- `cancel_expired_bookings()` - отмена просроченных бронирований
- `get_user_bookings()` - бронирования пользователя
- `get_hotel_bookings_report()` - отчет по бронированиям

### 05_test_data.sql
- Тестовые данные отелей, номеров, удобств
- Связи номеров с удобствами

## Структура базы данных

### Основные таблицы:

1. **users** - пользователи с ролями и аутентификацией
2. **hotels** - отели
3. **rooms** - номера в отелях
4. **roomtypes** - типы номеров
5. **amenities** - удобства
6. **room_amenities** - связь номеров и удобств
7. **bookings** - бронирования
8. **reviews** - отзывы
9. **guests** - старая таблица гостей (для совместимости)
10. **booking_status_log** - лог изменений статусов

### Роли пользователей:

- `guest` - Гость (создание бронирований, отзывы)
- `hotel_admin` - Администратор отеля (управление номерами своего отеля)
- `system_admin` - Системный администратор (полный доступ)

### Статусы бронирований:

- `pending` - Ожидает подтверждения
- `confirmed` - Подтверждено
- `cancelled` - Отменено
- `checked_in` - Заезд выполнен
- `checked_out` - Выезд выполнен (можно оставить отзыв)
- `completed` - Завершено

## Проверка установки

После выполнения всех скриптов проверьте:

```sql
-- Список таблиц
\dt

-- Список представлений
\dv

-- Список функций
\df

-- Проверка данных
SELECT * FROM users WHERE role = 'system_admin';
SELECT * FROM v_hotels_full LIMIT 5;
SELECT * FROM v_available_rooms_today LIMIT 10;
```

## Примеры использования

### Поиск доступных номеров:
```sql
SELECT * FROM get_available_rooms(1, '2024-12-20', '2024-12-25', 2);
```

### Статистика отеля:
```sql
SELECT * FROM get_hotel_occupancy_stats(1, '2024-01-01', '2024-12-31');
```

### Бронирования пользователя:
```sql
SELECT * FROM get_user_bookings(1);
```

### Создание бронирования:
```sql
INSERT INTO bookings (user_id, room_id, check_in_date, check_out_date, guests_count, status)
VALUES (1, 1, '2024-12-20', '2024-12-25', 2, 'pending');
-- total_price рассчитается автоматически триггером
```

## Backup и восстановление

### Создание бэкапа:
```bash
pg_dump -U postgres hotel_booking > backup_hotel_booking.sql
```

### Восстановление:
```bash
psql -U postgres -d hotel_booking < backup_hotel_booking.sql
```

## Troubleshooting

### Ошибка "relation already exists":
Если таблица уже существует, скрипт пропустит её создание (используется `IF NOT EXISTS`).

### Ошибка при миграции данных:
Проверьте, что данные в `guests` корректны и email уникальны.

### Триггер не срабатывает:
Убедитесь, что триггеры созданы после создания таблиц.
