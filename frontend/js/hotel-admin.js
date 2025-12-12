// hotel-admin.js - Управление отелем для администратора

class HotelAdmin {
    constructor() {
        this.hotelId = null;
        this.hotel = null;
        this.rooms = [];
        this.bookings = [];
        this.reviews = [];
        this.roomtypes = [];
    }

    async init() {
        try {
            // Получаем информацию о текущем пользователе
            const user = Auth.getCurrentUser();
            if (!user || !user.hotel_id) {
                showError('Отель не привязан к вашему аккаунту');
                return;
            }

            this.hotelId = user.hotel_id;

            // Загружаем информацию об отеле и статистику
            await this.loadHotelInfo();
            await this.loadDashboardStats();
            
        } catch (error) {
            console.error('[HotelAdmin] Init error:', error);
            showError('Ошибка инициализации');
        }
    }

    async loadHotelInfo() {
        try {
            this.hotel = await API.request(`/hotels/${this.hotelId}`);
            document.getElementById('hotel-name').textContent = this.hotel.name;
        } catch (error) {
            console.error('[HotelAdmin] Error loading hotel:', error);
        }
    }

    async loadDashboardStats() {
        // Статистика больше не отображается на плашках
    }

    async loadRooms() {
        const container = document.getElementById('rooms-list');
        container.innerHTML = '<div class="text-center my-5"><div class="spinner-border" role="status"></div></div>';
        
        try {
            this.rooms = await API.request(`/rooms/hotel/${this.hotelId}`);
            
            if (this.rooms.length === 0) {
                container.innerHTML = '<div class="alert alert-info">Номера не добавлены</div>';
                return;
            }

            container.innerHTML = this.rooms.map(room => `
                <div class="card mb-3">
                    <div class="card-body">
                        <div class="row">
                            <div class="col-md-8">
                                <h5>Номер ${room.room_number}</h5>
                                <p class="mb-1">Этаж: ${room.floor || 'Не указан'}</p>
                                <p class="mb-1">Цена: ${room.price_per_night} ₽/ночь</p>
                                <p class="mb-1">Статус: <span class="badge ${room.is_available ? 'bg-success' : 'bg-secondary'}">${room.is_available ? 'Доступен' : 'Занят'}</span></p>
                            </div>
                            <div class="col-md-4 text-end">
                                <button class="btn btn-sm btn-primary" onclick="hotelAdmin.editRoom(${room.room_id})">
                                    <i class="bi bi-pencil"></i> Редактировать
                                </button>
                                <button class="btn btn-sm btn-danger" onclick="hotelAdmin.deleteRoom(${room.room_id})">
                                    <i class="bi bi-trash"></i> Удалить
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            `).join('');
            
        } catch (error) {
            container.innerHTML = '<div class="alert alert-danger">Ошибка загрузки номеров</div>';
        }
    }

    async loadBookings() {
        const container = document.getElementById('bookings-list');
        container.innerHTML = '<div class="text-center my-5"><div class="spinner-border" role="status"></div></div>';
        
        try {
            this.bookings = await API.request(`/bookings/hotel/${this.hotelId}`);
            
            if (this.bookings.length === 0) {
                container.innerHTML = '<div class="alert alert-info">Бронирований нет</div>';
                return;
            }

            container.innerHTML = this.bookings.map(booking => {
                const statusBadges = {
                    pending: 'bg-warning',
                    confirmed: 'bg-success',
                    checked_in: 'bg-info',
                    completed: 'bg-secondary',
                    cancelled: 'bg-danger'
                };
                
                return `
                    <div class="card mb-3">
                        <div class="card-body">
                            <div class="row">
                                <div class="col-md-8">
                                    <h6>Бронирование #${booking.booking_id}</h6>
                                    <p class="mb-1">Заезд: ${new Date(booking.check_in_date).toLocaleDateString('ru-RU')}</p>
                                    <p class="mb-1">Выезд: ${new Date(booking.check_out_date).toLocaleDateString('ru-RU')}</p>
                                    <p class="mb-1">Гостей: ${booking.guests_count || 1}</p>
                                    <p class="mb-1">Стоимость: ${booking.total_price} ₽</p>
                                    <span class="badge ${statusBadges[booking.status]}">${this.getStatusText(booking.status)}</span>
                                </div>
                                <div class="col-md-4 text-end">
                                    ${booking.status === 'pending' ? `
                                        <button class="btn btn-sm btn-success mb-1" onclick="hotelAdmin.updateBookingStatus(${booking.booking_id}, 'confirmed')">
                                            <i class="bi bi-check-circle"></i> Подтвердить
                                        </button>
                                        <button class="btn btn-sm btn-danger" onclick="hotelAdmin.updateBookingStatus(${booking.booking_id}, 'cancelled')">
                                            <i class="bi bi-x-circle"></i> Отменить
                                        </button>
                                    ` : ''}
                                    ${booking.status === 'confirmed' ? `
                                        <button class="btn btn-sm btn-info mb-1" onclick="hotelAdmin.updateBookingStatus(${booking.booking_id}, 'checked_in')">
                                            <i class="bi bi-door-open"></i> Заселен
                                        </button>
                                    ` : ''}
                                    ${booking.status === 'checked_in' ? `
                                        <button class="btn btn-sm btn-secondary" onclick="hotelAdmin.updateBookingStatus(${booking.booking_id}, 'completed')">
                                            <i class="bi bi-check2-circle"></i> Завершить
                                        </button>
                                    ` : ''}
                                </div>
                            </div>
                        </div>
                    </div>
                `;
            }).join('');
            
        } catch (error) {
            container.innerHTML = '<div class="alert alert-danger">Ошибка загрузки бронирований</div>';
        }
    }

    async loadReviews() {
        const container = document.getElementById('reviews-list');
        container.innerHTML = '<div class="text-center my-5"><div class="spinner-border" role="status"></div></div>';
        
        try {
            this.reviews = await API.request(`/reviews/hotel/${this.hotelId}`);
            
            if (this.reviews.length === 0) {
                container.innerHTML = '<div class="alert alert-info">Отзывов нет</div>';
                return;
            }

            container.innerHTML = this.reviews.map(review => `
                <div class="card mb-3">
                    <div class="card-body">
                        <div class="row">
                            <div class="col-md-8">
                                <h6>${review.user ? review.user.first_name + ' ' + review.user.last_name : 'Гость'}</h6>
                                <div class="mb-2">${'⭐'.repeat(review.rating)}</div>
                                <p>${review.comment || 'Без комментария'}</p>
                                <small class="text-muted">${new Date(review.created_at).toLocaleDateString('ru-RU')}</small>
                            </div>
                            <div class="col-md-4 text-end">
                                <span class="badge ${review.is_approved ? 'bg-success' : 'bg-warning'}">
                                    ${review.is_approved ? 'Одобрен' : 'На модерации'}
                                </span>
                                ${!review.is_approved ? `
                                    <button class="btn btn-sm btn-success mt-2" onclick="hotelAdmin.approveReview(${review.review_id})">
                                        <i class="bi bi-check-circle"></i> Одобрить
                                    </button>
                                ` : ''}
                            </div>
                        </div>
                    </div>
                </div>
            `).join('');
            
        } catch (error) {
            container.innerHTML = '<div class="alert alert-danger">Ошибка загрузки отзывов</div>';
        }
    }

    async loadRoomTypes() {
        const container = document.getElementById('roomtypes-list');
        container.innerHTML = '<div class="text-center my-5"><div class="spinner-border" role="status"></div></div>';
        
        try {
            this.roomtypes = await API.request('/roomtypes/');
            
            if (this.roomtypes.length === 0) {
                container.innerHTML = '<div class="alert alert-info">Типы номеров не добавлены</div>';
                return;
            }

            container.innerHTML = this.roomtypes.map(type => `
                <div class="card mb-3">
                    <div class="card-body">
                        <div class="row">
                            <div class="col-md-8">
                                <h5>${type.type_name}</h5>
                                <p class="mb-1">${type.description || ''}</p>
                                <p class="mb-1">Цена: ${type.price_per_night} ₽/ночь</p>
                                <p class="mb-1">Макс. гостей: ${type.max_occupancy}</p>
                            </div>
                            <div class="col-md-4 text-end">
                                <button class="btn btn-sm btn-primary" onclick="hotelAdmin.editRoomType(${type.roomtype_id})">
                                    <i class="bi bi-pencil"></i> Редактировать
                                </button>
                                <button class="btn btn-sm btn-danger" onclick="hotelAdmin.deleteRoomType(${type.roomtype_id})">
                                    <i class="bi bi-trash"></i> Удалить
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            `).join('');
            
        } catch (error) {
            container.innerHTML = '<div class="alert alert-danger">Ошибка загрузки типов номеров</div>';
        }
    }

    getStatusText(status) {
        const statuses = {
            pending: 'Ожидает',
            confirmed: 'Подтверждено',
            checked_in: 'Заселен',
            completed: 'Завершено',
            cancelled: 'Отменено'
        };
        return statuses[status] || status;
    }

    async updateBookingStatus(bookingId, newStatus) {
        try {
            await API.request(`/bookings/${bookingId}/status`, 'PATCH', { status: newStatus });
            showSuccess('Статус обновлен');
            this.loadBookings();
        } catch (error) {
            showError('Ошибка обновления статуса');
        }
    }

    async approveReview(reviewId) {
        try {
            await API.request(`/reviews/${reviewId}`, 'PUT', { is_approved: true });
            showSuccess('Отзыв одобрен');
            this.loadReviews();
        } catch (error) {
            showError('Ошибка одобрения отзыва');
        }
    }

    showAddRoomModal() {
        showError('Функция в разработке');
    }

    showAddRoomTypeModal() {
        showError('Функция в разработке');
    }

    editRoom(roomId) {
        showError('Функция в разработке');
    }

    deleteRoom(roomId) {
        showError('Функция в разработке');
    }

    editRoomType(typeId) {
        showError('Функция в разработке');
    }

    deleteRoomType(typeId) {
        showError('Функция в разработке');
    }
}

const hotelAdmin = new HotelAdmin();
