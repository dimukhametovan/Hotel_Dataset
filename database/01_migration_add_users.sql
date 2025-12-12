-- ============================================
-- Скрипт обновления существующей базы данных
-- Добавление системы пользователей с ролями и аутентификацией
-- ============================================

-- ============================================
-- 1. Создание типа для ролей
-- ============================================
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('guest', 'hotel_admin', 'system_admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================
-- 2. Создание таблицы пользователей
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,  -- Bcrypt hash пароля
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    role user_role NOT NULL DEFAULT 'guest',
    is_active BOOLEAN DEFAULT TRUE,
    guest_id INTEGER,  -- Связь со старой таблицей guests
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_guest ON users(guest_id);

-- ============================================
-- 3. Добавление полей в существующие таблицы
-- ============================================

-- Добавляем admin_id в hotels (администратор отеля)
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS admin_id INTEGER REFERENCES users(user_id) ON DELETE SET NULL;
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE hotels ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_hotels_admin ON hotels(admin_id);

-- Добавляем user_id в bookings (связь с новой системой пользователей)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE;

-- Добавляем поля timestamps
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Добавляем поле guests_count если его нет
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS guests_count INTEGER DEFAULT 1 CHECK (guests_count > 0);

-- Добавляем поля в rooms
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT TRUE;
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_rooms_available ON rooms(is_available);

-- Переносим price_per_night из roomtypes в rooms (для гибкости)
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS price_per_night DECIMAL(10, 2);

-- Обновляем rooms.price_per_night из roomtypes
UPDATE rooms r
SET price_per_night = rt.price_per_night
FROM roomtypes rt
WHERE r.roomtype_id = rt.type_id
AND r.price_per_night IS NULL;

-- Добавляем max_occupancy в roomtypes
ALTER TABLE roomtypes ADD COLUMN IF NOT EXISTS max_occupancy INTEGER DEFAULT 2 CHECK (max_occupancy > 0);

-- Добавляем поля в reviews
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS hotel_id INTEGER;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Заполняем hotel_id в reviews на основе booking
UPDATE reviews r
SET hotel_id = rm.hotel_id
FROM bookings b
JOIN rooms rm ON b.room_id = rm.room_id
WHERE r.booking_id = b.booking_id AND r.hotel_id IS NULL;

-- Добавляем внешний ключ для hotel_id
ALTER TABLE reviews ADD CONSTRAINT IF NOT EXISTS reviews_hotel_id_fkey 
    FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_reviews_hotel ON reviews(hotel_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user ON reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_approved ON reviews(is_approved);

-- Добавляем поля в amenities
ALTER TABLE amenities ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE amenities ADD COLUMN IF NOT EXISTS icon VARCHAR(50);
ALTER TABLE amenities ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Добавляем created_at в room_amenities
ALTER TABLE room_amenities ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Добавляем поля в roomtypes
ALTER TABLE roomtypes ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- ============================================
-- 4. Миграция данных guests -> users
-- ============================================

-- Создаем пользователей на основе существующих гостей
INSERT INTO users (email, password_hash, first_name, last_name, phone, role, guest_id, created_at)
SELECT 
    g.email,
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5oDhGx0JqHX3O', -- hash для 'password123'
    g.first_name,
    g.last_name,
    g.phone,
    'guest'::user_role,
    g.guest_id,
    g.registration_date
FROM guests g
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = g.email)
ON CONFLICT (email) DO NOTHING;

-- Обновляем bookings.user_id на основе guest_id
UPDATE bookings b
SET user_id = u.user_id
FROM users u
WHERE b.guest_id = u.guest_id
AND b.user_id IS NULL;

-- Обновляем reviews.user_id на основе bookings
UPDATE reviews r
SET user_id = b.user_id
FROM bookings b
WHERE r.booking_id = b.booking_id
AND r.user_id IS NULL;

-- ============================================
-- 5. Создание тестовых администраторов
-- ============================================

-- Системный администратор (пароль: admin123)
INSERT INTO users (email, password_hash, first_name, last_name, role, is_active)
VALUES 
    ('admin@hotel.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5oDhGx0JqHX3O', 
     'Системный', 'Администратор', 'system_admin', TRUE)
ON CONFLICT (email) DO NOTHING;

-- Администраторы отелей (пароль: hotel123)
INSERT INTO users (email, password_hash, first_name, last_name, phone, role, is_active)
VALUES 
    ('admin.plaza@hotel.ru', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5oDhGx0JqHX3O', 
     'Менеджер', 'Плаза', '+7-495-222-3344', 'hotel_admin', TRUE),
    ('admin.seaview@hotel.ru', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5oDhGx0JqHX3O', 
     'Менеджер', 'Сивью', '+7-862-333-4455', 'hotel_admin', TRUE),
    ('admin.mountain@hotel.ru', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5oDhGx0JqHX3O', 
     'Менеджер', 'Маунтин', '+7-862-444-5566', 'hotel_admin', TRUE)
ON CONFLICT (email) DO NOTHING;

-- Назначаем администраторов отелям
UPDATE hotels SET admin_id = (SELECT user_id FROM users WHERE email = 'admin.plaza@hotel.ru') 
WHERE name = 'Hotel Plaza';

UPDATE hotels SET admin_id = (SELECT user_id FROM users WHERE email = 'admin.seaview@hotel.ru') 
WHERE name = 'Sea View Resort';

UPDATE hotels SET admin_id = (SELECT user_id FROM users WHERE email = 'admin.mountain@hotel.ru') 
WHERE name = 'Mountain Lodge';

-- ============================================
-- 6. Комментарии к новым полям
-- ============================================
COMMENT ON TABLE users IS 'Пользователи системы с аутентификацией и ролями';
COMMENT ON COLUMN users.password_hash IS 'Bcrypt hash пароля (НЕ хранится в открытом виде!)';
COMMENT ON COLUMN users.role IS 'Роль пользователя: guest, hotel_admin, system_admin';
COMMENT ON COLUMN users.guest_id IS 'Связь со старой таблицей guests для миграции данных';
COMMENT ON COLUMN hotels.admin_id IS 'Администратор отеля из таблицы users';
COMMENT ON COLUMN bookings.user_id IS 'Пользователь из новой системы аутентификации';
COMMENT ON COLUMN reviews.is_approved IS 'Отзыв одобрен администратором отеля';

-- ============================================
-- ИНФОРМАЦИЯ О ТЕСТОВЫХ ПОЛЬЗОВАТЕЛЯХ
-- ============================================
-- Email: admin@hotel.com | Пароль: admin123 | Роль: Системный администратор
-- Email: admin.plaza@hotel.ru | Пароль: hotel123 | Роль: Администратор отеля
-- Email: любой email из guests | Пароль: password123 | Роль: Гость
-- ============================================
