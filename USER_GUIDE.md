# Руководство по использованию системы бронирования отелей

## Роли пользователей и их функционал

### 1. Гость (Guest)

#### Доступный функционал:
- ✅ Регистрация и авторизация
- ✅ Просмотр списка отелей
- ✅ Просмотр доступных номеров
- ✅ Фильтрация номеров по типу, цене и дате
- ✅ Создание бронирования
- ✅ Просмотр своих бронирований с фильтрами
- ✅ Отмена бронирования (до даты заезда)
- ✅ Добавление отзыва после завершенного проживания

#### Тестовые данные:
```
Email: ivan.petrov@mail.ru
Password: guest123
```

#### API эндпоинты:
```bash
# Авторизация
POST /api/v1/auth/login
Body: username=ivan.petrov@mail.ru&password=guest123

# Просмотр отелей
GET /api/v1/hotels/

# Просмотр номеров отеля
GET /api/v1/rooms/hotel/{hotel_id}

# Создание бронирования
POST /api/v1/bookings/
Body: {
  "room_id": 2,
  "check_in_date": "2025-12-25",
  "check_out_date": "2025-12-30",
  "guests_count": 2
}

# Просмотр своих бронирований
GET /api/v1/bookings/my

# Фильтрация по статусу
GET /api/v1/bookings/my?status=confirmed

# Отмена бронирования
DELETE /api/v1/bookings/{booking_id}

# Добавление отзыва
POST /api/v1/reviews/
Body: {
  "hotel_id": 1,
  "rating": 5,
  "comment": "Отличный отель!"
}
```

---

### 2. Администратор отеля (Hotel Admin)

#### Доступный функционал:
- ✅ Управление номерами своего отеля
  - Добавление номеров
  - Редактирование номеров
  - Удаление номеров
- ✅ Управление типами номеров
  - Создание типов
  - Редактирование типов
  - Удаление типов
- ✅ Управление удобствами номеров
  - Назначение удобств
  - Удаление удобств
- ✅ Просмотр всех бронирований по отелю
- ✅ Изменение статусов бронирований
- ✅ Формирование отчетов
  - Отчет по загрузке номеров
  - Отчет по бронированиям
  - Экспорт в CSV

#### Тестовые данные:
```
Email: admin.plaza@hotel.ru
Password: admin123
```

#### API эндпоинты:
```bash
# Создание номера
POST /api/v1/rooms/
Body: {
  "hotel_id": 1,
  "roomtype_id": 1,
  "room_number": "101",
  "floor": 1,
  "price_per_night": 5000,
  "is_available": true,
  "description": "Уютный номер с видом на город",
  "amenity_ids": [1, 2, 3]
}

# Редактирование номера
PUT /api/v1/rooms/{room_id}
Body: {
  "price_per_night": 5500,
  "is_available": false
}

# Удаление номера
DELETE /api/v1/rooms/{room_id}

# Создание типа номера
POST /api/v1/roomtypes/
Body: {
  "type_name": "Люкс",
  "description": "Роскошный номер",
  "max_occupancy": 4,
  "price_per_night": 15000
}

# Просмотр бронирований отеля
GET /api/v1/bookings/hotel/{hotel_id}/all

# Фильтрация по статусу
GET /api/v1/bookings/hotel/{hotel_id}/all?status=confirmed

# Изменение статуса бронирования
PUT /api/v1/bookings/{booking_id}
Body: {
  "status": "checked_in"
}

# Отчет по загрузке номеров
GET /api/v1/reports/room-occupancy?hotel_id=1&start_date=2025-01-01&end_date=2025-12-31

# Отчет по бронированиям
GET /api/v1/reports/bookings?hotel_id=1&status=confirmed

# Экспорт в CSV
GET /api/v1/reports/bookings/export?hotel_id=1
```

---

### 3. Системный администратор (System Admin)

#### Доступный функционал:
- ✅ Управление пользователями
  - Просмотр всех пользователей
  - Создание пользователей
  - Блокировка/разблокировка
  - Назначение ролей
  - Удаление пользователей
- ✅ Управление отелями
  - Добавление отелей
  - Редактирование отелей
  - Удаление отелей
- ✅ Управление удобствами
  - Добавление удобств
  - Редактирование удобств
  - Удаление удобств
- ✅ Просмотр всех отчетов системы

#### Тестовые данные:
```
Email: admin@hotel.com
Password: admin123
```

#### API эндпоинты:
```bash
# Просмотр всех пользователей
GET /api/v1/users/

# Создание пользователя
POST /api/v1/users/
Body: {
  "email": "newuser@example.com",
  "password": "password123",
  "first_name": "Иван",
  "last_name": "Иванов",
  "phone": "+7-999-123-4567",
  "role": "guest"
}

# Блокировка пользователя
POST /api/v1/users/{user_id}/block

# Разблокировка пользователя
POST /api/v1/users/{user_id}/unblock

# Изменение роли
PATCH /api/v1/users/{user_id}/role?role=hotel_admin

# Создание отеля
POST /api/v1/hotels/
Body: {
  "name": "Новый отель",
  "address": "ул. Примерная, 1",
  "city": "Москва",
  "country": "Россия",
  "phone": "+7-495-123-4567",
  "email": "info@newhotel.ru",
  "star_rating": 4,
  "description": "Современный отель в центре города"
}

# Редактирование отеля
PATCH /api/v1/hotels/{hotel_id}
Body: {
  "star_rating": 5,
  "description": "Обновленное описание"
}

# Удаление отеля
DELETE /api/v1/hotels/{hotel_id}

# Создание удобства
POST /api/v1/amenities/
Body: {
  "amenity_name": "Джакузи",
  "description": "Ванна с гидромассажем"
}

# Назначение удобства номеру
POST /api/v1/amenities/room/{room_id}/amenity/{amenity_id}

# Просмотр всех отчетов
GET /api/v1/reports/bookings
GET /api/v1/reports/room-occupancy
```

---

## Статусы бронирований

- **pending** - Ожидает подтверждения
- **confirmed** - Подтверждено
- **checked_in** - Заселен
- **checked_out** - Выселен
- **cancelled** - Отменено

---

## Работа с фронтендом

### Страница бронирований (my-bookings.html)

#### Функции:
1. **Просмотр бронирований** - Все ваши бронирования с полной информацией
2. **Фильтрация** - По статусу бронирования
3. **Сортировка** - По дате создания или дате заезда
4. **Статистика** - Общее количество, подтвержденные, ожидающие, сумма
5. **Отмена бронирования** - Для подтвержденных бронирований до даты заезда
6. **Оставить отзыв** - После выселения

#### Использование:
1. Авторизуйтесь на главной странице
2. Перейдите в "Мои бронирования"
3. Используйте фильтры для поиска нужных бронирований
4. Нажмите "Подробнее" для детальной информации
5. Используйте "Отменить" для отмены (если доступно)
6. Оставьте отзыв после выселения

---

## Запуск системы

### Backend:
```bash
cd backend
source venv/bin/activate  # или venv\Scripts\activate на Windows
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API документация доступна по адресу: http://localhost:8000/docs

### Frontend:
Откройте `index.html` в браузере или используйте локальный сервер:
```bash
cd frontend
python -m http.server 8080
```

Затем откройте http://localhost:8080

---

## Примеры использования

### Создание нового бронирования (Guest):
```bash
# 1. Авторизация
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=ivan.petrov@mail.ru&password=guest123" | \
  python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

# 2. Просмотр доступных номеров
curl -s "http://localhost:8000/api/v1/rooms/hotel/1?available_from=2025-12-20&available_to=2025-12-25"

# 3. Создание бронирования
curl -X POST http://localhost:8000/api/v1/bookings/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "room_id": 1,
    "check_in_date": "2025-12-20",
    "check_out_date": "2025-12-25",
    "guests_count": 2
  }'
```

### Получение отчета (Hotel Admin):
```bash
# Авторизация
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin.plaza@hotel.ru&password=admin123" | \
  python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

# Отчет по загрузке
curl -s "http://localhost:8000/api/v1/reports/room-occupancy?hotel_id=1&start_date=2025-01-01&end_date=2025-12-31" \
  -H "Authorization: Bearer $TOKEN"

# Экспорт в CSV
curl -s "http://localhost:8000/api/v1/reports/bookings/export?hotel_id=1" \
  -H "Authorization: Bearer $TOKEN" > bookings_report.csv
```

---

## Troubleshooting

### Проблема: "Не удалось загрузить бронирования"
**Решение**: Проверьте, что backend запущен на порту 8000

### Проблема: "Unauthorized"
**Решение**: Обновите токен авторизации

### Проблема: "Room already booked"
**Решение**: Выберите другие даты или другой номер

---

## Структура проекта

```
КП_БД/
├── backend/
│   ├── app/
│   │   ├── api/v1/          # API эндпоинты
│   │   │   ├── auth.py      # Авторизация
│   │   │   ├── users.py     # Пользователи
│   │   │   ├── hotels.py    # Отели
│   │   │   ├── rooms.py     # Номера
│   │   │   ├── roomtypes.py # Типы номеров
│   │   │   ├── amenities.py # Удобства
│   │   │   ├── bookings.py  # Бронирования
│   │   │   ├── reviews.py   # Отзывы
│   │   │   └── reports.py   # Отчеты
│   │   ├── core/            # Конфигурация и БД
│   │   ├── models/          # SQLAlchemy модели
│   │   └── schemas/         # Pydantic схемы
│   └── requirements.txt
├── database/
│   └── *.sql               # SQL скрипты
└── frontend/
    ├── index.html          # Главная страница
    ├── my-bookings.html    # Страница бронирований
    ├── css/
    └── js/
```

---

Система полностью готова к использованию! 🎉
