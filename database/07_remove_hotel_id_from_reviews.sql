-- ============================================
-- Миграция: Удаление hotel_id из reviews
-- Приведение к 3NF (убираем транзитивную зависимость)
-- ============================================

-- hotel_id можно получить через booking_id -> room_id -> hotel_id
-- Хранить его отдельно - избыточность данных

ALTER TABLE reviews DROP COLUMN IF EXISTS hotel_id CASCADE;

COMMENT ON TABLE reviews IS 'Отзывы гостей (hotel_id получается через bookings)';
