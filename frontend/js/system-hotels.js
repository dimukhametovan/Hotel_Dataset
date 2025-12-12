// system-hotels.js - Управление отелями для системного администратора

class SystemHotels {
    constructor() {
        this.hotels = [];
        this.hotelAdmins = [];
        this.currentHotelId = null;
        this.hotelModal = null;
        this.deleteModal = null;
        this.filters = {
            search: '',
            status: 'all'
        };
    }

    async init() {
        try {
            // Инициализация модальных окон
            this.hotelModal = new bootstrap.Modal(document.getElementById('hotelModal'));
            this.deleteModal = new bootstrap.Modal(document.getElementById('deleteModal'));

            // Загружаем данные
            await this.loadHotels();
            await this.loadHotelAdmins();

            // Настройка обработчиков событий
            this.setupEventListeners();
            
        } catch (error) {
            console.error('[SystemHotels] Init error:', error);
            showError('Ошибка инициализации');
        }
    }

    setupEventListeners() {
        // Кнопка добавления отеля
        document.getElementById('add-hotel-btn').addEventListener('click', () => {
            this.openHotelModal();
        });

        // Кнопка сохранения отеля
        document.getElementById('save-hotel-btn').addEventListener('click', () => {
            this.saveHotel();
        });

        // Кнопка подтверждения удаления
        document.getElementById('confirm-delete-btn').addEventListener('click', () => {
            this.deleteHotel();
        });

        // Поиск
        document.getElementById('search-hotel').addEventListener('input', (e) => {
            this.filters.search = e.target.value.toLowerCase();
            this.renderHotels();
        });

        // Фильтр по статусу
        document.getElementById('filter-status').addEventListener('change', (e) => {
            this.filters.status = e.target.value;
            this.renderHotels();
        });

        // Сброс фильтров
        document.getElementById('reset-filters').addEventListener('click', () => {
            this.filters = { search: '', status: 'all' };
            document.getElementById('search-hotel').value = '';
            document.getElementById('filter-status').value = 'all';
            this.renderHotels();
        });
    }

    async loadHotels() {
        try {
            this.hotels = await API.request('/hotels/', 'GET');
            this.renderHotels();
        } catch (error) {
            console.error('[SystemHotels] Error loading hotels:', error);
            showError('Ошибка загрузки отелей');
        }
    }

    async loadHotelAdmins() {
        try {
            const allUsers = await API.request('/users/', 'GET');
            this.hotelAdmins = allUsers.filter(u => u.role === 'hotel_admin');
        } catch (error) {
            console.error('[SystemHotels] Error loading hotel admins:', error);
        }
    }

    renderHotels() {
        const container = document.getElementById('hotels-list');
        
        // Применяем фильтры
        let filteredHotels = this.hotels.filter(hotel => {
            // Поиск
            if (this.filters.search) {
                const searchLower = this.filters.search.toLowerCase();
                const matchesSearch = 
                    hotel.name.toLowerCase().includes(searchLower) ||
                    hotel.city.toLowerCase().includes(searchLower) ||
                    hotel.address.toLowerCase().includes(searchLower);
                if (!matchesSearch) return false;
            }

            // Статус
            if (this.filters.status === 'active' && !hotel.is_active) return false;
            if (this.filters.status === 'inactive' && hotel.is_active) return false;

            return true;
        });

        if (filteredHotels.length === 0) {
            container.innerHTML = `
                <div class="alert alert-info text-center">
                    <i class="bi bi-info-circle me-2"></i>
                    Отели не найдены
                </div>
            `;
            return;
        }

        container.innerHTML = filteredHotels.map(hotel => `
            <div class="card mb-3">
                <div class="card-body">
                    <div class="row align-items-center">
                        <div class="col-md-8">
                            <h5 class="card-title mb-2">
                                ${hotel.name}
                                ${hotel.is_active 
                                    ? '<span class="badge bg-success ms-2">Активен</span>' 
                                    : '<span class="badge bg-secondary ms-2">Неактивен</span>'}
                                ${hotel.star_rating 
                                    ? `<span class="badge bg-warning text-dark ms-2">${'⭐'.repeat(Math.round(hotel.star_rating))}</span>` 
                                    : ''}
                            </h5>
                            <p class="text-muted mb-1">
                                <i class="bi bi-geo-alt me-1"></i>${hotel.city}, ${hotel.country}
                            </p>
                            <p class="text-muted mb-1 small">${hotel.address}</p>
                            ${hotel.phone ? `<p class="text-muted mb-1 small"><i class="bi bi-telephone me-1"></i>${hotel.phone}</p>` : ''}
                            ${hotel.email ? `<p class="text-muted mb-0 small"><i class="bi bi-envelope me-1"></i>${hotel.email}</p>` : ''}
                        </div>
                        <div class="col-md-4 text-end">
                            <button class="btn btn-sm btn-outline-primary me-2" onclick="systemHotels.openHotelModal(${hotel.hotel_id})">
                                <i class="bi bi-pencil me-1"></i>Редактировать
                            </button>
                            <button class="btn btn-sm btn-outline-danger" onclick="systemHotels.confirmDelete(${hotel.hotel_id}, '${hotel.name.replace(/'/g, "\\'")}')">
                                <i class="bi bi-trash me-1"></i>Удалить
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        `).join('');
    }

    async openHotelModal(hotelId = null) {
        this.currentHotelId = hotelId;
        
        // Заполняем список администраторов
        const adminSelect = document.getElementById('hotel-admin');
        adminSelect.innerHTML = '<option value="">Не назначен</option>' + 
            this.hotelAdmins.map(admin => 
                `<option value="${admin.user_id}">${admin.first_name} ${admin.last_name} (${admin.email})</option>`
            ).join('');

        if (hotelId) {
            // Режим редактирования
            document.getElementById('hotelModalTitle').textContent = 'Редактировать отель';
            
            const hotel = this.hotels.find(h => h.hotel_id === hotelId);
            if (hotel) {
                document.getElementById('hotel-id').value = hotel.hotel_id;
                document.getElementById('hotel-name').value = hotel.name;
                document.getElementById('hotel-city').value = hotel.city;
                document.getElementById('hotel-country').value = hotel.country;
                document.getElementById('hotel-address').value = hotel.address;
                document.getElementById('hotel-phone').value = hotel.phone || '';
                document.getElementById('hotel-email').value = hotel.email || '';
                document.getElementById('hotel-stars').value = hotel.star_rating || '';
                document.getElementById('hotel-description').value = hotel.description || '';
                document.getElementById('hotel-admin').value = hotel.admin_id || '';
                document.getElementById('hotel-active').checked = hotel.is_active;
            }
        } else {
            // Режим создания
            document.getElementById('hotelModalTitle').textContent = 'Добавить отель';
            document.getElementById('hotel-form').reset();
            document.getElementById('hotel-id').value = '';
            document.getElementById('hotel-active').checked = true;
        }

        this.hotelModal.show();
    }

    async saveHotel() {
        try {
            const hotelId = document.getElementById('hotel-id').value;
            const hotelData = {
                name: document.getElementById('hotel-name').value.trim(),
                city: document.getElementById('hotel-city').value.trim(),
                country: document.getElementById('hotel-country').value.trim(),
                address: document.getElementById('hotel-address').value.trim(),
                phone: document.getElementById('hotel-phone').value.trim() || null,
                email: document.getElementById('hotel-email').value.trim() || null,
                star_rating: document.getElementById('hotel-stars').value ? parseFloat(document.getElementById('hotel-stars').value) : null,
                description: document.getElementById('hotel-description').value.trim() || null,
                admin_id: document.getElementById('hotel-admin').value ? parseInt(document.getElementById('hotel-admin').value) : null,
                is_active: document.getElementById('hotel-active').checked
            };

            // Валидация
            if (!hotelData.name || !hotelData.city || !hotelData.country || !hotelData.address) {
                showError('Заполните все обязательные поля');
                return;
            }

            if (hotelId) {
                // Обновление
                await API.request(`/hotels/${hotelId}`, 'PATCH', hotelData);
                showSuccess('Отель успешно обновлен');
            } else {
                // Создание
                await API.request('/hotels/', 'POST', hotelData);
                showSuccess('Отель успешно добавлен');
            }

            this.hotelModal.hide();
            await this.loadHotels();
            
        } catch (error) {
            console.error('[SystemHotels] Error saving hotel:', error);
            showError(error.message || 'Ошибка сохранения отеля');
        }
    }

    confirmDelete(hotelId, hotelName) {
        this.currentHotelId = hotelId;
        document.getElementById('delete-hotel-name').textContent = hotelName;
        this.deleteModal.show();
    }

    async deleteHotel() {
        try {
            await API.request(`/hotels/${this.currentHotelId}`, 'DELETE');
            showSuccess('Отель успешно удален');
            this.deleteModal.hide();
            await this.loadHotels();
        } catch (error) {
            console.error('[SystemHotels] Error deleting hotel:', error);
            showError(error.message || 'Ошибка удаления отеля');
        }
    }
}

// Создаем глобальный экземпляр
const systemHotels = new SystemHotels();
