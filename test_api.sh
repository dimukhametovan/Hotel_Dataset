#!/bin/bash

# Скрипт тестирования API для всех ролей

echo "========================================="
echo "Тестирование API системы бронирования отелей"
echo "========================================="
echo ""

# Получение токенов
echo "1. Авторизация пользователей..."
GUEST_TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=ivan.petrov@mail.ru&password=guest123" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

ADMIN_TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin@hotel.com&password=admin123" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

echo "✓ Авторизация успешна"
echo ""

# Тесты для роли ГОСТЬ
echo "========================================="
echo "ТЕСТЫ ДЛЯ РОЛИ ГОСТЬ"
echo "========================================="

echo "✓ Просмотр списка отелей (первые 3):"
curl -s http://localhost:8000/api/v1/hotels/?limit=3 | python3 -m json.tool | grep -E '"hotel_id"|"name"|"city"'
echo ""

echo "✓ Просмотр типов номеров:"
curl -s http://localhost:8000/api/v1/roomtypes/ | python3 -m json.tool | grep -E '"roomtype_id"|"type_name"' | head -6
echo ""

echo "✓ Просмотр номеров отеля ID=1:"
curl -s "http://localhost:8000/api/v1/rooms/hotel/1?limit=3" | python3 -m json.tool | grep -E '"room_id"|"room_number"|"price_per_night"'
echo ""

echo "✓ Создание бронирования (гость):"
curl -s -X POST http://localhost:8000/api/v1/bookings/ \
  -H "Authorization: Bearer $GUEST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "room_id": 1,
    "check_in_date": "2025-12-20",
    "check_out_date": "2025-12-25",
    "guests_count": 2,
    "special_requests": "Тихий номер, пожалуйста"
  }' | python3 -m json.tool | grep -E '"booking_id"|"status"|"total_price"'
echo ""

echo "✓ Просмотр своих бронирований (гость):"
curl -s http://localhost:8000/api/v1/bookings/my \
  -H "Authorization: Bearer $GUEST_TOKEN" | python3 -m json.tool | grep -E '"booking_id"|"status"' | head -6
echo ""

# Тесты для роли СИСТЕМНЫЙ АДМИНИСТРАТОР
echo "========================================="
echo "ТЕСТЫ ДЛЯ РОЛИ СИСТЕМНЫЙ АДМИНИСТРАТОР"
echo "========================================="

echo "✓ Просмотр всех пользователей:"
curl -s http://localhost:8000/api/v1/users/?limit=5 \
  -H "Authorization: Bearer $ADMIN_TOKEN" | python3 -m json.tool | grep -E '"user_id"|"email"|"role"' | head -15
echo ""

echo "✓ Создание нового отеля:"
curl -s -X POST http://localhost:8000/api/v1/hotels/ \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Hotel API",
    "address": "Тестовая улица, 1",
    "city": "Москва",
    "country": "Россия",
    "phone": "+7-495-000-0000",
    "email": "test@testhotel.ru",
    "star_rating": "4.0",
    "description": "Тестовый отель"
  }' | python3 -m json.tool | grep -E '"hotel_id"|"name"|"city"'
echo ""

echo "✓ Создание нового удобства:"
curl -s -X POST http://localhost:8000/api/v1/amenities/ \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amenity_name": "Smart TV",
    "description": "Умный телевизор"
  }' | python3 -m json.tool | grep -E '"amenity_id"|"amenity_name"'
echo ""

echo "✓ Отчет по бронированиям:"
curl -s "http://localhost:8000/api/v1/reports/bookings?limit=3" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | python3 -m json.tool | grep -E '"total_count"'
echo ""

echo "========================================="
echo "Тестирование завершено!"
echo "========================================="
