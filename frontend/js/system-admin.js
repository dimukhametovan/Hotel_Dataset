// system-admin.js - Главная страница системного администратора

class SystemAdmin {
    constructor() {
        this.hotels = [];
        this.users = [];
    }

    async init() {
        try {
            await this.loadStatistics();
        } catch (error) {
            console.error('[SystemAdmin] Init error:', error);
            showError('Ошибка загрузки данных');
        }
    }

    async loadStatistics() {
        try {
            // Загружаем статистику отелей
            this.hotels = await API.request('/hotels/', 'GET');
            const hotelsContainer = document.getElementById('hotels-stats');
            if (hotelsContainer) {
                const activeHotels = this.hotels.filter(h => h.is_active).length;
                hotelsContainer.innerHTML = `
                    <div class="d-flex justify-content-around">
                        <div>
                            <div class="h4 mb-0 text-primary">${this.hotels.length}</div>
                            <small class="text-muted">Всего отелей</small>
                        </div>
                        <div>
                            <div class="h4 mb-0 text-success">${activeHotels}</div>
                            <small class="text-muted">Активных</small>
                        </div>
                    </div>
                `;
            }

            // Загружаем статистику пользователей
            this.users = await API.request('/users/', 'GET');
            const usersContainer = document.getElementById('users-stats');
            if (usersContainer) {
                const guests = this.users.filter(u => u.role === 'guest').length;
                const hotelAdmins = this.users.filter(u => u.role === 'hotel_admin').length;
                const systemAdmins = this.users.filter(u => u.role === 'system_admin').length;
                
                usersContainer.innerHTML = `
                    <div class="row g-2 small">
                        <div class="col-12">
                            <div class="d-flex justify-content-between">
                                <span class="text-muted">Всего:</span>
                                <strong>${this.users.length}</strong>
                            </div>
                        </div>
                        <div class="col-12">
                            <div class="d-flex justify-content-between">
                                <span class="text-muted">Гостей:</span>
                                <span class="text-info">${guests}</span>
                            </div>
                        </div>
                        <div class="col-12">
                            <div class="d-flex justify-content-between">
                                <span class="text-muted">Админов отелей:</span>
                                <span class="text-success">${hotelAdmins}</span>
                            </div>
                        </div>
                        <div class="col-12">
                            <div class="d-flex justify-content-between">
                                <span class="text-muted">Системных админов:</span>
                                <span class="text-danger">${systemAdmins}</span>
                            </div>
                        </div>
                    </div>
                `;
            }

        } catch (error) {
            console.error('[SystemAdmin] Error loading statistics:', error);
            showError('Ошибка загрузки статистики');
        }
    }
}

// Создаем глобальный экземпляр
const systemAdmin = new SystemAdmin();
