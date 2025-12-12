// system-users.js - Управление пользователями для системного администратора

class SystemUsers {
    constructor() {
        this.users = [];
        this.hotels = [];
        this.currentUserId = null;
        this.userModal = null;
        this.filters = {
            search: '',
            role: 'all',
            status: 'all'
        };
    }

    async init() {
        try {
            // Инициализация модального окна
            this.userModal = new bootstrap.Modal(document.getElementById('userModal'));

            // Загружаем данные
            await this.loadUsers();
            await this.loadHotels();

            // Настройка обработчиков событий
            this.setupEventListeners();
            
        } catch (error) {
            console.error('[SystemUsers] Init error:', error);
            showError('Ошибка инициализации');
        }
    }

    setupEventListeners() {
        // Кнопка сохранения пользователя
        document.getElementById('save-user-btn').addEventListener('click', () => {
            this.saveUser();
        });

        // Изменение роли - показываем/скрываем выбор отеля
        document.getElementById('user-role').addEventListener('change', (e) => {
            const hotelContainer = document.getElementById('hotel-select-container');
            if (e.target.value === 'hotel_admin') {
                hotelContainer.classList.remove('d-none');
            } else {
                hotelContainer.classList.add('d-none');
            }
        });

        // Поиск
        document.getElementById('search-user').addEventListener('input', (e) => {
            this.filters.search = e.target.value.toLowerCase();
            this.renderUsers();
        });

        // Фильтр по роли
        document.getElementById('filter-role').addEventListener('change', (e) => {
            this.filters.role = e.target.value;
            this.renderUsers();
        });

        // Фильтр по статусу
        document.getElementById('filter-status').addEventListener('change', (e) => {
            this.filters.status = e.target.value;
            this.renderUsers();
        });

        // Сброс фильтров
        document.getElementById('reset-filters').addEventListener('click', () => {
            this.filters = { search: '', role: 'all', status: 'all' };
            document.getElementById('search-user').value = '';
            document.getElementById('filter-role').value = 'all';
            document.getElementById('filter-status').value = 'all';
            this.renderUsers();
        });
    }

    async loadUsers() {
        try {
            this.users = await API.request('/users/');
            this.renderUsers();
            this.updateStatistics();
        } catch (error) {
            console.error('[SystemUsers] Error loading users:', error);
            showError('Ошибка загрузки пользователей');
        }
    }

    async loadHotels() {
        try {
            this.hotels = await API.request('/hotels/');
        } catch (error) {
            console.error('[SystemUsers] Error loading hotels:', error);
        }
    }

    updateStatistics() {
        const totalUsers = this.users.length;
        const guests = this.users.filter(u => u.role === 'guest').length;
        const hotelAdmins = this.users.filter(u => u.role === 'hotel_admin').length;
        const systemAdmins = this.users.filter(u => u.role === 'system_admin').length;

        document.getElementById('total-users').textContent = totalUsers;
        document.getElementById('total-guests').textContent = guests;
        document.getElementById('total-hotel-admins').textContent = hotelAdmins;
        document.getElementById('total-system-admins').textContent = systemAdmins;
    }

    renderUsers() {
        const container = document.getElementById('users-list');
        
        // Применяем фильтры
        let filteredUsers = this.users.filter(user => {
            // Поиск
            if (this.filters.search) {
                const searchLower = this.filters.search.toLowerCase();
                const matchesSearch = 
                    user.first_name.toLowerCase().includes(searchLower) ||
                    user.last_name.toLowerCase().includes(searchLower) ||
                    user.email.toLowerCase().includes(searchLower);
                if (!matchesSearch) return false;
            }

            // Роль
            if (this.filters.role !== 'all' && user.role !== this.filters.role) {
                return false;
            }

            // Статус
            if (this.filters.status === 'active' && !user.is_active) return false;
            if (this.filters.status === 'blocked' && user.is_active) return false;

            return true;
        });

        if (filteredUsers.length === 0) {
            container.innerHTML = `
                <div class="alert alert-info text-center">
                    <i class="bi bi-info-circle me-2"></i>
                    Пользователи не найдены
                </div>
            `;
            return;
        }

        // Создаем таблицу
        container.innerHTML = `
            <div class="table-responsive">
                <table class="table table-hover">
                    <thead>
                        <tr>
                            <th>Имя</th>
                            <th>Email</th>
                            <th>Телефон</th>
                            <th>Роль</th>
                            <th>Отель</th>
                            <th>Статус</th>
                            <th>Действия</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${filteredUsers.map(user => this.renderUserRow(user)).join('')}
                    </tbody>
                </table>
            </div>
        `;
    }

    renderUserRow(user) {
        const roleNames = {
            guest: 'Гость',
            hotel_admin: 'Администратор отеля',
            system_admin: 'Системный администратор'
        };

        const roleBadges = {
            guest: 'info',
            hotel_admin: 'success',
            system_admin: 'danger'
        };

        // Находим отель для администратора
        let hotelName = '-';
        if (user.role === 'hotel_admin' && user.hotel_id) {
            const hotel = this.hotels.find(h => h.hotel_id === user.hotel_id);
            hotelName = hotel ? hotel.name : `Отель #${user.hotel_id}`;
        }

        return `
            <tr>
                <td>
                    <strong>${user.first_name} ${user.last_name}</strong>
                </td>
                <td>${user.email}</td>
                <td>${user.phone || '-'}</td>
                <td>
                    <span class="badge bg-${roleBadges[user.role]}">${roleNames[user.role]}</span>
                </td>
                <td>${hotelName}</td>
                <td>
                    ${user.is_active 
                        ? '<span class="badge bg-success">Активен</span>' 
                        : '<span class="badge bg-danger">Заблокирован</span>'}
                </td>
                <td>
                    <button class="btn btn-sm btn-outline-primary" onclick="systemUsers.openUserModal(${user.user_id})">
                        <i class="bi bi-pencil me-1"></i>Изменить
                    </button>
                </td>
            </tr>
        `;
    }

    async openUserModal(userId) {
        this.currentUserId = userId;
        
        const user = this.users.find(u => u.user_id === userId);
        if (!user) return;

        // Заполняем список отелей
        const hotelSelect = document.getElementById('user-hotel');
        hotelSelect.innerHTML = '<option value="">Выберите отель</option>' + 
            this.hotels.map(hotel => 
                `<option value="${hotel.hotel_id}">${hotel.name} (${hotel.city})</option>`
            ).join('');

        // Заполняем данные пользователя
        document.getElementById('user-id').value = user.user_id;
        document.getElementById('user-email').value = user.email;
        document.getElementById('user-first-name').value = user.first_name;
        document.getElementById('user-last-name').value = user.last_name;
        document.getElementById('user-phone').value = user.phone || '';
        document.getElementById('user-role').value = user.role;
        document.getElementById('user-active').checked = user.is_active;

        // Показываем/скрываем выбор отеля
        const hotelContainer = document.getElementById('hotel-select-container');
        if (user.role === 'hotel_admin') {
            hotelContainer.classList.remove('d-none');
            document.getElementById('user-hotel').value = user.hotel_id || '';
        } else {
            hotelContainer.classList.add('d-none');
        }

        this.userModal.show();
    }

    async saveUser() {
        try {
            const userId = parseInt(document.getElementById('user-id').value);
            const role = document.getElementById('user-role').value;
            const isActive = document.getElementById('user-active').checked;
            
            let hotelId = null;
            if (role === 'hotel_admin') {
                hotelId = document.getElementById('user-hotel').value;
                if (!hotelId) {
                    showError('Для администратора отеля необходимо выбрать отель');
                    return;
                }
                hotelId = parseInt(hotelId);
            }

            // Обновляем пользователя
            const userData = {
                is_active: isActive
            };

            await API.request(`/users/${userId}`, {
                method: 'PATCH',
                body: JSON.stringify(userData)
            });

            // Обновляем роль и отель отдельным запросом (если нужно)
            const user = this.users.find(u => u.user_id === userId);
            if (user.role !== role || user.hotel_id !== hotelId) {
                await API.request(`/users/${userId}/role`, {
                    method: 'PATCH',
                    body: JSON.stringify({ 
                        role: role,
                        hotel_id: hotelId 
                    })
                });
            }

            showSuccess('Пользователь успешно обновлен');
            this.userModal.hide();
            await this.loadUsers();
            
        } catch (error) {
            console.error('[SystemUsers] Error saving user:', error);
            showError(error.message || 'Ошибка сохранения пользователя');
        }
    }
}

// Создаем глобальный экземпляр
const systemUsers = new SystemUsers();
