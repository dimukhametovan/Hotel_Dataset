-- ============================================
-- Функции и хранимые процедуры
-- Сервис бронирования отелей
-- ============================================

-- ============================================
-- Функция: Расчет стоимости бронирования
-- ============================================
CREATE OR REPLACE FUNCTION calculate_booking_price(
    p_room_id INTEGER,
    p_check_in DATE,
    p_check_out DATE
) RETURNS DECIMAL(10, 2) AS $$
DECLARE
    v_price_per_night DECIMAL(10, 2);
    v_nights INTEGER;
    v_total DECIMAL(10, 2);
BEGIN
    -- Получаем цену за ночь из rooms (или из roomtypes если в rooms NULL)
    SELECT COALESCE(r.price_per_night, rt.price_per_night) INTO v_price_per_night
    FROM rooms r
    LEFT JOIN roomtypes rt ON r.roomtype_id = rt.roomtype_id
    WHERE r.room_id = p_room_id;
    
    IF v_price_per_night IS NULL THEN
        RAISE EXCEPTION 'Номер с ID % не найден', p_room_id;
    END IF;
    
    -- Вычисляем количество ночей
    v_nights := p_check_out - p_check_in;
    
    IF v_nights <= 0 THEN
        RAISE EXCEPTION 'Дата выезда должна быть позже даты заезда';
    END IF;
    
    -- Рассчитываем общую стоимость
    v_total := v_price_per_night * v_nights;
    
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_booking_price IS 'Рассчитывает общую стоимость бронирования на основе цены номера и количества ночей';

-- ============================================
-- Функция: Проверка доступности номера
-- ============================================
CREATE OR REPLACE FUNCTION check_room_availability(
    p_room_id INTEGER,
    p_check_in DATE,
    p_check_out DATE,
    p_exclude_booking_id INTEGER DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_conflict_count INTEGER;
BEGIN
    -- Проверяем, нет ли пересечений с существующими бронированиями
    SELECT COUNT(*) INTO v_conflict_count
    FROM bookings
    WHERE room_id = p_room_id
        AND status NOT IN ('cancelled')
        AND (booking_id != p_exclude_booking_id OR p_exclude_booking_id IS NULL)
        AND (
            (check_in_date <= p_check_in AND check_out_date > p_check_in)
            OR (check_in_date < p_check_out AND check_out_date >= p_check_out)
            OR (check_in_date >= p_check_in AND check_out_date <= p_check_out)
        );
    
    RETURN v_conflict_count = 0;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_room_availability IS 'Проверяет доступность номера в указанный период';

-- ============================================
-- Функция: Получение доступных номеров
-- ============================================
CREATE OR REPLACE FUNCTION get_available_rooms(
    p_hotel_id INTEGER,
    p_check_in DATE,
    p_check_out DATE,
    p_guests_count INTEGER DEFAULT 1
) RETURNS TABLE (
    room_id INTEGER,
    room_number VARCHAR,
    type_name VARCHAR,
    price_per_night DECIMAL,
    max_occupancy INTEGER,
    total_price DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.room_id,
        r.room_number,
        rt.name as type_name,
        r.price_per_night,
        rt.max_occupancy,
        calculate_booking_price(r.room_id, p_check_in, p_check_out) as total_price
    FROM rooms r
    INNER JOIN room_types rt ON r.type_id = rt.type_id
    WHERE r.hotel_id = p_hotel_id
        AND r.is_available = TRUE
        AND rt.max_occupancy >= p_guests_count
        AND check_room_availability(r.room_id, p_check_in, p_check_out)
    ORDER BY r.price_per_night;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_available_rooms IS 'Возвращает список доступных номеров отеля в указанный период';

-- ============================================
-- Функция: Статистика загрузки отеля
-- ============================================
CREATE OR REPLACE FUNCTION get_hotel_occupancy_stats(
    p_hotel_id INTEGER,
    p_start_date DATE,
    p_end_date DATE
) RETURNS TABLE (
    total_rooms BIGINT,
    booked_rooms BIGINT,
    available_rooms BIGINT,
    occupancy_rate DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    WITH room_stats AS (
        SELECT COUNT(*) as total
        FROM rooms
        WHERE hotel_id = p_hotel_id AND is_available = TRUE
    ),
    booking_stats AS (
        SELECT COUNT(DISTINCT room_id) as booked
        FROM bookings b
        INNER JOIN rooms r ON b.room_id = r.room_id
        WHERE r.hotel_id = p_hotel_id
            AND b.status IN ('confirmed', 'checked_in')
            AND b.check_in_date <= p_end_date
            AND b.check_out_date >= p_start_date
    )
    SELECT 
        rs.total,
        COALESCE(bs.booked, 0) as booked,
        rs.total - COALESCE(bs.booked, 0) as available,
        CASE 
            WHEN rs.total > 0 THEN ROUND((COALESCE(bs.booked, 0)::DECIMAL / rs.total) * 100, 2)
            ELSE 0
        END as rate
    FROM room_stats rs, booking_stats bs;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_hotel_occupancy_stats IS 'Статистика загрузки отеля за период';

-- ============================================
-- Функция: Средний рейтинг отеля
-- ============================================
CREATE OR REPLACE FUNCTION get_hotel_average_rating(p_hotel_id INTEGER)
RETURNS DECIMAL(3, 2) AS $$
DECLARE
    v_avg_rating DECIMAL(3, 2);
BEGIN
    SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0)
    INTO v_avg_rating
    FROM reviews
    WHERE hotel_id = p_hotel_id AND is_approved = TRUE;
    
    RETURN v_avg_rating;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_hotel_average_rating IS 'Возвращает средний рейтинг отеля на основе одобренных отзывов';

-- ============================================
-- Функция: Проверка прав на добавление отзыва
-- ============================================
CREATE OR REPLACE FUNCTION can_add_review(
    p_user_id INTEGER,
    p_booking_id INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    v_booking_exists BOOLEAN;
    v_is_checked_out BOOLEAN;
    v_has_review BOOLEAN;
BEGIN
    -- Проверяем, принадлежит ли бронирование пользователю
    SELECT EXISTS(
        SELECT 1 FROM bookings
        WHERE booking_id = p_booking_id
            AND user_id = p_user_id
    ) INTO v_booking_exists;
    
    IF NOT v_booking_exists THEN
        RETURN FALSE;
    END IF;
    
    -- Проверяем, завершено ли проживание
    SELECT status = 'checked_out' INTO v_is_checked_out
    FROM bookings
    WHERE booking_id = p_booking_id;
    
    IF NOT v_is_checked_out THEN
        RETURN FALSE;
    END IF;
    
    -- Проверяем, нет ли уже отзыва
    SELECT EXISTS(
        SELECT 1 FROM reviews
        WHERE booking_id = p_booking_id
    ) INTO v_has_review;
    
    RETURN NOT v_has_review;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION can_add_review IS 'Проверяет, может ли пользователь добавить отзыв к бронированию';

-- ============================================
-- Процедура: Отмена просроченных бронирований
-- ============================================
CREATE OR REPLACE PROCEDURE cancel_expired_bookings()
LANGUAGE plpgsql AS $$
DECLARE
    v_cancelled_count INTEGER;
BEGIN
    -- Отменяем бронирования со статусом pending, у которых дата заезда прошла
    UPDATE bookings
    SET status = 'cancelled',
        updated_at = CURRENT_TIMESTAMP
    WHERE status = 'pending'
        AND check_in_date < CURRENT_DATE;
    
    GET DIAGNOSTICS v_cancelled_count = ROW_COUNT;
    
    RAISE NOTICE 'Отменено % просроченных бронирований', v_cancelled_count;
END;
$$;

COMMENT ON PROCEDURE cancel_expired_bookings IS 'Автоматически отменяет бронирования с истекшим сроком';

-- ============================================
-- Функция: Получение бронирований пользователя
-- ============================================
CREATE OR REPLACE FUNCTION get_user_bookings(p_user_id INTEGER)
RETURNS TABLE (
    booking_id INTEGER,
    hotel_name VARCHAR,
    room_number VARCHAR,
    check_in DATE,
    check_out DATE,
    status booking_status,
    total_price DECIMAL,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.booking_id,
        h.name as hotel_name,
        r.room_number,
        b.check_in_date,
        b.check_out_date,
        b.status,
        b.total_price,
        b.created_at
    FROM bookings b
    INNER JOIN rooms r ON b.room_id = r.room_id
    INNER JOIN hotels h ON r.hotel_id = h.hotel_id
    WHERE b.user_id = p_user_id
    ORDER BY b.created_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_user_bookings IS 'Возвращает все бронирования пользователя с деталями';

-- ============================================
-- Функция: Формирование отчета по бронированиям отеля
-- ============================================
CREATE OR REPLACE FUNCTION get_hotel_bookings_report(
    p_hotel_id INTEGER,
    p_start_date DATE,
    p_end_date DATE
) RETURNS TABLE (
    booking_id INTEGER,
    guest_name VARCHAR,
    guest_email VARCHAR,
    room_number VARCHAR,
    check_in DATE,
    check_out DATE,
    status booking_status,
    total_price DECIMAL,
    nights INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.booking_id,
        u.first_name || ' ' || u.last_name as guest_name,
        u.email as guest_email,
        r.room_number,
        b.check_in_date,
        b.check_out_date,
        b.status,
        b.total_price,
        (b.check_out_date - b.check_in_date) as nights
    FROM bookings b
    INNER JOIN rooms r ON b.room_id = r.room_id
    INNER JOIN users u ON b.user_id = u.user_id
    WHERE r.hotel_id = p_hotel_id
        AND b.check_in_date <= p_end_date
        AND b.check_out_date >= p_start_date
    ORDER BY b.check_in_date DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_hotel_bookings_report IS 'Отчет по бронированиям отеля за период';
