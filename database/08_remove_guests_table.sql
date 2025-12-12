-- ============================================
-- Миграция: Очистка от устаревших полей guests
-- Таблица users полностью заменяет guests
-- ============================================

-- 1. Удаляем guest_id из bookings (не используется)
ALTER TABLE bookings DROP COLUMN IF EXISTS guest_id CASCADE;

-- 2. Удаляем guest_id из users (было для миграции)
ALTER TABLE users DROP COLUMN IF EXISTS guest_id CASCADE;

-- 3. Удаляем модель Guest (старая таблица)
DROP TABLE IF EXISTS guests CASCADE;

-- 4. Удаляем индекс если был
DROP INDEX IF EXISTS idx_users_guest;
DROP INDEX IF EXISTS idx_bookings_guest;

COMMENT ON TABLE users IS 'Пользователи системы (гости, админы отелей, системные админы)';
COMMENT ON TABLE bookings IS 'Бронирования номеров (user_id → users)';
