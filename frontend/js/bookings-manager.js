// bookings-manager.js - Управление бронированиями отеля

class BookingsManager {
    constructor() {
        this.hotelId = null;
        this.hotel = null;
        this.bookings = [];
        this.allBookings = [];
        this.rooms = [];
        this.confirmModal = null;
        this.pendingStatusChange = null;
    }

    async init() {
        try {
            // Получаем информацию о текущем пользователе
            const user = Auth.getCurrentUser();
            if (!user || !user.hotel_id) {
                showError('Отель не привязан к вашему аккаунту');
                window.location.href = 'index.html';
                return;
            }

            this.hotelId = user.hotel_id;

            // Инициализация модального окна
            this.confirmModal = new bootstrap.Modal(document.getElementById('confirmStatusModal'));

            // Загружаем данные
            await this.loadHotelInfo();
            await this.loadRooms();
            await this.loadBookings();
            
        } catch (error) {
            console.error('[BookingsManager] Init error:', error);
            showError('Ошибка инициализации');
        }
    }

    async loadHotelInfo() {
        try {
            this.hotel = await API.request(`/hotels/${this.hotelId}`);
            document.getElementById('hotel-name').textContent = this.hotel.name;
        } catch (error) {
            console.error('[BookingsManager] Error loading hotel:', error);
            document.getElementById('hotel-name').textContent = 'Ошибка загрузки';
        }
    }

    async loadRooms() {
        try {
            this.rooms = await API.request(`/rooms/hotel/${this.hotelId}`);
        } catch (error) {
            console.error('[BookingsManager] Error loading rooms:', error);
        }
    }

    async loadBookings() {
        const container = document.getElementById('bookings-container');
        container.innerHTML = '<div class="text-center my-5"><div class="spinner-border text-primary"></div></div>';
        
        try {
            this.allBookings = await API.request(`/bookings/hotel/${this.hotelId}/all`);
            this.bookings = [...this.allBookings];
            
            this.updateStatistics();
            this.renderBookings();
            
        } catch (error) {
            console.error('[BookingsManager] Error loading bookings:', error);
            container.innerHTML = '<div class="alert alert-danger">Ошибка загрузки бронирований</div>';
        }
    }

    updateStatistics() {
        const stats = {
            pending: 0,
            confirmed: 0,
            checked_in: 0,
            completed: 0
        };

        this.allBookings.forEach(booking => {
            if (stats.hasOwnProperty(booking.status)) {
                stats[booking.status]++;
            }
        });

        document.getElementById('stat-pending').textContent = stats.pending;
        document.getElementById('stat-confirmed').textContent = stats.confirmed;
        document.getElementById('stat-checked-in').textContent = stats.checked_in;
        document.getElementById('stat-completed').textContent = stats.completed;
    }

    renderBookings() {
        const container = document.getElementById('bookings-container');
        
        if (this.bookings.length === 0) {
            container.innerHTML = '<div class="alert alert-info"><i class="bi bi-info-circle me-2"></i>Бронирования не найдены</div>';
            return;
        }

        container.innerHTML = this.bookings.map(booking => {
            const room = this.rooms.find(r => r.room_id === booking.room_id);
            const roomNumber = room ? room.room_number : 'Неизвестен';
            
            const checkInDate = new Date(booking.check_in_date);
            const checkOutDate = new Date(booking.check_out_date);
            const nights = Math.ceil((checkOutDate - checkInDate) / (1000 * 60 * 60 * 24));
            
            const statusInfo = this.getStatusInfo(booking.status);
            const guestName = booking.user ? `${booking.user.first_name} ${booking.user.last_name}` : 'Неизвестен';
            const guestPhone = booking.user?.phone || 'Не указан';
            const guestEmail = booking.user?.email || 'Не указан';
            
            return `
                <div class="card mb-3 shadow-sm">
                    <div class="card-body">
                        <div class="row align-items-center">
                            <div class="col-md-8">
                                <div class="d-flex align-items-center mb-2">
                                    <h5 class="mb-0 me-3">
                                        <i class="bi bi-calendar-event text-primary me-2"></i>
                                        Бронирование #${booking.booking_id}
                                    </h5>
                                    <span class="badge ${statusInfo.class}">
                                        ${statusInfo.text}
                                    </span>
                                </div>
                                
                                <div class="mb-2">
                                    <p class="mb-1">
                                        <i class="bi bi-person-circle me-2 text-info"></i>
                                        <strong>Гость:</strong> ${guestName}
                                    </p>
                                    <p class="mb-1">
                                        <i class="bi bi-telephone me-2 text-info"></i>
                                        <strong>Телефон:</strong> ${guestPhone}
                                    </p>
                                    <p class="mb-1">
                                        <i class="bi bi-envelope me-2 text-info"></i>
                                        <strong>Email:</strong> ${guestEmail}
                                    </p>
                                </div>
                                
                                <div class="row text-muted">
                                    <div class="col-md-6">
                                        <p class="mb-1">
                                            <i class="bi bi-door-closed me-2"></i>
                                            <strong>Номер:</strong> ${roomNumber}
                                        </p>
                                        <p class="mb-1">
                                            <i class="bi bi-calendar-check me-2"></i>
                                            <strong>Заезд:</strong> ${checkInDate.toLocaleDateString('ru-RU')}
                                        </p>
                                        <p class="mb-1">
                                            <i class="bi bi-calendar-x me-2"></i>
                                            <strong>Выезд:</strong> ${checkOutDate.toLocaleDateString('ru-RU')}
                                        </p>
                                    </div>
                                    <div class="col-md-6">
                                        <p class="mb-1">
                                            <i class="bi bi-moon me-2"></i>
                                            <strong>Ночей:</strong> ${nights}
                                        </p>
                                        <p class="mb-1">
                                            <i class="bi bi-people me-2"></i>
                                            <strong>Гостей:</strong> ${booking.guests_count || 1}
                                        </p>
                                        <p class="mb-1">
                                            <i class="bi bi-cash me-2"></i>
                                            <strong>Сумма:</strong> ${booking.total_price} ₽
                                        </p>
                                    </div>
                                </div>
                                
                                <div class="mt-2">
                                    <small class="text-muted">
                                        <i class="bi bi-clock me-1"></i>
                                        Создано: ${new Date(booking.created_at).toLocaleString('ru-RU')}
                                    </small>
                                </div>
                            </div>
                            
                            <div class="col-md-4 text-end">
                                ${this.renderStatusButtons(booking)}
                            </div>
                        </div>
                    </div>
                </div>
            `;
        }).join('');
    }

    renderStatusButtons(booking) {
        const buttons = [];

        if (booking.status === 'pending') {
            buttons.push(`
                <button class="btn btn-success mb-2 w-100" 
                        onclick="bookingsManager.showStatusChangeModal(${booking.booking_id}, 'confirmed')">
                    <i class="bi bi-check-circle me-1"></i>Подтвердить
                </button>
            `);
            buttons.push(`
                <button class="btn btn-danger w-100" 
                        onclick="bookingsManager.showStatusChangeModal(${booking.booking_id}, 'cancelled')">
                    <i class="bi bi-x-circle me-1"></i>Отменить
                </button>
            `);
        } else if (booking.status === 'confirmed') {
            buttons.push(`
                <button class="btn btn-info mb-2 w-100" 
                        onclick="bookingsManager.showStatusChangeModal(${booking.booking_id}, 'checked_in')">
                    <i class="bi bi-door-open me-1"></i>Заселить
                </button>
            `);
            buttons.push(`
                <button class="btn btn-danger w-100" 
                        onclick="bookingsManager.showStatusChangeModal(${booking.booking_id}, 'cancelled')">
                    <i class="bi bi-x-circle me-1"></i>Отменить
                </button>
            `);
        } else if (booking.status === 'checked_in') {
            buttons.push(`
                <button class="btn btn-secondary w-100" 
                        onclick="bookingsManager.showStatusChangeModal(${booking.booking_id}, 'completed')">
                    <i class="bi bi-check2-circle me-1"></i>Завершить
                </button>
            `);
        }

        return buttons.join('');
    }

    getStatusInfo(status) {
        const statusMap = {
            pending: { text: 'Ожидает подтверждения', class: 'bg-warning' },
            confirmed: { text: 'Подтверждено', class: 'bg-success' },
            checked_in: { text: 'Заселен', class: 'bg-info' },
            completed: { text: 'Завершено', class: 'bg-secondary' },
            cancelled: { text: 'Отменено', class: 'bg-danger' }
        };

        return statusMap[status] || { text: status, class: 'bg-secondary' };
    }

    showStatusChangeModal(bookingId, newStatus) {
        this.pendingStatusChange = { bookingId, newStatus };
        
        const statusTexts = {
            confirmed: 'Вы уверены, что хотите подтвердить это бронирование?',
            checked_in: 'Вы уверены, что хотите отметить гостя как заселенного?',
            completed: 'Вы уверены, что хотите завершить это бронирование?',
            cancelled: 'Вы уверены, что хотите отменить это бронирование?'
        };

        document.getElementById('confirm-status-text').textContent = 
            statusTexts[newStatus] || 'Изменить статус бронирования?';
        
        this.confirmModal.show();
    }

    async confirmStatusChange() {
        if (!this.pendingStatusChange) return;

        const { bookingId, newStatus } = this.pendingStatusChange;

        try {
            await API.request(`/bookings/${bookingId}`, {
                method: 'PUT',
                body: JSON.stringify({ status: newStatus })
            });

            showSuccess('Статус бронирования успешно обновлен');
            this.confirmModal.hide();
            this.pendingStatusChange = null;
            await this.loadBookings();
            
        } catch (error) {
            console.error('[BookingsManager] Error updating status:', error);
            showError(error.message || 'Ошибка обновления статуса');
        }
    }

    applyFilters() {
        const statusFilter = document.getElementById('filter-status').value;
        const dateFromFilter = document.getElementById('filter-date-from').value;
        const dateToFilter = document.getElementById('filter-date-to').value;

        this.bookings = this.allBookings.filter(booking => {
            if (statusFilter && booking.status !== statusFilter) return false;
            
            if (dateFromFilter) {
                const checkInDate = new Date(booking.check_in_date);
                const filterDate = new Date(dateFromFilter);
                if (checkInDate < filterDate) return false;
            }
            
            if (dateToFilter) {
                const checkInDate = new Date(booking.check_in_date);
                const filterDate = new Date(dateToFilter);
                if (checkInDate > filterDate) return false;
            }
            
            return true;
        });

        this.renderBookings();
    }

    resetFilters() {
        document.getElementById('filter-status').value = '';
        document.getElementById('filter-date-from').value = '';
        document.getElementById('filter-date-to').value = '';
        this.bookings = [...this.allBookings];
        this.renderBookings();
    }
}

// Создаем глобальный экземпляр
const bookingsManager = new BookingsManager();
