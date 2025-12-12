# test_connection_detailed.py
import asyncpg
import asyncio
import socket
import sys
from dotenv import load_dotenv
import os

load_dotenv()

async def test_postgresql_directly():
    """Тест прямого подключения к PostgreSQL"""
    print("🔍 Тест 1: Проверка порта 5432 в Windows...")
    
    # Проверяем, слушает ли что-то порт 5432 в Windows
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)
    result = sock.connect_ex(('localhost', 5432))
    sock.close()
    
    if result == 0:
        print("✅ Порт 5432 открыт в Windows")
    else:
        print("❌ Порт 5432 закрыт в Windows")
        print("   SSH туннель не активен или DBeaver не подключен")
        return False
    
    print("\n🔍 Тест 2: Подключение к PostgreSQL...")
    
    try:
        conn = await asyncpg.connect(
            host='172.30.219.23',
            port=5432,
            user='postgres',
            password='123456',  # замените на ваш пароль
            database='hotel_booking',
            timeout=10
        )
        
        print("✅ PostgreSQL подключение успешно!")
        
        # Тестируем простой запрос
        print("\n🔍 Тест 3: Выполнение запроса...")
        version = await conn.fetchval("SELECT version();")
        print(f"📦 Версия PostgreSQL: {version.split(',')[0]}")
        
        # Проверяем таблицы
        tables = await conn.fetch("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            ORDER BY table_name
            LIMIT 5
        """)
        
        print(f"📊 Найдено таблиц (первые 5):")
        for table in tables:
            print(f"   - {table['table_name']}")
        
        await conn.close()
        return True
        
    except asyncpg.InvalidPasswordError:
        print("❌ Неправильный пароль PostgreSQL")
        print("   Запустите в WSL: sudo -u postgres psql -c \"\password postgres\"")
        return False
    except asyncpg.ConnectionDoesNotExistError:
        print("❌ Подключение не существует")
        print("   Проверьте, запущен ли PostgreSQL в WSL")
        return False
    except ConnectionRefusedError:
        print("❌ Подключение отклонено")
        print("   Проверьте SSH туннель в DBeaver")
        return False
    except Exception as e:
        print(f"❌ Неизвестная ошибка: {type(e).__name__}: {e}")
        return False

async def test_ssh_connection():
    """Тест SSH подключения к WSL"""
    print("\n🔍 Тест SSH подключения...")
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex(('172.30.219.23', 22))
        sock.close()
        
        if result == 0:
            print("✅ SSH сервер в WSL доступен")
            return True
        else:
            print("❌ SSH сервер недоступен")
            print("   Запустите в WSL: sudo service ssh start")
            return False
    except Exception as e:
        print(f"❌ Ошибка SSH теста: {e}")
        return False

async def main():
    print("=" * 50)
    print("🔧 ДИАГНОСТИКА ПОДКЛЮЧЕНИЯ WSL → Windows")
    print("=" * 50)
    
    # Проверяем SSH
    ssh_ok = await test_ssh_connection()
    
    if not ssh_ok:
        print("\n⚠️  Сначала настройте SSH в WSL:")
        print("   1. sudo apt install openssh-server")
        print("   2. sudo service ssh start")
        print("   3. sudo systemctl enable ssh")
        return
    
    # Проверяем PostgreSQL
    pg_ok = await test_postgresql_directly()
    
    if not pg_ok:
        print("\n⚠️  Решение проблем:")
        print("   Вариант A: Настройте DBeaver с SSH туннелем и подключитесь")
        print("   Вариант B: Запустите SSH туннель вручную")
        
        print("\n🚀 Быстрое решение:")
        print("   1. Откройте DBeaver")
        print("   2. Нажмите правой кнопкой на подключение к hotel_booking")
        print("   3. Выберите 'Подключиться'")
        print("   4. Запустите этот скрипт снова")
        
        # Предлагаем альтернативу
        print("\n💡 Альтернатива: Используйте прямое подключение через порт")
        use_direct = input("   Попробовать прямое подключение? (y/n): ")
        if use_direct.lower() == 'y':
            await test_direct_connection()

async def test_direct_connection():
    """Тест прямого подключения к IP WSL"""
    print("\n🔍 Тест прямого подключения к IP WSL...")
    
    try:
        conn = await asyncpg.connect(
            host='172.30.219.23',  # IP вашего WSL
            port=5432,
            user='postgres',
            password='password123',
            database='hotel_booking',
            timeout=10
        )
        print("✅ Прямое подключение работает!")
        await conn.close()
        return True
    except Exception as e:
        print(f"❌ Прямое подключение не работает: {e}")
        print("\n💡 Настройте PostgreSQL в WSL:")
        print("   1. sudo nano /etc/postgresql/*/main/postgresql.conf")
        print("   2. Измените: listen_addresses = '*'")
        print("   3. sudo nano /etc/postgresql/*/main/pg_hba.conf")
        print("   4. Добавьте: host all all 0.0.0.0/0 md5")
        print("   5. sudo systemctl restart postgresql")
        return False

if __name__ == "__main__":
    asyncio.run(main())