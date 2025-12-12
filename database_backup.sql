--
-- PostgreSQL database dump
--

\restrict GBmXa2hkQGQeekj9P6jsKRhEkmmnTVz9WbDMOLcREbMJfaQD8hyv7k4iBBrUhg1

-- Dumped from database version 18.0
-- Dumped by pg_dump version 18.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
-- SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_role AS ENUM (
    'guest',
    'hotel_admin',
    'system_admin'
);


ALTER TYPE public.user_role OWNER TO postgres;

--
-- Name: calculate_booking_price(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_booking_price(p_room_id integer, p_check_in date, p_check_out date) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.calculate_booking_price(p_room_id integer, p_check_in date, p_check_out date) OWNER TO postgres;

--
-- Name: FUNCTION calculate_booking_price(p_room_id integer, p_check_in date, p_check_out date); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.calculate_booking_price(p_room_id integer, p_check_in date, p_check_out date) IS 'Рассчитывает общую стоимость бронирования на основе цены номера и количества ночей';


--
-- Name: calculate_total_price_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_total_price_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.calculate_total_price_trigger() OWNER TO postgres;

--
-- Name: can_add_review(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.can_add_review(p_user_id integer, p_booking_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.can_add_review(p_user_id integer, p_booking_id integer) OWNER TO postgres;

--
-- Name: FUNCTION can_add_review(p_user_id integer, p_booking_id integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.can_add_review(p_user_id integer, p_booking_id integer) IS 'Проверяет, может ли пользователь добавить отзыв к бронированию';


--
-- Name: cancel_expired_bookings(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.cancel_expired_bookings()
    LANGUAGE plpgsql
    AS $$
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


ALTER PROCEDURE public.cancel_expired_bookings() OWNER TO postgres;

--
-- Name: PROCEDURE cancel_expired_bookings(); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON PROCEDURE public.cancel_expired_bookings() IS 'Автоматически отменяет бронирования с истекшим сроком';


--
-- Name: check_booking_availability(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_booking_availability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.check_booking_availability() OWNER TO postgres;

--
-- Name: check_room_availability(integer, date, date, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_room_availability(p_room_id integer, p_check_in date, p_check_out date, p_exclude_booking_id integer DEFAULT NULL::integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.check_room_availability(p_room_id integer, p_check_in date, p_check_out date, p_exclude_booking_id integer) OWNER TO postgres;

--
-- Name: FUNCTION check_room_availability(p_room_id integer, p_check_in date, p_check_out date, p_exclude_booking_id integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.check_room_availability(p_room_id integer, p_check_in date, p_check_out date, p_exclude_booking_id integer) IS 'Проверяет доступность номера в указанный период';


--
-- Name: get_available_rooms(integer, date, date, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_available_rooms(p_hotel_id integer, p_check_in date, p_check_out date, p_guests_count integer DEFAULT 1) RETURNS TABLE(room_id integer, room_number character varying, type_name character varying, price_per_night numeric, max_occupancy integer, total_price numeric)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_available_rooms(p_hotel_id integer, p_check_in date, p_check_out date, p_guests_count integer) OWNER TO postgres;

--
-- Name: FUNCTION get_available_rooms(p_hotel_id integer, p_check_in date, p_check_out date, p_guests_count integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.get_available_rooms(p_hotel_id integer, p_check_in date, p_check_out date, p_guests_count integer) IS 'Возвращает список доступных номеров отеля в указанный период';


--
-- Name: get_hotel_average_rating(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_hotel_average_rating(p_hotel_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_avg_rating DECIMAL(3, 2);
BEGIN
    SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0)
    INTO v_avg_rating
    FROM reviews
    WHERE hotel_id = p_hotel_id AND is_approved = TRUE;
    
    RETURN v_avg_rating;
END;
$$;


ALTER FUNCTION public.get_hotel_average_rating(p_hotel_id integer) OWNER TO postgres;

--
-- Name: FUNCTION get_hotel_average_rating(p_hotel_id integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.get_hotel_average_rating(p_hotel_id integer) IS 'Возвращает средний рейтинг отеля на основе одобренных отзывов';


--
-- Name: get_hotel_occupancy_stats(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_hotel_occupancy_stats(p_hotel_id integer, p_start_date date, p_end_date date) RETURNS TABLE(total_rooms bigint, booked_rooms bigint, available_rooms bigint, occupancy_rate numeric)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_hotel_occupancy_stats(p_hotel_id integer, p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: FUNCTION get_hotel_occupancy_stats(p_hotel_id integer, p_start_date date, p_end_date date); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.get_hotel_occupancy_stats(p_hotel_id integer, p_start_date date, p_end_date date) IS 'Статистика загрузки отеля за период';


--
-- Name: log_booking_status_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_booking_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO booking_status_log (booking_id, old_status, new_status, changed_at)
        VALUES (NEW.booking_id, OLD.status, NEW.status, CURRENT_TIMESTAMP);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_booking_status_change() OWNER TO postgres;

--
-- Name: set_booking_date(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_booking_date() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.booking_date IS NULL THEN
        NEW.booking_date := CURRENT_TIMESTAMP;
    END IF;
    
    IF NEW.created_at IS NULL THEN
        NEW.created_at := CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_booking_date() OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

--
-- Name: validate_review_rights(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_review_rights() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.validate_review_rights() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: amenities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.amenities (
    amenity_id integer NOT NULL,
    amenity_name character varying(255),
    description text,
    icon character varying(50),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.amenities OWNER TO postgres;

--
-- Name: amenities_amenity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.amenities_amenity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.amenities_amenity_id_seq OWNER TO postgres;

--
-- Name: amenities_amenity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.amenities_amenity_id_seq OWNED BY public.amenities.amenity_id;


--
-- Name: booking_status_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.booking_status_log (
    log_id integer NOT NULL,
    booking_id integer NOT NULL,
    old_status character varying(20),
    new_status character varying(20),
    changed_by integer,
    changed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.booking_status_log OWNER TO postgres;

--
-- Name: TABLE booking_status_log; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.booking_status_log IS 'Журнал изменений статусов бронирований';


--
-- Name: booking_status_log_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.booking_status_log_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.booking_status_log_log_id_seq OWNER TO postgres;

--
-- Name: booking_status_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.booking_status_log_log_id_seq OWNED BY public.booking_status_log.log_id;


--
-- Name: bookings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bookings (
    booking_id integer NOT NULL,
    guest_id integer,
    room_id integer,
    check_in_date date,
    check_out_date date,
    booking_date timestamp without time zone,
    total_price numeric(10,2),
    status character varying(20),
    user_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    guests_count integer DEFAULT 1,
    CONSTRAINT bookings_guests_count_check CHECK ((guests_count > 0))
);


ALTER TABLE public.bookings OWNER TO postgres;

--
-- Name: COLUMN bookings.user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.bookings.user_id IS 'Пользователь из новой системы аутентификации';


--
-- Name: bookings_booking_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bookings_booking_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bookings_booking_id_seq OWNER TO postgres;

--
-- Name: bookings_booking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bookings_booking_id_seq OWNED BY public.bookings.booking_id;


--
-- Name: guests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.guests (
    guest_id integer NOT NULL,
    first_name character varying(100),
    last_name character varying(100),
    email character varying(255),
    phone character varying(20),
    date_of_birth date,
    registration_date timestamp without time zone
);


ALTER TABLE public.guests OWNER TO postgres;

--
-- Name: guests_guest_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.guests_guest_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.guests_guest_id_seq OWNER TO postgres;

--
-- Name: guests_guest_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.guests_guest_id_seq OWNED BY public.guests.guest_id;


--
-- Name: hotels; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hotels (
    hotel_id integer NOT NULL,
    name character varying(255),
    address character varying(500),
    city character varying(100),
    country character varying(100),
    phone character varying(20),
    email character varying(255),
    star_rating numeric(2,1),
    description text,
    admin_id integer,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.hotels OWNER TO postgres;

--
-- Name: COLUMN hotels.admin_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.hotels.admin_id IS 'Администратор отеля из таблицы users';


--
-- Name: hotels_hotel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.hotels_hotel_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.hotels_hotel_id_seq OWNER TO postgres;

--
-- Name: hotels_hotel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.hotels_hotel_id_seq OWNED BY public.hotels.hotel_id;


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reviews (
    review_id integer NOT NULL,
    booking_id integer,
    rating integer,
    comment text,
    review_date timestamp without time zone,
    user_id integer,
    hotel_id integer,
    is_approved boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.reviews OWNER TO postgres;

--
-- Name: COLUMN reviews.is_approved; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.reviews.is_approved IS 'Отзыв одобрен администратором отеля';


--
-- Name: reviews_review_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.reviews_review_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.reviews_review_id_seq OWNER TO postgres;

--
-- Name: reviews_review_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.reviews_review_id_seq OWNED BY public.reviews.review_id;


--
-- Name: room_amenities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.room_amenities (
    room_amenity_id integer NOT NULL,
    room_id integer,
    amenity_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.room_amenities OWNER TO postgres;

--
-- Name: room_amenities_room_amenity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.room_amenities_room_amenity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.room_amenities_room_amenity_id_seq OWNER TO postgres;

--
-- Name: room_amenities_room_amenity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.room_amenities_room_amenity_id_seq OWNED BY public.room_amenities.room_amenity_id;


--
-- Name: rooms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rooms (
    room_id integer NOT NULL,
    hotel_id integer,
    roomtype_id integer,
    room_number character varying(10),
    floor integer,
    is_available boolean DEFAULT true,
    description text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_per_night numeric(10,2)
);


ALTER TABLE public.rooms OWNER TO postgres;

--
-- Name: rooms_room_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rooms_room_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rooms_room_id_seq OWNER TO postgres;

--
-- Name: rooms_room_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rooms_room_id_seq OWNED BY public.rooms.room_id;


--
-- Name: roomtypes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roomtypes (
    roomtype_id integer NOT NULL,
    type_name character varying(100),
    description text,
    price_per_night numeric(10,2),
    max_occupancy integer DEFAULT 2,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT roomtypes_max_occupancy_check CHECK ((max_occupancy > 0))
);


ALTER TABLE public.roomtypes OWNER TO postgres;

--
-- Name: roomtypes_roomtype_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.roomtypes_roomtype_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.roomtypes_roomtype_id_seq OWNER TO postgres;

--
-- Name: roomtypes_roomtype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roomtypes_roomtype_id_seq OWNED BY public.roomtypes.roomtype_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id integer NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    phone character varying(20),
    role public.user_role DEFAULT 'guest'::public.user_role NOT NULL,
    is_active boolean DEFAULT true,
    guest_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    hotel_id integer,
    CONSTRAINT email_format CHECK (((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.users IS 'Пользователи системы с аутентификацией и ролями';


--
-- Name: COLUMN users.password_hash; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.users.password_hash IS 'Bcrypt hash пароля (НЕ хранится в открытом виде!)';


--
-- Name: COLUMN users.role; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.users.role IS 'Роль пользователя: guest, hotel_admin, system_admin';


--
-- Name: COLUMN users.guest_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.users.guest_id IS 'Связь со старой таблицей guests для миграции данных';


--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_user_id_seq OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- Name: v_active_bookings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_active_bookings AS
 SELECT b.booking_id,
    b.check_in_date,
    b.check_out_date,
    b.status,
    b.total_price,
    b.guests_count,
    b.booking_date,
    (((u.first_name)::text || ' '::text) || (u.last_name)::text) AS guest_name,
    u.email AS guest_email,
    u.phone AS guest_phone,
    h.name AS hotel_name,
    h.city,
    r.room_number,
    rt.type_name AS room_type,
    (b.check_out_date - b.check_in_date) AS nights
   FROM ((((public.bookings b
     JOIN public.users u ON ((b.user_id = u.user_id)))
     JOIN public.rooms r ON ((b.room_id = r.room_id)))
     JOIN public.hotels h ON ((r.hotel_id = h.hotel_id)))
     JOIN public.roomtypes rt ON ((r.roomtype_id = rt.roomtype_id)))
  WHERE ((b.status)::text <> 'cancelled'::text)
  ORDER BY b.check_in_date DESC;


ALTER VIEW public.v_active_bookings OWNER TO postgres;

--
-- Name: VIEW v_active_bookings; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_active_bookings IS 'Активные (неотмененные) бронирования с полной информацией';


--
-- Name: v_available_rooms_today; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_available_rooms_today AS
 SELECT r.room_id,
    h.hotel_id,
    h.name AS hotel_name,
    h.city,
    r.room_number,
    rt.type_name,
    COALESCE(r.price_per_night, rt.price_per_night) AS price_per_night,
    rt.max_occupancy,
    string_agg((a.amenity_name)::text, ', '::text) AS amenities
   FROM ((((public.rooms r
     JOIN public.hotels h ON (((r.hotel_id = h.hotel_id) AND (h.is_active = true))))
     JOIN public.roomtypes rt ON ((r.roomtype_id = rt.roomtype_id)))
     LEFT JOIN public.room_amenities ra ON ((r.room_id = ra.room_id)))
     LEFT JOIN public.amenities a ON ((ra.amenity_id = a.amenity_id)))
  WHERE ((r.is_available = true) AND (NOT (EXISTS ( SELECT 1
           FROM public.bookings b
          WHERE ((b.room_id = r.room_id) AND ((b.status)::text <> 'cancelled'::text) AND (b.check_in_date <= CURRENT_DATE) AND (b.check_out_date > CURRENT_DATE))))))
  GROUP BY r.room_id, h.hotel_id, h.name, h.city, r.room_number, rt.type_name, r.price_per_night, rt.price_per_night, rt.max_occupancy;


ALTER VIEW public.v_available_rooms_today OWNER TO postgres;

--
-- Name: VIEW v_available_rooms_today; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_available_rooms_today IS 'Номера, доступные для бронирования на сегодня';


--
-- Name: v_current_stays; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_current_stays AS
 SELECT b.booking_id,
    (((u.first_name)::text || ' '::text) || (u.last_name)::text) AS guest_name,
    u.email AS guest_email,
    h.name AS hotel_name,
    r.room_number,
    b.check_in_date,
    b.check_out_date,
    (CURRENT_DATE - b.check_in_date) AS days_stayed,
    (b.check_out_date - CURRENT_DATE) AS days_remaining,
    b.total_price
   FROM (((public.bookings b
     JOIN public.users u ON ((b.user_id = u.user_id)))
     JOIN public.rooms r ON ((b.room_id = r.room_id)))
     JOIN public.hotels h ON ((r.hotel_id = h.hotel_id)))
  WHERE (((b.status)::text = 'confirmed'::text) AND (b.check_in_date <= CURRENT_DATE) AND (b.check_out_date > CURRENT_DATE));


ALTER VIEW public.v_current_stays OWNER TO postgres;

--
-- Name: VIEW v_current_stays; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_current_stays IS 'Текущие проживающие гости';


--
-- Name: v_hotel_statistics; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_hotel_statistics AS
 SELECT h.hotel_id,
    h.name AS hotel_name,
    h.city,
    h.star_rating,
    count(DISTINCT r.room_id) AS total_rooms,
    count(DISTINCT
        CASE
            WHEN r.is_available THEN r.room_id
            ELSE NULL::integer
        END) AS available_rooms,
    count(DISTINCT b.booking_id) AS total_bookings,
    count(DISTINCT
        CASE
            WHEN ((b.status)::text = 'confirmed'::text) THEN b.booking_id
            ELSE NULL::integer
        END) AS confirmed_bookings,
    count(DISTINCT
        CASE
            WHEN ((b.status)::text = 'cancelled'::text) THEN b.booking_id
            ELSE NULL::integer
        END) AS cancelled_bookings,
    COALESCE(sum(
        CASE
            WHEN ((b.status)::text <> 'cancelled'::text) THEN b.total_price
            ELSE NULL::numeric
        END), (0)::numeric) AS total_revenue,
    COALESCE(round(avg(rev.rating), 2), (0)::numeric) AS average_rating,
    count(DISTINCT rev.review_id) AS reviews_count
   FROM (((public.hotels h
     LEFT JOIN public.rooms r ON ((h.hotel_id = r.hotel_id)))
     LEFT JOIN public.bookings b ON ((r.room_id = b.room_id)))
     LEFT JOIN public.reviews rev ON (((h.hotel_id = rev.hotel_id) AND (rev.is_approved = true))))
  GROUP BY h.hotel_id, h.name, h.city, h.star_rating;


ALTER VIEW public.v_hotel_statistics OWNER TO postgres;

--
-- Name: VIEW v_hotel_statistics; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_hotel_statistics IS 'Статистика по отелям: номера, бронирования, доход, рейтинг';


--
-- Name: v_hotels_full; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_hotels_full AS
 SELECT h.hotel_id,
    h.name AS hotel_name,
    h.address,
    h.city,
    h.country,
    h.phone,
    h.email,
    h.star_rating,
    h.description,
    h.is_active,
    (((u.first_name)::text || ' '::text) || (u.last_name)::text) AS admin_name,
    u.email AS admin_email,
    count(DISTINCT r.room_id) AS total_rooms,
    COALESCE(round(avg(rev.rating), 2), (0)::numeric) AS average_rating,
    count(DISTINCT rev.review_id) AS reviews_count
   FROM (((public.hotels h
     LEFT JOIN public.users u ON ((h.admin_id = u.user_id)))
     LEFT JOIN public.rooms r ON ((h.hotel_id = r.hotel_id)))
     LEFT JOIN public.reviews rev ON (((h.hotel_id = rev.hotel_id) AND (rev.is_approved = true))))
  GROUP BY h.hotel_id, h.name, h.address, h.city, h.country, h.phone, h.email, h.star_rating, h.description, h.is_active, u.first_name, u.last_name, u.email;


ALTER VIEW public.v_hotels_full OWNER TO postgres;

--
-- Name: VIEW v_hotels_full; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_hotels_full IS 'Полная информация об отелях с рейтингами и количеством номеров';


--
-- Name: v_reviews_full; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_reviews_full AS
 SELECT r.review_id,
    r.booking_id,
    r.rating,
    r.comment,
    r.review_date,
    r.is_approved,
    (((u.first_name)::text || ' '::text) || (u.last_name)::text) AS guest_name,
    h.hotel_id,
    h.name AS hotel_name,
    h.city,
    rm.room_number,
    rt.type_name AS room_type
   FROM (((((public.reviews r
     JOIN public.users u ON ((r.user_id = u.user_id)))
     JOIN public.hotels h ON ((r.hotel_id = h.hotel_id)))
     JOIN public.bookings b ON ((r.booking_id = b.booking_id)))
     JOIN public.rooms rm ON ((b.room_id = rm.room_id)))
     JOIN public.roomtypes rt ON ((rm.roomtype_id = rt.roomtype_id)))
  ORDER BY r.review_date DESC;


ALTER VIEW public.v_reviews_full OWNER TO postgres;

--
-- Name: VIEW v_reviews_full; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_reviews_full IS 'Отзывы с полной информацией о госте и отеле';


--
-- Name: v_room_occupancy; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_room_occupancy AS
 SELECT r.room_id,
    h.name AS hotel_name,
    r.room_number,
    rt.type_name,
    COALESCE(r.price_per_night, rt.price_per_night) AS price_per_night,
    r.is_available,
    count(b.booking_id) AS total_bookings,
    count(
        CASE
            WHEN ((b.check_in_date <= CURRENT_DATE) AND (b.check_out_date > CURRENT_DATE) AND ((b.status)::text = 'confirmed'::text)) THEN 1
            ELSE NULL::integer
        END) AS currently_occupied,
    max(b.check_out_date) AS last_checkout_date
   FROM (((public.rooms r
     JOIN public.hotels h ON ((r.hotel_id = h.hotel_id)))
     JOIN public.roomtypes rt ON ((r.roomtype_id = rt.roomtype_id)))
     LEFT JOIN public.bookings b ON (((r.room_id = b.room_id) AND ((b.status)::text <> 'cancelled'::text))))
  GROUP BY r.room_id, h.name, r.room_number, rt.type_name, r.price_per_night, rt.price_per_night, r.is_available;


ALTER VIEW public.v_room_occupancy OWNER TO postgres;

--
-- Name: VIEW v_room_occupancy; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_room_occupancy IS 'Загрузка номеров и статус занятости';


--
-- Name: v_rooms_full; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_rooms_full AS
 SELECT r.room_id,
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
    string_agg((a.amenity_name)::text, ', '::text ORDER BY (a.amenity_name)::text) AS amenities
   FROM ((((public.rooms r
     JOIN public.hotels h ON ((r.hotel_id = h.hotel_id)))
     JOIN public.roomtypes rt ON ((r.roomtype_id = rt.roomtype_id)))
     LEFT JOIN public.room_amenities ra ON ((r.room_id = ra.room_id)))
     LEFT JOIN public.amenities a ON ((ra.amenity_id = a.amenity_id)))
  GROUP BY r.room_id, r.hotel_id, h.name, h.city, r.room_number, r.floor, rt.type_name, rt.description, r.price_per_night, rt.price_per_night, rt.max_occupancy, r.is_available, r.description;


ALTER VIEW public.v_rooms_full OWNER TO postgres;

--
-- Name: VIEW v_rooms_full; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_rooms_full IS 'Полная информация о номерах с удобствами';


--
-- Name: v_users_info; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_users_info AS
 SELECT u.user_id,
    u.email,
    (((u.first_name)::text || ' '::text) || (u.last_name)::text) AS full_name,
    u.first_name,
    u.last_name,
    u.phone,
    u.role,
    u.is_active,
    u.created_at,
        CASE u.role
            WHEN 'guest'::public.user_role THEN 'Гость'::text
            WHEN 'hotel_admin'::public.user_role THEN 'Администратор отеля'::text
            WHEN 'system_admin'::public.user_role THEN 'Системный администратор'::text
            ELSE NULL::text
        END AS role_display,
    count(DISTINCT b.booking_id) AS total_bookings,
    count(DISTINCT r.review_id) AS total_reviews,
    h.name AS managed_hotel
   FROM (((public.users u
     LEFT JOIN public.bookings b ON ((u.user_id = b.user_id)))
     LEFT JOIN public.reviews r ON ((u.user_id = r.user_id)))
     LEFT JOIN public.hotels h ON ((u.user_id = h.admin_id)))
  GROUP BY u.user_id, u.email, u.first_name, u.last_name, u.phone, u.role, u.is_active, u.created_at, h.name;


ALTER VIEW public.v_users_info OWNER TO postgres;

--
-- Name: VIEW v_users_info; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_users_info IS 'Информация о пользователях с количеством бронирований и отзывов';


--
-- Name: amenities amenity_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.amenities ALTER COLUMN amenity_id SET DEFAULT nextval('public.amenities_amenity_id_seq'::regclass);


--
-- Name: booking_status_log log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.booking_status_log ALTER COLUMN log_id SET DEFAULT nextval('public.booking_status_log_log_id_seq'::regclass);


--
-- Name: bookings booking_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookings ALTER COLUMN booking_id SET DEFAULT nextval('public.bookings_booking_id_seq'::regclass);


--
-- Name: guests guest_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.guests ALTER COLUMN guest_id SET DEFAULT nextval('public.guests_guest_id_seq'::regclass);


--
-- Name: hotels hotel_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hotels ALTER COLUMN hotel_id SET DEFAULT nextval('public.hotels_hotel_id_seq'::regclass);


--
-- Name: reviews review_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews ALTER COLUMN review_id SET DEFAULT nextval('public.reviews_review_id_seq'::regclass);


--
-- Name: room_amenities room_amenity_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_amenities ALTER COLUMN room_amenity_id SET DEFAULT nextval('public.room_amenities_room_amenity_id_seq'::regclass);


--
-- Name: rooms room_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms ALTER COLUMN room_id SET DEFAULT nextval('public.rooms_room_id_seq'::regclass);


--
-- Name: roomtypes roomtype_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roomtypes ALTER COLUMN roomtype_id SET DEFAULT nextval('public.roomtypes_roomtype_id_seq'::regclass);


--
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- Data for Name: amenities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.amenities (amenity_id, amenity_name, description, icon, created_at) FROM stdin;
1	Бесплатный Wi-Fi	\N	\N	2025-12-11 16:41:06.633158
2	Кондиционер	\N	\N	2025-12-11 16:41:06.633158
3	Телевизор с кабельными каналами	\N	\N	2025-12-11 16:41:06.633158
4	Мини-бар	\N	\N	2025-12-11 16:41:06.633158
5	Сейф	\N	\N	2025-12-11 16:41:06.633158
6	Фен	\N	\N	2025-12-11 16:41:06.633158
7	Халаты и тапочки	\N	\N	2025-12-11 16:41:06.633158
8	Кофемашина	\N	\N	2025-12-11 16:41:06.633158
9	Вид на море	\N	\N	2025-12-11 16:41:06.633158
10	Вид на горы	\N	\N	2025-12-11 16:41:06.633158
11	Балкон	\N	\N	2025-12-11 16:41:06.633158
12	Джакузи	\N	\N	2025-12-11 16:41:06.633158
13	Бассейн	\N	\N	2025-12-11 16:41:06.633158
14	Спа-услуги	\N	\N	2025-12-11 16:41:06.633158
15	Завтрак включен	\N	\N	2025-12-11 16:41:06.633158
16	Smart TV	Умный телевизор	\N	2025-12-11 21:41:05.589063
\.


--
-- Data for Name: booking_status_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.booking_status_log (log_id, booking_id, old_status, new_status, changed_by, changed_at) FROM stdin;
1	1	confirmed	completed	\N	2025-12-12 12:41:54.080739
2	15	pending	confirmed	\N	2025-12-12 14:01:10.732476
3	15	confirmed	checked_in	\N	2025-12-12 14:01:18.25879
4	15	checked_in	completed	\N	2025-12-12 14:01:21.873891
5	14	confirmed	checked_in	\N	2025-12-12 16:44:14.542224
6	19	pending	confirmed	\N	2025-12-12 18:59:51.392367
7	19	confirmed	cancelled	\N	2025-12-12 19:01:08.269311
8	20	pending	confirmed	\N	2025-12-12 19:06:30.123565
9	20	confirmed	cancelled	\N	2025-12-12 19:06:48.250503
\.


--
-- Data for Name: bookings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bookings (booking_id, guest_id, room_id, check_in_date, check_out_date, booking_date, total_price, status, user_id, created_at, updated_at, guests_count) FROM stdin;
2	2	2	2024-01-10	2024-01-12	2024-01-01 14:30:00	11000.00	completed	2	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
3	3	8	2024-02-01	2024-02-07	2024-01-20 16:45:00	51000.00	available	3	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
4	4	12	2024-01-25	2024-01-28	2024-01-15 09:20:00	18000.00	completed	4	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
17	5	13	2024-01-13	2024-01-17	2025-12-11 00:17:00.595092	9000.00	pending	5	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
16	5	7	2024-03-01	2024-03-03	2025-11-29 14:46:44.286829	15000.00	completed	5	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
5	5	3	2024-03-10	2024-03-15	2024-02-28 11:15:00	37500.00	confirmed	5	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
6	6	9	2024-02-14	2024-02-16	2024-02-01 13:40:00	17000.00	cancelled	6	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
7	7	5	2024-01-20	2024-01-25	2024-01-10 15:25:00	125000.00	completed	7	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
8	8	6	2024-02-05	2024-02-10	2024-01-25 12:10:00	37500.00	confirmed	8	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
9	9	7	2024-03-01	2024-03-03	2024-02-20 08:50:00	9000.00	pending	9	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
10	10	10	2024-01-30	2024-02-05	2024-01-18 17:35:00	39000.00	occupied	10	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
11	11	11	2024-02-20	2024-02-25	2024-02-10 14:20:00	27500.00	confirmed	11	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
12	12	13	2024-03-15	2024-03-20	2024-03-01 10:05:00	22500.00	pending	12	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
13	13	14	2024-01-18	2024-01-22	2024-01-08 19:15:00	30000.00	completed	13	2025-12-11 16:41:06.591145	2025-12-11 16:41:06.59179	1
18	\N	2	2025-12-25	2025-12-30	2025-12-11 23:46:48.193384	27500.00	confirmed	1	2025-12-11 23:46:48.193384	2025-12-11 23:46:48.193384	2
1	1	1	2024-01-15	2024-01-20	2024-01-05 10:00:00	60000.00	completed	1	2025-12-11 16:41:06.591145	2025-12-12 12:41:54.080739	1
15	15	16	2024-03-05	2024-03-08	2024-02-25 11:55:00	16500.00	completed	15	2025-12-11 16:41:06.591145	2025-12-12 14:01:21.873891	1
14	14	15	2024-02-08	2024-02-12	2024-01-30 16:40:00	20000.00	checked_in	14	2025-12-11 16:41:06.591145	2025-12-12 16:44:14.542224	1
19	\N	15	2025-12-14	2025-12-16	2025-12-12 18:58:46.432751	800.00	cancelled	24	2025-12-12 18:58:46.432751	2025-12-12 19:01:08.269311	1
20	\N	16	2025-12-14	2025-12-16	2025-12-12 19:05:44.653857	800.00	cancelled	24	2025-12-12 19:05:44.653857	2025-12-12 19:06:48.250503	1
\.


--
-- Data for Name: guests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.guests (guest_id, first_name, last_name, email, phone, date_of_birth, registration_date) FROM stdin;
1	Иван	Петров	ivan.petrov@mail.ru	+79161111111	1985-05-15	2024-01-10 14:30:00
2	Мария	Сидорова	maria.sidorova@gmail.com	+79162222222	1990-08-22	2024-01-12 09:15:00
3	Алексей	Козлов	alex.kozlov@yandex.ru	+79163333333	1978-12-03	2024-01-15 16:45:00
4	Елена	Николаева	elena.nikolaeva@mail.ru	+79164444444	1992-03-18	2024-01-18 11:20:00
5	Дмитрий	Васильев	dmitry.vasilev@gmail.com	+79165555555	1988-07-25	2024-01-20 13:10:00
6	Ольга	Павлова	olga.pavlova@yandex.ru	+79166666666	1995-11-30	2024-01-22 15:35:00
7	Сергей	Морозов	sergey.morozov@mail.ru	+79167777777	1982-02-14	2024-01-25 10:05:00
8	Анна	Волкова	anna.volkova@gmail.com	+79168888888	1991-06-08	2024-01-28 14:50:00
9	Павел	Семенов	pavel.semenov@yandex.ru	+79169999999	1975-09-12	2024-02-01 12:25:00
10	Юлия	Лебедева	yulia.lebedeva@mail.ru	+79161010101	1987-04-05	2024-02-03 17:40:00
11	Артем	Егоров	artem.egorov@gmail.com	+79161111112	1993-10-20	2024-02-05 08:15:00
12	Наталья	Ковалева	natalia.kovaleva@yandex.ru	+79161111113	1980-01-28	2024-02-08 19:30:00
13	Михаил	Орлов	mikhail.orlov@mail.ru	+79161111114	1972-07-17	2024-02-10 11:55:00
14	Виктория	Андреева	victoria.andreeva@gmail.com	+79161111115	1994-12-09	2024-02-12 16:20:00
15	Андрей	Соколов	andrey.sokolov@yandex.ru	+79161111116	1983-03-24	2024-02-15 13:45:00
16	Анна	Иванова	anna@gmail.com	9661552352	2003-09-02	2025-11-29 14:24:03.002013
17	Анна	Романовна	anna@gmail.com	9661552352	2003-09-02	2025-11-29 15:31:10.523312
18	Александр	Воронежцев	voron.alex@gmail.com	+79855523525	2000-04-16	2025-12-10 23:21:22.013407
\.


--
-- Data for Name: hotels; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hotels (hotel_id, name, address, city, country, phone, email, star_rating, description, admin_id, is_active, created_at, updated_at) FROM stdin;
5	Business Inn	Невский пр-т, 100	Санкт-Петербург	Россия	+7-812-555-6677	info@businessinn.spb.ru	3.0	Отель для деловых поездок	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
6	River Side	ул. Баумана, 30	Казань	Россия	+7-843-666-7788	booking@riverside.ru	4.0	Отель с видом на реку	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
7	Historic Manor	ул. Великая, 5	Великий Новгород	Россия	+7-816-777-8899	manor@history.ru	3.0	Отель в историческом здании	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
8	Spa Paradise	ул. Курортная, 20	Анапа	Россия	+7-861-888-9900	spa@paradise.ru	4.0	Спа-отель с лечебными программами	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
9	City Center	ул. Ленина, 75	Екатеринбург	Россия	+7-343-999-0011	reception@citycenter.ru	3.0	Отель в деловом центре города	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
10	Airport Hotel	ул. Авиационная, 10	Калининград	Россия	+7-401-111-2233	airport@hotel.ru	3.0	Удобный отель рядом с аэропортом	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
11	Winter Palace	Дворцовая наб., 38	Санкт-Петербург	Россия	+7-812-222-3344	winter@palace.ru	5.0	Элитный отель с видом на Эрмитаж	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
12	Golden Ring	ул. Свободы, 45	Ярославль	Россия	+7-485-333-4455	golden@ring.ru	3.0	Отель в Золотом кольце России	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
13	Forest Retreat	ул. Лесная, 8	Кострома	Россия	+7-494-444-5566	forest@retreat.ru	4.0	Эко-отель в сосновом бору	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
14	Lakeside Resort	ул. Озерная, 12	Петрозаводск	Россия	+7-814-555-6677	lakeside@resort.ru	4.0	Курорт на берегу озера	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
15	Metropol	Театральный пр-д, 1	Москва	Россия	+7-495-666-7788	info@metropol.ru	5.0	Легендарный отель с богатой историей	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
4	Mountain Lodge	ул. Горная, 15	Красная Поляна	Россия	+7-862-444-5566	lodge@mountain.ru	4.0	Горный отель у подъемников	22	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
31	Нева Палас	Невский проспект, д. 120	Санкт-Петербург	Россия	+7-812-345-67-89	booking@nevapalace.ru	5.0	Исторический отель на главной улице Санкт-Петербурга. Из окон открывается вид на Казанский собор.	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
1	Отель Премиум Москва	ул. Тверская, д. 10	Москва	Россия	+7-495-111-2233	info@grandhotel.ru	5.0	Роскошный пятизвездочный отель в центре Москвы	\N	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
2	Hotel Plaza	ул. Арбат, 25	Москва	Россия	+7-495-222-3344	book@plaza.ru	4.0	Комфортабельный отель в историческом центре	20	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
3	Sea View Resort	ул. Приморская, 50	Сочи	Россия	+7-862-333-4455	resort@seaview.com	4.5	Курортный комплекс с私人 пляжем	21	t	2025-12-11 16:41:06.581905	2025-12-11 16:41:06.584555
32	Test Hotel API	Тестовая улица, 1	Москва	Россия	+7-495-000-0000	test@testhotel.ru	4.0	Тестовый отель	\N	t	2025-12-11 21:41:05.5463	2025-12-11 21:41:05.5463
\.


--
-- Data for Name: reviews; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reviews (review_id, booking_id, rating, comment, review_date, user_id, hotel_id, is_approved, created_at, updated_at) FROM stdin;
2	2	4	Хороший номер за свои деньги, удобное расположение.	2024-01-13 14:30:00	2	1	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
4	4	3	Номер хороший, но балкон оказался меньше чем на фото.	2024-01-29 16:45:00	4	4	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
5	5	4	Отлично для бизнес-поездки, быстрый Wi-Fi.	2024-03-16 09:20:00	5	1	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
7	7	2	За такие деньги ожидали большего, сервис хромает.	2024-01-26 11:10:00	7	2	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
8	8	4	Уютный номер, приветливый персонал.	2024-02-11 15:25:00	8	2	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
9	9	3	Все нормально, но ничего особенного.	2024-03-04 13:40:00	9	2	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
11	11	4	Хорошее соотношение цена/качество.	2024-02-26 14:05:00	11	3	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
12	12	5	Семейный номер просторный, детям понравилось.	2024-03-21 10:50:00	12	4	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
13	13	4	Удобно для деловой поездки, рядом с центром.	2024-01-23 12:35:00	13	4	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
14	14	3	Нормальный отель, но далеко от моря.	2024-02-13 16:20:00	14	5	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
15	15	5	Все понравилось))	2024-03-09 19:45:00	15	5	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
6	6	5	Романтический отпуск удался! Спасибо отелю.	2024-02-17 18:30:00	6	3	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
3	3	5	Незабываемый вид на море! Обязательно вернемся.	2024-02-08 10:15:00	3	3	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
10	10	5	Прекрасное спа, отдохнули великолепно!	2024-02-06 17:55:00	10	3	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
1	1	5	Прекрасный отель, отличный сервис! Люкс оправдал ожидания.	2024-01-21 12:00:00	1	1	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
16	16	2	\N	2024-03-09 00:00:00	5	2	f	2025-12-11 16:41:06.606954	2025-12-11 16:41:06.6075
\.


--
-- Data for Name: room_amenities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.room_amenities (room_amenity_id, room_id, amenity_id, created_at) FROM stdin;
1	1	1	2025-12-11 16:41:06.63369
2	1	2	2025-12-11 16:41:06.63369
3	1	3	2025-12-11 16:41:06.63369
4	1	4	2025-12-11 16:41:06.63369
5	1	5	2025-12-11 16:41:06.63369
6	1	6	2025-12-11 16:41:06.63369
7	1	7	2025-12-11 16:41:06.63369
8	1	8	2025-12-11 16:41:06.63369
9	1	15	2025-12-11 16:41:06.63369
10	2	1	2025-12-11 16:41:06.63369
11	2	2	2025-12-11 16:41:06.63369
12	2	3	2025-12-11 16:41:06.63369
13	2	6	2025-12-11 16:41:06.63369
14	2	15	2025-12-11 16:41:06.63369
15	3	1	2025-12-11 16:41:06.63369
16	3	2	2025-12-11 16:41:06.63369
17	3	3	2025-12-11 16:41:06.63369
18	3	4	2025-12-11 16:41:06.63369
19	3	5	2025-12-11 16:41:06.63369
20	3	6	2025-12-11 16:41:06.63369
21	3	8	2025-12-11 16:41:06.63369
22	3	15	2025-12-11 16:41:06.63369
23	8	1	2025-12-11 16:41:06.63369
24	8	2	2025-12-11 16:41:06.63369
25	8	3	2025-12-11 16:41:06.63369
26	8	6	2025-12-11 16:41:06.63369
27	8	9	2025-12-11 16:41:06.63369
28	8	15	2025-12-11 16:41:06.63369
29	9	1	2025-12-11 16:41:06.63369
30	9	2	2025-12-11 16:41:06.63369
31	9	3	2025-12-11 16:41:06.63369
32	9	6	2025-12-11 16:41:06.63369
33	9	9	2025-12-11 16:41:06.63369
34	9	15	2025-12-11 16:41:06.63369
35	12	1	2025-12-11 16:41:06.63369
36	12	2	2025-12-11 16:41:06.63369
37	12	3	2025-12-11 16:41:06.63369
38	12	6	2025-12-11 16:41:06.63369
39	12	11	2025-12-11 16:41:06.63369
40	4	1	2025-12-11 16:41:06.63369
41	4	2	2025-12-11 16:41:06.63369
42	4	3	2025-12-11 16:41:06.63369
43	4	6	2025-12-11 16:41:06.63369
44	5	1	2025-12-11 16:41:06.63369
45	5	2	2025-12-11 16:41:06.63369
46	5	3	2025-12-11 16:41:06.63369
47	5	4	2025-12-11 16:41:06.63369
48	5	5	2025-12-11 16:41:06.63369
49	6	1	2025-12-11 16:41:06.63369
50	6	2	2025-12-11 16:41:06.63369
51	6	3	2025-12-11 16:41:06.63369
52	7	1	2025-12-11 16:41:06.63369
53	7	2	2025-12-11 16:41:06.63369
54	7	3	2025-12-11 16:41:06.63369
55	10	1	2025-12-11 16:41:06.63369
56	10	2	2025-12-11 16:41:06.63369
57	10	3	2025-12-11 16:41:06.63369
58	11	1	2025-12-11 16:41:06.63369
59	11	2	2025-12-11 16:41:06.63369
60	11	3	2025-12-11 16:41:06.63369
61	13	1	2025-12-11 16:41:06.63369
62	13	2	2025-12-11 16:41:06.63369
63	13	3	2025-12-11 16:41:06.63369
65	14	2	2025-12-11 16:41:06.63369
66	14	3	2025-12-11 16:41:06.63369
70	16	1	2025-12-11 16:41:06.63369
71	16	2	2025-12-11 16:41:06.63369
72	16	3	2025-12-11 16:41:06.63369
73	17	1	2025-12-11 16:41:06.63369
74	17	2	2025-12-11 16:41:06.63369
75	17	3	2025-12-11 16:41:06.63369
76	18	1	2025-12-11 16:41:06.63369
77	18	2	2025-12-11 16:41:06.63369
78	18	3	2025-12-11 16:41:06.63369
79	19	1	2025-12-11 16:41:06.63369
80	19	2	2025-12-11 16:41:06.63369
81	19	3	2025-12-11 16:41:06.63369
83	29	2	2025-12-11 16:41:06.63369
64	30	1	2025-12-11 16:41:06.63369
82	29	1	2025-12-11 16:41:06.63369
84	30	10	2025-12-11 16:41:06.63369
88	15	1	2025-12-12 13:50:13.335457
89	15	2	2025-12-12 13:50:13.335457
90	15	3	2025-12-12 13:50:13.335457
\.


--
-- Data for Name: rooms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rooms (room_id, hotel_id, roomtype_id, room_number, floor, is_available, description, created_at, updated_at, price_per_night) FROM stdin;
1	1	7	101	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	12000.00
2	1	4	102	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	5500.00
3	1	5	201	2	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	400.00
4	1	6	202	2	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	6500.00
5	2	8	301	3	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	25000.00
6	2	5	302	3	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	400.00
7	2	3	401	4	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	4500.00
8	3	9	101	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	8500.00
9	3	9	102	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	8500.00
10	3	6	201	2	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	6500.00
11	3	7	202	2	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	12000.00
12	4	10	101	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	6000.00
13	4	6	102	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	6500.00
14	4	4	201	2	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	5500.00
15	5	5	101	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	400.00
16	5	5	102	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	400.00
17	5	3	201	2	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	4500.00
18	6	4	101	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	5500.00
19	7	7	201	2	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	12000.00
20	8	12	301	3	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	8000.00
21	9	2	101	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	3500.00
22	10	3	201	2	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	4500.00
23	11	8	101	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	25000.00
24	12	4	201	2	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	5500.00
25	13	6	101	1	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	6500.00
26	14	9	201	2	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	8500.00
27	15	5	301	3	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	400.00
28	7	1	28	2	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	2500.00
29	5	9	37	3	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	8500.00
30	5	9	48	4	t	\N	2025-12-11 16:41:06.596952	2025-12-11 18:13:55.153874	8500.00
\.


--
-- Data for Name: roomtypes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roomtypes (roomtype_id, type_name, description, price_per_night, max_occupancy, created_at) FROM stdin;
1	Эконом одноместный	Небольшой уютный номер с одной кроватью	2500.00	2	2025-12-11 16:41:06.634467
2	Эконом двухместный	Номер с двумя отдельными кроватями	3500.00	2	2025-12-11 16:41:06.634467
3	Стандарт одноместный	Комфортабельный номер с двуспальной кроватью	4500.00	2	2025-12-11 16:41:06.634467
4	Стандарт двухместный	Просторный номер с двумя кроватями	5500.00	2	2025-12-11 16:41:06.634467
6	Семейный номер	Большой номер с дополнительной детской кроватью	6500.00	2	2025-12-11 16:41:06.634467
7	Люкс	Роскошный номер с гостиной зоной	12000.00	2	2025-12-11 16:41:06.634467
8	Президентский люкс	Апартаменты высшего класса	25000.00	2	2025-12-11 16:41:06.634467
9	Номер с видом на море	Номер с панорамным видом на море	8500.00	2	2025-12-11 16:41:06.634467
10	Номер с балконом	Номер с собственным балконом	6000.00	2	2025-12-11 16:41:06.634467
11	Джуниор сьют	Улучшенный номер с мини-кухней	9500.00	2	2025-12-11 16:41:06.634467
12	Делюкс	Просторный номер повышенной комфортности	8000.00	2	2025-12-11 16:41:06.634467
13	Апартаменты	Полноценные апартаменты с кухней	15000.00	2	2025-12-11 16:41:06.634467
14	Студия	Номер с совмещенной гостиной и спальней	5000.00	2	2025-12-11 16:41:06.634467
15	Хостел (место)	Койка в общем номере	1500.00	2	2025-12-11 16:41:06.634467
5	Бизнес-класс	Номер для деловых поездок с рабочим столом	400.00	2	2025-12-11 16:41:06.634467
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, email, password_hash, first_name, last_name, phone, role, is_active, guest_id, created_at, updated_at, hotel_id) FROM stdin;
21	admin.seaview@hotel.ru	$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5oDhGx0JqHX3O	Менеджер	Сивью	+7-862-333-4455	hotel_admin	t	\N	2025-12-11 16:41:06.655148	2025-12-11 16:41:06.655148	\N
22	admin.mountain@hotel.ru	$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5oDhGx0JqHX3O	Менеджер	Маунтин	+7-862-444-5566	hotel_admin	t	\N	2025-12-11 16:41:06.655148	2025-12-11 16:41:06.655148	\N
19	admin@hotel.com	$2b$12$Mw9u/da03xoiqzO9ivcK8uhZumbqgpf84wK/GWnBuqugvvjhz51pS	Системный	Администратор	\N	system_admin	t	\N	2025-12-11 16:41:06.653827	2025-12-11 18:08:56.878535	\N
20	admin.plaza@hotel.ru	$2b$12$hRpqH8zRltrIyIgIOIObx.FIWpCfphNoMV81SV/NP38mkNGssz1da	Менеджер	Плаза	+7-495-222-3344	hotel_admin	t	\N	2025-12-11 16:41:06.655148	2025-12-11 18:08:56.985817	\N
23	hotel_admin@hotel.com	$2b$12$Mw9u/da03xoiqzO9ivcK8uhZumbqgpf84wK/GWnBuqugvvjhz51pS	Менеджер	Business	\N	hotel_admin	t	\N	2025-12-12 13:23:19.810999	2025-12-12 13:23:43.692106	5
24	nastya.yes@list.ru	$2b$12$G9IeBnQxBcFeNoPBejqjd.a1xOw4edj7GpPlz91/geo9YDpA4zfcG	Анастасия	Алейникова	+79856967202	guest	t	\N	2025-12-12 18:44:10.495963	2025-12-12 19:21:12.701169	\N
1	ivan.petrov@mail.ru	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Иван	Петров	+79161111111	guest	t	1	2024-01-10 14:30:00	2025-12-11 21:17:11.156011	\N
2	maria.sidorova@gmail.com	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Мария	Сидорова	+79162222222	guest	t	2	2024-01-12 09:15:00	2025-12-11 21:17:11.156011	\N
3	alex.kozlov@yandex.ru	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Алексей	Козлов	+79163333333	guest	t	3	2024-01-15 16:45:00	2025-12-11 21:17:11.156011	\N
4	elena.nikolaeva@mail.ru	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Елена	Николаева	+79164444444	guest	t	4	2024-01-18 11:20:00	2025-12-11 21:17:11.156011	\N
5	dmitry.vasilev@gmail.com	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Дмитрий	Васильев	+79165555555	guest	t	5	2024-01-20 13:10:00	2025-12-11 21:17:11.156011	\N
6	olga.pavlova@yandex.ru	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Ольга	Павлова	+79166666666	guest	t	6	2024-01-22 15:35:00	2025-12-11 21:17:11.156011	\N
7	sergey.morozov@mail.ru	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Сергей	Морозов	+79167777777	guest	t	7	2024-01-25 10:05:00	2025-12-11 21:17:11.156011	\N
8	anna.volkova@gmail.com	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Анна	Волкова	+79168888888	guest	t	8	2024-01-28 14:50:00	2025-12-11 21:17:11.156011	\N
9	pavel.semenov@yandex.ru	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Павел	Семенов	+79169999999	guest	t	9	2024-02-01 12:25:00	2025-12-11 21:17:11.156011	\N
10	yulia.lebedeva@mail.ru	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Юлия	Лебедева	+79161010101	guest	t	10	2024-02-03 17:40:00	2025-12-11 21:17:11.156011	\N
11	artem.egorov@gmail.com	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Артем	Егоров	+79161111112	guest	t	11	2024-02-05 08:15:00	2025-12-11 21:17:11.156011	\N
12	natalia.kovaleva@yandex.ru	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Наталья	Ковалева	+79161111113	guest	t	12	2024-02-08 19:30:00	2025-12-11 21:17:11.156011	\N
13	mikhail.orlov@mail.ru	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Михаил	Орлов	+79161111114	guest	t	13	2024-02-10 11:55:00	2025-12-11 21:17:11.156011	\N
14	victoria.andreeva@gmail.com	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Виктория	Андреева	+79161111115	guest	t	14	2024-02-12 16:20:00	2025-12-11 21:17:11.156011	\N
15	andrey.sokolov@yandex.ru	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Андрей	Соколов	+79161111116	guest	t	15	2024-02-15 13:45:00	2025-12-11 21:17:11.156011	\N
16	anna@gmail.com	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Анна	Иванова	9661552352	guest	t	16	2025-11-29 14:24:03.002013	2025-12-11 21:17:11.156011	\N
18	voron.alex@gmail.com	$2b$12$f6iHODGIzW3UZUtMUvixkeHVSnjo.w/hLU7LZd2j8HPCyu3pTL1Sq	Александр	Воронежцев	+79855523525	guest	t	18	2025-12-10 23:21:22.013407	2025-12-11 21:17:11.156011	\N
\.


--
-- Name: amenities_amenity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.amenities_amenity_id_seq', 16, true);


--
-- Name: booking_status_log_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.booking_status_log_log_id_seq', 9, true);


--
-- Name: bookings_booking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bookings_booking_id_seq', 20, true);


--
-- Name: guests_guest_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.guests_guest_id_seq', 18, true);


--
-- Name: hotels_hotel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.hotels_hotel_id_seq', 32, true);


--
-- Name: reviews_review_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.reviews_review_id_seq', 16, true);


--
-- Name: room_amenities_room_amenity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.room_amenities_room_amenity_id_seq', 90, true);


--
-- Name: rooms_room_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rooms_room_id_seq', 30, true);


--
-- Name: roomtypes_roomtype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roomtypes_roomtype_id_seq', 15, true);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_id_seq', 24, true);


--
-- Name: amenities amenities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.amenities
    ADD CONSTRAINT amenities_pkey PRIMARY KEY (amenity_id);


--
-- Name: booking_status_log booking_status_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.booking_status_log
    ADD CONSTRAINT booking_status_log_pkey PRIMARY KEY (log_id);


--
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (booking_id);


--
-- Name: guests guests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.guests
    ADD CONSTRAINT guests_pkey PRIMARY KEY (guest_id);


--
-- Name: hotels hotels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hotels
    ADD CONSTRAINT hotels_pkey PRIMARY KEY (hotel_id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (review_id);


--
-- Name: room_amenities room_amenities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_amenities
    ADD CONSTRAINT room_amenities_pkey PRIMARY KEY (room_amenity_id);


--
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (room_id);


--
-- Name: roomtypes roomtypes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roomtypes
    ADD CONSTRAINT roomtypes_pkey PRIMARY KEY (roomtype_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: idx_hotels_admin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_hotels_admin ON public.hotels USING btree (admin_id);


--
-- Name: idx_reviews_approved; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reviews_approved ON public.reviews USING btree (is_approved);


--
-- Name: idx_reviews_hotel; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reviews_hotel ON public.reviews USING btree (hotel_id);


--
-- Name: idx_reviews_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reviews_user ON public.reviews USING btree (user_id);


--
-- Name: idx_rooms_available; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_rooms_available ON public.rooms USING btree (is_available);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: idx_users_guest; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_guest ON public.users USING btree (guest_id);


--
-- Name: idx_users_role; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_role ON public.users USING btree (role);


--
-- Name: bookings calculate_booking_price; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER calculate_booking_price BEFORE INSERT OR UPDATE OF room_id, check_in_date, check_out_date ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.calculate_total_price_trigger();


--
-- Name: TRIGGER calculate_booking_price ON bookings; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TRIGGER calculate_booking_price ON public.bookings IS 'Автоматически рассчитывает total_price на основе цены номера и количества ночей';


--
-- Name: bookings check_room_before_booking; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_room_before_booking BEFORE INSERT OR UPDATE OF room_id, check_in_date, check_out_date ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.check_booking_availability();


--
-- Name: TRIGGER check_room_before_booking ON bookings; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TRIGGER check_room_before_booking ON public.bookings IS 'Проверяет доступность номера в указанный период перед созданием/обновлением бронирования';


--
-- Name: bookings log_status_change; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_status_change AFTER UPDATE OF status ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.log_booking_status_change();


--
-- Name: TRIGGER log_status_change ON bookings; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TRIGGER log_status_change ON public.bookings IS 'Логирует все изменения статуса бронирования для аудита';


--
-- Name: bookings set_booking_dates; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_booking_dates BEFORE INSERT ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.set_booking_date();


--
-- Name: bookings update_bookings_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: hotels update_hotels_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_hotels_updated_at BEFORE UPDATE ON public.hotels FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: reviews update_reviews_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: rooms update_rooms_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_rooms_updated_at BEFORE UPDATE ON public.rooms FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: reviews validate_review; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER validate_review BEFORE INSERT ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.validate_review_rights();


--
-- Name: TRIGGER validate_review ON reviews; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TRIGGER validate_review ON public.reviews IS 'Проверяет права пользователя на добавление отзыва';


--
-- Name: booking_status_log booking_status_log_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.booking_status_log
    ADD CONSTRAINT booking_status_log_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.users(user_id);


--
-- Name: bookings bookings_guest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_guest_id_fkey FOREIGN KEY (guest_id) REFERENCES public.guests(guest_id);


--
-- Name: bookings bookings_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(room_id);


--
-- Name: bookings bookings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: hotels hotels_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hotels
    ADD CONSTRAINT hotels_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: reviews reviews_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(booking_id);


--
-- Name: reviews reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: room_amenities room_amenities_amenity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_amenities
    ADD CONSTRAINT room_amenities_amenity_id_fkey FOREIGN KEY (amenity_id) REFERENCES public.amenities(amenity_id);


--
-- Name: room_amenities room_amenities_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room_amenities
    ADD CONSTRAINT room_amenities_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(room_id);


--
-- Name: rooms rooms_hotel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_hotel_id_fkey FOREIGN KEY (hotel_id) REFERENCES public.hotels(hotel_id);


--
-- Name: rooms rooms_roomtype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_roomtype_id_fkey FOREIGN KEY (roomtype_id) REFERENCES public.roomtypes(roomtype_id);


--
-- Name: users users_hotel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_hotel_id_fkey FOREIGN KEY (hotel_id) REFERENCES public.hotels(hotel_id);


--
-- PostgreSQL database dump complete
--

\unrestrict GBmXa2hkQGQeekj9P6jsKRhEkmmnTVz9WbDMOLcREbMJfaQD8hyv7k4iBBrUhg1

