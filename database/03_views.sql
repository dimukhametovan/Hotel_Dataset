<<<<<<< HEAD
-- ============================================
-- Представления (Views)
-- Сервис бронирования отелей
-- ============================================

-- ============================================
-- Представление: Полная информация об отелях
-- ============================================
CREATE OR REPLACE VIEW v_hotels_full AS
SELECT 
    h.hotel_id,
    h.name AS hotel_name,
    h.address,
    h.city,
    h.country,
    h.phone,
    h.email,
    h.star_rating,
    h.description,
    h.is_active,
    u.first_name || ' ' || u.last_name AS admin_name,
    u.email AS admin_email,
    COUNT(DISTINCT r.room_id) AS total_rooms,
    COALESCE(ROUND(AVG(rev.rating)::numeric, 2), 0) AS average_rating,
    COUNT(DISTINCT rev.review_id) AS reviews_count
FROM hotels h
LEFT JOIN users u ON h.admin_id = u.user_id
LEFT JOIN rooms r ON h.hotel_id = r.hotel_id
LEFT JOIN reviews rev ON h.hotel_id = rev.hotel_id AND rev.is_approved = TRUE
GROUP BY h.hotel_id, h.name, h.address, h.city, h.country, h.phone, 
         h.email, h.star_rating, h.description, h.is_active, u.first_name, u.last_name, u.email;

COMMENT ON VIEW v_hotels_full IS 'Полная информация об отелях с рейтингами и количеством номеров';

-- ============================================
-- Представление: Номера с полной информацией
-- ============================================
CREATE OR REPLACE VIEW v_rooms_full AS
SELECT 
    r.room_id,
    r.hotel_id,
    h.name AS hotel_name,
    h.city,
    r.room_number,
    r.floor,
    rt.type_name,
    rt.description AS room_type_description,
    COALESCE(r.price_per_night, rt.price_per_night) AS price_per_night,
    rt.max_occupancy,
    r.is_available,
    r.description AS room_description,
    STRING_AGG(a.amenity_name, ', ' ORDER BY a.amenity_name) AS amenities
FROM rooms r
INNER JOIN hotels h ON r.hotel_id = h.hotel_id
INNER JOIN roomtypes rt ON r.roomtype_id = rt.roomtype_id
LEFT JOIN room_amenities ra ON r.room_id = ra.room_id
LEFT JOIN amenities a ON ra.amenity_id = a.amenity_id
GROUP BY r.room_id, r.hotel_id, h.name, h.city, r.room_number, r.floor,
         rt.type_name, rt.description, r.price_per_night, rt.price_per_night,
         rt.max_occupancy, r.is_available, r.description;

COMMENT ON VIEW v_rooms_full IS 'Полная информация о номерах с удобствами';

-- ============================================
-- Представление: Активные бронирования
-- ============================================
CREATE OR REPLACE VIEW v_active_bookings AS
SELECT 
    b.booking_id,
    b.check_in_date,
    b.check_out_date,
    b.status,
    b.total_price,
    b.guests_count,
    b.booking_date,
    u.first_name || ' ' || u.last_name AS guest_name,
    u.email AS guest_email,
    u.phone AS guest_phone,
    h.name AS hotel_name,
    h.city,
    r.room_number,
    rt.type_name AS room_type,
    (b.check_out_date - b.check_in_date) AS nights
FROM bookings b
INNER JOIN users u ON b.user_id = u.user_id
INNER JOIN rooms r ON b.room_id = r.room_id
INNER JOIN hotels h ON r.hotel_id = h.hotel_id
INNER JOIN roomtypes rt ON r.roomtype_id = rt.roomtype_id
WHERE b.status NOT IN ('cancelled')
ORDER BY b.check_in_date DESC;

COMMENT ON VIEW v_active_bookings IS 'Активные (неотмененные) бронирования с полной информацией';

-- ============================================
-- Представление: Текущие проживания
-- ============================================
CREATE OR REPLACE VIEW v_current_stays AS
SELECT 
    b.booking_id,
    u.first_name || ' ' || u.last_name AS guest_name,
    u.email AS guest_email,
    h.name AS hotel_name,
    r.room_number,
    b.check_in_date,
    b.check_out_date,
    (CURRENT_DATE - b.check_in_date) AS days_stayed,
    (b.check_out_date - CURRENT_DATE) AS days_remaining,
    b.total_price
FROM bookings b
INNER JOIN users u ON b.user_id = u.user_id
INNER JOIN rooms r ON b.room_id = r.room_id
INNER JOIN hotels h ON r.hotel_id = h.hotel_id
WHERE b.status = 'confirmed'
    AND b.check_in_date <= CURRENT_DATE
    AND b.check_out_date > CURRENT_DATE;

COMMENT ON VIEW v_current_stays IS 'Текущие проживающие гости';

-- ============================================
-- Представление: Отзывы с полной информацией
-- ============================================
CREATE OR REPLACE VIEW v_reviews_full AS
SELECT 
    r.review_id,
    r.booking_id,
    r.rating,
    r.comment,
    r.review_date,
    r.is_approved,
    u.first_name || ' ' || u.last_name AS guest_name,
    h.hotel_id,
    h.name AS hotel_name,
    h.city,
    rm.room_number,
    rt.type_name AS room_type
FROM reviews r
INNER JOIN users u ON r.user_id = u.user_id
INNER JOIN hotels h ON r.hotel_id = h.hotel_id
INNER JOIN bookings b ON r.booking_id = b.booking_id
INNER JOIN rooms rm ON b.room_id = rm.room_id
INNER JOIN roomtypes rt ON rm.roomtype_id = rt.roomtype_id
ORDER BY r.review_date DESC;

COMMENT ON VIEW v_reviews_full IS 'Отзывы с полной информацией о госте и отеле';

-- ============================================
-- Представление: Статистика по отелям
-- ============================================
CREATE OR REPLACE VIEW v_hotel_statistics AS
SELECT 
    h.hotel_id,
    h.name AS hotel_name,
    h.city,
    h.star_rating,
    COUNT(DISTINCT r.room_id) AS total_rooms,
    COUNT(DISTINCT CASE WHEN r.is_available THEN r.room_id END) AS available_rooms,
    COUNT(DISTINCT b.booking_id) AS total_bookings,
    COUNT(DISTINCT CASE WHEN b.status = 'confirmed' THEN b.booking_id END) AS confirmed_bookings,
    COUNT(DISTINCT CASE WHEN b.status = 'cancelled' THEN b.booking_id END) AS cancelled_bookings,
    COALESCE(SUM(CASE WHEN b.status NOT IN ('cancelled') THEN b.total_price END), 0) AS total_revenue,
    COALESCE(ROUND(AVG(rev.rating)::numeric, 2), 0) AS average_rating,
    COUNT(DISTINCT rev.review_id) AS reviews_count
FROM hotels h
LEFT JOIN rooms r ON h.hotel_id = r.hotel_id
LEFT JOIN bookings b ON r.room_id = b.room_id
LEFT JOIN reviews rev ON h.hotel_id = rev.hotel_id AND rev.is_approved = TRUE
GROUP BY h.hotel_id, h.name, h.city, h.star_rating;

COMMENT ON VIEW v_hotel_statistics IS 'Статистика по отелям: номера, бронирования, доход, рейтинг';

-- ============================================
-- Представление: Загрузка номеров
-- ============================================
CREATE OR REPLACE VIEW v_room_occupancy AS
SELECT 
    r.room_id,
    h.name AS hotel_name,
    r.room_number,
    rt.type_name,
    COALESCE(r.price_per_night, rt.price_per_night) AS price_per_night,
    r.is_available,
    COUNT(b.booking_id) AS total_bookings,
    COUNT(CASE WHEN b.check_in_date <= CURRENT_DATE 
               AND b.check_out_date > CURRENT_DATE 
               AND b.status = 'confirmed' 
          THEN 1 END) AS currently_occupied,
    MAX(b.check_out_date) AS last_checkout_date
FROM rooms r
INNER JOIN hotels h ON r.hotel_id = h.hotel_id
INNER JOIN roomtypes rt ON r.roomtype_id = rt.roomtype_id
LEFT JOIN bookings b ON r.room_id = b.room_id AND b.status NOT IN ('cancelled')
GROUP BY r.room_id, h.name, r.room_number, rt.type_name, r.price_per_night, rt.price_per_night, r.is_available;

COMMENT ON VIEW v_room_occupancy IS 'Загрузка номеров и статус занятости';

-- ============================================
-- Представление: Пользователи с ролями
-- ============================================
CREATE OR REPLACE VIEW v_users_info AS
SELECT 
    u.user_id,
    u.email,
    u.first_name || ' ' || u.last_name AS full_name,
    u.first_name,
    u.last_name,
    u.phone,
    u.role,
    u.is_active,
    u.created_at,
    CASE u.role
        WHEN 'guest' THEN 'Гость'
        WHEN 'hotel_admin' THEN 'Администратор отеля'
        WHEN 'system_admin' THEN 'Системный администратор'
    END AS role_display,
    COUNT(DISTINCT b.booking_id) AS total_bookings,
    COUNT(DISTINCT r.review_id) AS total_reviews,
    h.name AS managed_hotel
FROM users u
LEFT JOIN bookings b ON u.user_id = b.user_id
LEFT JOIN reviews r ON u.user_id = r.user_id
LEFT JOIN hotels h ON u.user_id = h.admin_id
GROUP BY u.user_id, u.email, u.first_name, u.last_name, u.phone, 
         u.role, u.is_active, u.created_at, h.name;

COMMENT ON VIEW v_users_info IS 'Информация о пользователях с количеством бронирований и отзывов';

-- ============================================
-- Представление: Доступные номера на сегодня
-- ============================================
CREATE OR REPLACE VIEW v_available_rooms_today AS
SELECT 
    r.room_id,
    h.hotel_id,
    h.name AS hotel_name,
    h.city,
    r.room_number,
    rt.type_name,
    COALESCE(r.price_per_night, rt.price_per_night) AS price_per_night,
    rt.max_occupancy,
    STRING_AGG(a.amenity_name, ', ') AS amenities
FROM rooms r
INNER JOIN hotels h ON r.hotel_id = h.hotel_id AND h.is_active = TRUE
INNER JOIN roomtypes rt ON r.roomtype_id = rt.roomtype_id
LEFT JOIN room_amenities ra ON r.room_id = ra.room_id
LEFT JOIN amenities a ON ra.amenity_id = a.amenity_id
WHERE r.is_available = TRUE
    AND NOT EXISTS (
        SELECT 1 FROM bookings b
        WHERE b.room_id = r.room_id
            AND b.status NOT IN ('cancelled')
            AND b.check_in_date <= CURRENT_DATE
            AND b.check_out_date > CURRENT_DATE
    )
GROUP BY r.room_id, h.hotel_id, h.name, h.city, r.room_number, 
         rt.type_name, r.price_per_night, rt.price_per_night, rt.max_occupancy;

COMMENT ON VIEW v_available_rooms_today IS 'Номера, доступные для бронирования на сегодня';
=======
-- ============================================
-- Представления (Views)
-- Сервис бронирования отелей
-- ============================================

-- ============================================
-- Представление: Полная информация об отелях
-- ============================================
CREATE OR REPLACE VIEW v_hotels_full AS
SELECT 
    h.hotel_id,
    h.name AS hotel_name,
    h.address,
    h.city,
    h.country,
    h.phone,
    h.email,
    h.star_rating,
    h.description,
    h.is_active,
    u.first_name || ' ' || u.last_name AS admin_name,
    u.email AS admin_email,
    COUNT(DISTINCT r.room_id) AS total_rooms,
    COALESCE(ROUND(AVG(rev.rating)::numeric, 2), 0) AS average_rating,
    COUNT(DISTINCT rev.review_id) AS reviews_count
FROM hotels h
LEFT JOIN users u ON h.admin_id = u.user_id
LEFT JOIN rooms r ON h.hotel_id = r.hotel_id
LEFT JOIN reviews rev ON h.hotel_id = rev.hotel_id
GROUP BY h.hotel_id, h.name, h.address, h.city, h.country, h.phone, 
         h.email, h.star_rating, h.description, h.is_active, u.first_name, u.last_name, u.email;

COMMENT ON VIEW v_hotels_full IS 'Полная информация об отелях с рейтингами и количеством номеров';

-- ============================================
-- Представление: Номера с полной информацией
-- ============================================
CREATE OR REPLACE VIEW v_rooms_full AS
SELECT 
    r.room_id,
    r.hotel_id,
    h.name AS hotel_name,
    h.city,
    r.room_number,
    r.floor,
    rt.type_name,
    rt.description AS room_type_description,
    COALESCE(r.price_per_night, rt.price_per_night) AS price_per_night,
    rt.max_occupancy,
    r.is_available,
    r.description AS room_description,
    STRING_AGG(a.amenity_name, ', ' ORDER BY a.amenity_name) AS amenities
FROM rooms r
INNER JOIN hotels h ON r.hotel_id = h.hotel_id
INNER JOIN roomtypes rt ON r.roomtype_id = rt.roomtype_id
LEFT JOIN room_amenities ra ON r.room_id = ra.room_id
LEFT JOIN amenities a ON ra.amenity_id = a.amenity_id
GROUP BY r.room_id, r.hotel_id, h.name, h.city, r.room_number, r.floor,
         rt.type_name, rt.description, r.price_per_night, rt.price_per_night,
         rt.max_occupancy, r.is_available, r.description;

COMMENT ON VIEW v_rooms_full IS 'Полная информация о номерах с удобствами';

-- ============================================
-- Представление: Активные бронирования
-- ============================================
CREATE OR REPLACE VIEW v_active_bookings AS
SELECT 
    b.booking_id,
    b.check_in_date,
    b.check_out_date,
    b.status,
    b.total_price,
    b.guests_count,
    b.booking_date,
    u.first_name || ' ' || u.last_name AS guest_name,
    u.email AS guest_email,
    u.phone AS guest_phone,
    h.name AS hotel_name,
    h.city,
    r.room_number,
    rt.type_name AS room_type,
    (b.check_out_date - b.check_in_date) AS nights
FROM bookings b
INNER JOIN users u ON b.user_id = u.user_id
INNER JOIN rooms r ON b.room_id = r.room_id
INNER JOIN hotels h ON r.hotel_id = h.hotel_id
INNER JOIN roomtypes rt ON r.roomtype_id = rt.roomtype_id
WHERE b.status NOT IN ('cancelled')
ORDER BY b.check_in_date DESC;

COMMENT ON VIEW v_active_bookings IS 'Активные (неотмененные) бронирования с полной информацией';

-- ============================================
-- Представление: Текущие проживания
-- ============================================
CREATE OR REPLACE VIEW v_current_stays AS
SELECT 
    b.booking_id,
    u.first_name || ' ' || u.last_name AS guest_name,
    u.email AS guest_email,
    h.name AS hotel_name,
    r.room_number,
    b.check_in_date,
    b.check_out_date,
    (CURRENT_DATE - b.check_in_date) AS days_stayed,
    (b.check_out_date - CURRENT_DATE) AS days_remaining,
    b.total_price
FROM bookings b
INNER JOIN users u ON b.user_id = u.user_id
INNER JOIN rooms r ON b.room_id = r.room_id
INNER JOIN hotels h ON r.hotel_id = h.hotel_id
WHERE b.status = 'confirmed'
    AND b.check_in_date <= CURRENT_DATE
    AND b.check_out_date > CURRENT_DATE;

COMMENT ON VIEW v_current_stays IS 'Текущие проживающие гости';

-- ============================================
-- Представление: Отзывы с полной информацией
-- ============================================
CREATE OR REPLACE VIEW v_reviews_full AS
SELECT 
    r.review_id,
    r.booking_id,
    r.rating,
    r.comment,
    r.review_date,
    u.first_name || ' ' || u.last_name AS guest_name,
    h.hotel_id,
    h.name AS hotel_name,
    h.city,
    rm.room_number,
    rt.type_name AS room_type
FROM reviews r
INNER JOIN users u ON r.user_id = u.user_id
INNER JOIN bookings b ON r.booking_id = b.booking_id
INNER JOIN rooms rm ON b.room_id = rm.room_id
INNER JOIN hotels h ON rm.hotel_id = h.hotel_id
INNER JOIN roomtypes rt ON rm.roomtype_id = rt.roomtype_id
ORDER BY r.review_date DESC;

COMMENT ON VIEW v_reviews_full IS 'Отзывы с полной информацией о госте и отеле';

-- ============================================
-- Представление: Статистика по отелям
-- ============================================
CREATE OR REPLACE VIEW v_hotel_statistics AS
SELECT 
    h.hotel_id,
    h.name AS hotel_name,
    h.city,
    h.star_rating,
    COUNT(DISTINCT r.room_id) AS total_rooms,
    COUNT(DISTINCT CASE WHEN r.is_available THEN r.room_id END) AS available_rooms,
    COUNT(DISTINCT b.booking_id) AS total_bookings,
    COUNT(DISTINCT CASE WHEN b.status = 'confirmed' THEN b.booking_id END) AS confirmed_bookings,
    COUNT(DISTINCT CASE WHEN b.status = 'cancelled' THEN b.booking_id END) AS cancelled_bookings,
    COALESCE(SUM(CASE WHEN b.status NOT IN ('cancelled') THEN b.total_price END), 0) AS total_revenue,
    COALESCE(ROUND(AVG(rev.rating)::numeric, 2), 0) AS average_rating,
    COUNT(DISTINCT rev.review_id) AS reviews_count
FROM hotels h
LEFT JOIN rooms r ON h.hotel_id = r.hotel_id
LEFT JOIN bookings b ON r.room_id = b.room_id
LEFT JOIN reviews rev ON b.booking_id = rev.booking_id
GROUP BY h.hotel_id, h.name, h.city, h.star_rating;

COMMENT ON VIEW v_hotel_statistics IS 'Статистика по отелям: номера, бронирования, доход, рейтинг';

-- ============================================
-- Представление: Загрузка номеров
-- ============================================
CREATE OR REPLACE VIEW v_room_occupancy AS
SELECT 
    r.room_id,
    h.name AS hotel_name,
    r.room_number,
    rt.type_name,
    COALESCE(r.price_per_night, rt.price_per_night) AS price_per_night,
    r.is_available,
    COUNT(b.booking_id) AS total_bookings,
    COUNT(CASE WHEN b.check_in_date <= CURRENT_DATE 
               AND b.check_out_date > CURRENT_DATE 
               AND b.status = 'confirmed' 
          THEN 1 END) AS currently_occupied,
    MAX(b.check_out_date) AS last_checkout_date
FROM rooms r
INNER JOIN hotels h ON r.hotel_id = h.hotel_id
INNER JOIN roomtypes rt ON r.roomtype_id = rt.roomtype_id
LEFT JOIN bookings b ON r.room_id = b.room_id AND b.status NOT IN ('cancelled')
GROUP BY r.room_id, h.name, r.room_number, rt.type_name, r.price_per_night, rt.price_per_night, r.is_available;

COMMENT ON VIEW v_room_occupancy IS 'Загрузка номеров и статус занятости';

-- ============================================
-- Представление: Пользователи с ролями
-- ============================================
CREATE OR REPLACE VIEW v_users_info AS
SELECT 
    u.user_id,
    u.email,
    u.first_name || ' ' || u.last_name AS full_name,
    u.first_name,
    u.last_name,
    u.phone,
    u.role,
    u.is_active,
    u.created_at,
    CASE u.role
        WHEN 'guest' THEN 'Гость'
        WHEN 'hotel_admin' THEN 'Администратор отеля'
        WHEN 'system_admin' THEN 'Системный администратор'
    END AS role_display,
    COUNT(DISTINCT b.booking_id) AS total_bookings,
    COUNT(DISTINCT r.review_id) AS total_reviews,
    h.name AS managed_hotel
FROM users u
LEFT JOIN bookings b ON u.user_id = b.user_id
LEFT JOIN reviews r ON u.user_id = r.user_id
LEFT JOIN hotels h ON u.user_id = h.admin_id
GROUP BY u.user_id, u.email, u.first_name, u.last_name, u.phone, 
         u.role, u.is_active, u.created_at, h.name;

COMMENT ON VIEW v_users_info IS 'Информация о пользователях с количеством бронирований и отзывов';

-- ============================================
-- Представление: Доступные номера на сегодня
-- ============================================
CREATE OR REPLACE VIEW v_available_rooms_today AS
SELECT 
    r.room_id,
    h.hotel_id,
    h.name AS hotel_name,
    h.city,
    r.room_number,
    rt.type_name,
    COALESCE(r.price_per_night, rt.price_per_night) AS price_per_night,
    rt.max_occupancy,
    STRING_AGG(a.amenity_name, ', ') AS amenities
FROM rooms r
INNER JOIN hotels h ON r.hotel_id = h.hotel_id AND h.is_active = TRUE
INNER JOIN roomtypes rt ON r.roomtype_id = rt.roomtype_id
LEFT JOIN room_amenities ra ON r.room_id = ra.room_id
LEFT JOIN amenities a ON ra.amenity_id = a.amenity_id
WHERE r.is_available = TRUE
    AND NOT EXISTS (
        SELECT 1 FROM bookings b
        WHERE b.room_id = r.room_id
            AND b.status NOT IN ('cancelled')
            AND b.check_in_date <= CURRENT_DATE
            AND b.check_out_date > CURRENT_DATE
    )
GROUP BY r.room_id, h.hotel_id, h.name, h.city, r.room_number, 
         rt.type_name, r.price_per_night, rt.price_per_night, rt.max_occupancy;

COMMENT ON VIEW v_available_rooms_today IS 'Номера, доступные для бронирования на сегодня';
>>>>>>> main
