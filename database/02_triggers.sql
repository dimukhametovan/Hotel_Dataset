-- ============================================
-- Триггеры для базы данных
-- Сервис бронирования отелей
-- ============================================

-- ============================================
-- Функция для автоматического обновления updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Триггер: Обновление updated_at для users
-- ============================================
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Триггер: Обновление updated_at для hotels
-- ============================================
DROP TRIGGER IF EXISTS update_hotels_updated_at ON hotels;
CREATE TRIGGER update_hotels_updated_at
    BEFORE UPDATE ON hotels
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Триггер: Обновление updated_at для rooms
-- ============================================
DROP TRIGGER IF EXISTS update_rooms_updated_at ON rooms;
CREATE TRIGGER update_rooms_updated_at
    BEFORE UPDATE ON rooms
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Триггер: Обновление updated_at для bookings
-- ============================================
DROP TRIGGER IF EXISTS update_bookings_updated_at ON bookings;
CREATE TRIGGER update_bookings_updated_at
    BEFORE UPDATE ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Триггер: Обновление updated_at для reviews
-- ============================================
DROP TRIGGER IF EXISTS update_reviews_updated_at ON reviews;
CREATE TRIGGER update_reviews_updated_at
    BEFORE UPDATE ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Функция: Автоматический расчет total_price при создании бронирования
-- ============================================
CREATE OR REPLACE FUNCTION calculate_total_price_trigger()
RETURNS TRIGGER AS $$
DECLARE
    v_price_per_night DECIMAL(10, 2);
    v_nights INTEGER;
BEGIN
    -- Получаем цену номера за ночь
    SELECT price_per_night INTO v_price_per_night
    FROM rooms
    WHERE room_id = NEW.room_id;
    
    -- Рассчитываем количество ночей
    v_nights := NEW.check_out_date - NEW.check_in_date;
    
    -- Проверяем корректность дат
    IF v_nights <= 0 THEN
        RAISE EXCEPTION 'Дата выезда должна быть позже даты заезда';
    END IF;
    
    -- Рассчитываем общую стоимость
    NEW.total_price := v_price_per_night * v_nights;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Триггер: Автоматический расчет стоимости бронирования
-- ============================================
DROP TRIGGER IF EXISTS calculate_booking_price ON bookings;
CREATE TRIGGER calculate_booking_price
    BEFORE INSERT OR UPDATE OF room_id, check_in_date, check_out_date ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION calculate_total_price_trigger();

COMMENT ON TRIGGER calculate_booking_price ON bookings IS 
'Автоматически рассчитывает total_price на основе цены номера и количества ночей';

-- ============================================
-- Функция: Проверка доступности номера перед бронированием
-- ============================================
CREATE OR REPLACE FUNCTION check_booking_availability()
RETURNS TRIGGER AS $$
DECLARE
    v_conflict_count INTEGER;
BEGIN
    -- Проверяем пересечения с существующими бронированиями
    SELECT COUNT(*) INTO v_conflict_count
    FROM bookings
    WHERE room_id = NEW.room_id
        AND booking_id != COALESCE(NEW.booking_id, 0)  -- Исключаем текущее бронирование при UPDATE
        AND status NOT IN ('cancelled')
        AND (
            (check_in_date <= NEW.check_in_date AND check_out_date > NEW.check_in_date)
            OR (check_in_date < NEW.check_out_date AND check_out_date >= NEW.check_out_date)
            OR (check_in_date >= NEW.check_in_date AND check_out_date <= NEW.check_out_date)
        );
    
    IF v_conflict_count > 0 THEN
        RAISE EXCEPTION 'Номер уже забронирован на выбранные даты';
    END IF;
    
    -- Проверяем, что номер доступен
    IF NOT EXISTS (SELECT 1 FROM rooms WHERE room_id = NEW.room_id AND is_available = TRUE) THEN
        RAISE EXCEPTION 'Номер недоступен для бронирования';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Триггер: Проверка доступности при бронировании
-- ============================================
DROP TRIGGER IF EXISTS check_room_before_booking ON bookings;
CREATE TRIGGER check_room_before_booking
    BEFORE INSERT OR UPDATE OF room_id, check_in_date, check_out_date ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION check_booking_availability();

COMMENT ON TRIGGER check_room_before_booking ON bookings IS 
'Проверяет доступность номера в указанный период перед созданием/обновлением бронирования';

-- ============================================
-- Функция: Установка даты бронирования
-- ============================================
CREATE OR REPLACE FUNCTION set_booking_date()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.booking_date IS NULL THEN
        NEW.booking_date := CURRENT_TIMESTAMP;
    END IF;
    
    IF NEW.created_at IS NULL THEN
        NEW.created_at := CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Триггер: Установка даты бронирования
-- ============================================
DROP TRIGGER IF EXISTS set_booking_dates ON bookings;
CREATE TRIGGER set_booking_dates
    BEFORE INSERT ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION set_booking_date();

-- ============================================
-- Функция: Проверка прав на отзыв
-- ============================================
CREATE OR REPLACE FUNCTION validate_review_rights()
RETURNS TRIGGER AS $$
DECLARE
    v_booking_user_id INTEGER;
    v_booking_status VARCHAR(20);
BEGIN
    -- Получаем user_id и статус бронирования
    SELECT user_id, status INTO v_booking_user_id, v_booking_status
    FROM bookings
    WHERE booking_id = NEW.booking_id;
    
    -- Проверяем, что бронирование принадлежит пользователю
    IF v_booking_user_id != NEW.user_id THEN
        RAISE EXCEPTION 'Вы можете оставлять отзыв только на свои бронирования';
    END IF;
    
    -- Проверяем, что проживание завершено
    IF v_booking_status != 'completed' THEN
        RAISE EXCEPTION 'Отзыв можно оставить только после завершения проживания';
    END IF;
    
    -- Проверяем, что отзыв еще не был оставлен
    IF EXISTS (SELECT 1 FROM reviews WHERE booking_id = NEW.booking_id AND review_id != COALESCE(NEW.review_id, 0)) THEN
        RAISE EXCEPTION 'Отзыв на это бронирование уже существует';
    END IF;
    
    -- Устанавливаем дату отзыва
    IF NEW.review_date IS NULL THEN
        NEW.review_date := CURRENT_TIMESTAMP;
    END IF;
    
    IF NEW.created_at IS NULL THEN
        NEW.created_at := CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Триггер: Валидация прав на отзыв
-- ============================================
DROP TRIGGER IF EXISTS validate_review ON reviews;
CREATE TRIGGER validate_review
    BEFORE INSERT ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION validate_review_rights();

COMMENT ON TRIGGER validate_review ON reviews IS 
'Проверяет права пользователя на добавление отзыва';

-- ============================================
-- Функция: Логирование изменений статуса бронирования
-- ============================================
CREATE TABLE IF NOT EXISTS booking_status_log (
    log_id SERIAL PRIMARY KEY,
    booking_id INTEGER NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    changed_by INTEGER REFERENCES users(user_id),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION log_booking_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO booking_status_log (booking_id, old_status, new_status, changed_at)
        VALUES (NEW.booking_id, OLD.status, NEW.status, CURRENT_TIMESTAMP);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Триггер: Логирование изменений статуса
-- ============================================
DROP TRIGGER IF EXISTS log_status_change ON bookings;
CREATE TRIGGER log_status_change
    AFTER UPDATE OF status ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION log_booking_status_change();

COMMENT ON TRIGGER log_status_change ON bookings IS 
'Логирует все изменения статуса бронирования для аудита';

COMMENT ON TABLE booking_status_log IS 'Журнал изменений статусов бронирований';
