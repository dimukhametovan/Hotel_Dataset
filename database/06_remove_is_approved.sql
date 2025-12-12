-- ============================================
-- Миграция: Удаление поля is_approved из reviews
-- Отзывы теперь публикуются сразу
-- ============================================

-- Сначала пересоздаем views без is_approved
\i database/03_views.sql

-- Удаляем колонку is_approved
ALTER TABLE reviews DROP COLUMN IF EXISTS is_approved CASCADE;

COMMENT ON TABLE reviews IS 'Отзывы гостей об отелях (публикуются сразу)';
