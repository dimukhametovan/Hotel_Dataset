#!/bin/bash
# Скрипт для создания и настройки базы данных hotel

echo "🚀 Настройка базы данных hotel..."
echo ""

# Проверяем, существует ли база данных hotel
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw hotel; then
    echo "⚠️  База данных 'hotel' уже существует. Пересоздаём..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS hotel;" -q
fi

echo "1️⃣ Создание базы данных 'hotel'..."
sudo -u postgres psql -c "CREATE DATABASE hotel;" -q
echo "✅ База данных создана"
echo ""

echo "2️⃣ Создание схемы (таблицы, связи, индексы)..."
sudo -u postgres psql -d hotel -f database/init_schema.sql -q
echo "✅ Схема создана"
echo ""

echo "3️⃣ Применение миграции (добавление users, ролей, хешей паролей)..."
sudo -u postgres psql -d hotel -f database/01_migration_add_users.sql -q
echo "✅ Миграция выполнена"
echo ""

echo "4️⃣ Создание триггеров (автоматический расчет цен, проверки)..."
sudo -u postgres psql -d hotel -f database/02_triggers.sql -q
echo "✅ Триггеры созданы"
echo ""

echo "5️⃣ Создание представлений (views для выборок)..."
sudo -u postgres psql -d hotel -f database/03_views.sql -q
echo "✅ Представления созданы"
echo ""

echo "6️⃣ Создание функций (поиск номеров, отчеты, статистика)..."
sudo -u postgres psql -d hotel -f database/04_functions.sql -q
echo "✅ Функции созданы"
echo ""

echo "7️⃣ Вставка тестовых данных (отели, номера, пользователи, брони)..."
sudo -u postgres psql -d hotel -f database/05_test_data.sql -q
echo "✅ Тестовые данные добавлены"
echo ""

echo "🎉 База данных полностью настроена и готова к работе!"
echo ""
echo "📋 Тестовые пользователи:"
echo "   Системный админ: admin@hotel.com / admin123"
echo "   Админ отеля: admin.plaza@hotel.ru / hotel123"
echo "   Гости: используйте email из вашей таблицы guests / password123"