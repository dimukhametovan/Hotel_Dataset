-- ============================================
-- Скрипт инициализации базы данных
-- Сервис бронирования отелей
-- ============================================

-- Удаление существующих таблиц (если есть)
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS room_amenities CASCADE;
DROP TABLE IF EXISTS amenities CASCADE;
DROP TABLE IF EXISTS rooms CASCADE;
DROP TABLE IF EXISTS room_types CASCADE;
DROP TABLE IF EXISTS hotels CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TYPE IF EXISTS booking_status CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;

-- ============================================
-- Создание типов данных
-- ============================================

-- Тип для статуса бронирования
CREATE TYPE booking_status AS ENUM (
    'pending',      -- Ожидает подтверждения
    'confirmed',    -- Подтверждено
    'cancelled',    -- Отменено
    'checked_in',   -- Заезд выполнен
    'checked_out'   -- Выезд выполнен
);

-- Тип для роли пользователя
CREATE TYPE user_role AS ENUM (
    'guest',            -- Гость
    'hotel_admin',      -- Администратор отеля
    'system_admin'      -- Системный администратор
);

-- ============================================
-- Таблица: Роли
-- ============================================
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    role_name user_role NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- Таблица: Пользователи
-- ============================================
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,  -- Хранится bcrypt hash
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    role user_role NOT NULL DEFAULT 'guest',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Индексы для пользователей
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- ============================================
-- Таблица: Отели
-- ============================================
CREATE TABLE hotels (
    hotel_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    address VARCHAR(500) NOT NULL,
    city VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    stars INTEGER CHECK (stars >= 1 AND stars <= 5),
    admin_id INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Индексы для отелей
CREATE INDEX idx_hotels_city ON hotels(city);
CREATE INDEX idx_hotels_admin ON hotels(admin_id);

-- ============================================
-- Таблица: Типы номеров
-- ============================================
CREATE TABLE room_types (
    type_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    max_occupancy INTEGER NOT NULL CHECK (max_occupancy > 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- Таблица: Номера
-- ============================================
CREATE TABLE rooms (
    room_id SERIAL PRIMARY KEY,
    hotel_id INTEGER NOT NULL REFERENCES hotels(hotel_id) ON DELETE CASCADE,
    type_id INTEGER NOT NULL REFERENCES room_types(type_id) ON DELETE RESTRICT,
    room_number VARCHAR(20) NOT NULL,
    floor INTEGER,
    price_per_night DECIMAL(10, 2) NOT NULL CHECK (price_per_night >= 0),
    is_available BOOLEAN DEFAULT TRUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_room_number UNIQUE (hotel_id, room_number)
);

-- Индексы для номеров
CREATE INDEX idx_rooms_hotel ON rooms(hotel_id);
CREATE INDEX idx_rooms_type ON rooms(type_id);
CREATE INDEX idx_rooms_available ON rooms(is_available);

-- ============================================
-- Таблица: Удобства
-- ============================================
CREATE TABLE amenities (
    amenity_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(50),  -- Иконка для frontend
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- Таблица: Связь номеров и удобств (Many-to-Many)
-- ============================================
CREATE TABLE room_amenities (
    room_id INTEGER NOT NULL REFERENCES rooms(room_id) ON DELETE CASCADE,
    amenity_id INTEGER NOT NULL REFERENCES amenities(amenity_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (room_id, amenity_id)
);

-- Индексы для связи
CREATE INDEX idx_room_amenities_room ON room_amenities(room_id);
CREATE INDEX idx_room_amenities_amenity ON room_amenities(amenity_id);

-- ============================================
-- Таблица: Бронирования
-- ============================================
CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    room_id INTEGER NOT NULL REFERENCES rooms(room_id) ON DELETE RESTRICT,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    status booking_status DEFAULT 'pending',
    total_price DECIMAL(10, 2),
    guests_count INTEGER NOT NULL CHECK (guests_count > 0),
    special_requests TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_dates CHECK (check_out_date > check_in_date)
);

-- Индексы для бронирований
CREATE INDEX idx_bookings_user ON bookings(user_id);
CREATE INDEX idx_bookings_room ON bookings(room_id);
CREATE INDEX idx_bookings_dates ON bookings(check_in_date, check_out_date);
CREATE INDEX idx_bookings_status ON bookings(status);

-- ============================================
-- Таблица: Отзывы
-- ============================================
CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,
    booking_id INTEGER NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    hotel_id INTEGER NOT NULL REFERENCES hotels(hotel_id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    is_approved BOOLEAN DEFAULT FALSE,  -- Модерация отзывов
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_booking_review UNIQUE (booking_id)
);

-- Индексы для отзывов
CREATE INDEX idx_reviews_hotel ON reviews(hotel_id);
CREATE INDEX idx_reviews_user ON reviews(user_id);
CREATE INDEX idx_reviews_approved ON reviews(is_approved);

-- ============================================
-- Комментарии к таблицам
-- ============================================
COMMENT ON TABLE users IS 'Пользователи системы с различными ролями';
COMMENT ON TABLE hotels IS 'Отели в системе';
COMMENT ON TABLE rooms IS 'Номера в отелях';
COMMENT ON TABLE room_types IS 'Типы номеров (одноместный, двухместный и т.д.)';
COMMENT ON TABLE amenities IS 'Удобства в номерах';
COMMENT ON TABLE bookings IS 'Бронирования номеров';
COMMENT ON TABLE reviews IS 'Отзывы гостей о проживании';

COMMENT ON COLUMN users.password_hash IS 'Bcrypt hash пароля (пароль не хранится в открытом виде)';
COMMENT ON COLUMN bookings.total_price IS 'Автоматически рассчитывается триггером';
COMMENT ON COLUMN reviews.is_approved IS 'Отзыв одобрен администратором отеля';
