// bookings.js - Управление бронированиями

class Bookings {
    constructor() {
        this.bookings = [];
        this.filteredBookings = [];
        this.rooms = {};
        this.hotels = {};
    }

    async loadMyBookings(statusFilter = '') {
        try {
            const endpoint = statusFilter ? `/bookings/my?status=${statusFilter}` : '/bookings/my';
            const data = await API.request(endpoint);
            this.bookings = data;
            this.filteredBookings = data;
            
            // Загружаем дополнительную информацию
            await this.loadAdditionalInfo();
            
            this.renderMyBookings();
        } catch (error) {
            console.error('[Bookings] Error loading bookings:', error);
            showError('Не удалось загрузить бронирования');
        }
    }

    async loadAdditionalInfo() {
        // Загружаем информацию о комнатах и отелях
        const roomIds = [...new Set(this.bookings.map(b => b.room_id))];
        
        for (const roomId of roomIds) {
            try {
                const room = await API.request(`/rooms/${roomId}`);
                this.rooms[roomId] = room;
                
                // Загружаем информацию об отеле
                if (room.hotel_id && !this.hotels[room.hotel_id]) {
                    const hotel = await API.request(`/hotels/${room.hotel_id}`);
                    this.hotels[room.hotel_id] = hotel;
                }
            } catch (error) {
                console.error(`Error loading room ${roomId}:`, error);
            }
        }
    }

    renderMyBookings() {
        const container = document.getElementById('bookings-container');
        if (!container) return;

        if (this.filteredBookings.length === 0) {
            container.innerHTML = `
                <div class="alert alert-info">
                    <i class="bi bi-info-circle me-2"></i>
                    ${this.bookings.length === 0 ? 'У вас пока нет бронирований' : 'Бронирования не найдены по заданным фильтрам'}
                </div>
            `;
            return;
        }

        const html = this.filteredBookings.map(booking => this.renderBookingCard(booking)).join('');
        container.innerHTML = html;
    }

    renderBookingCard(booking) {
        const checkIn = new Date(booking.check_in_date).toLocaleDateString('ru-RU');
        const checkOut = new Date(booking.check_out_date).toLocaleDateString('ru-RU');
        const createdAt = new Date(booking.created_at).toLocaleDateString('ru-RU');
        const statusBadge = this.getStatusBadge(booking.status);
        const canCancel = (booking.status === 'confirmed' || booking.status === 'pending') && new Date(booking.check_in_date) > new Date();
        
        // Получаем информацию о комнате и отеле
        const room = this.rooms[booking.room_id] || {};
        const hotel = this.hotels[room.hotel_id] || {};
        
        // Вычисляем количество ночей
        const nights = Math.ceil((new Date(booking.check_out_date) - new Date(booking.check_in_date)) / (1000 * 60 * 60 * 24));

        return `
            <div class="card mb-3 shadow-sm hover-shadow">
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-8">
                            <div class="d-flex justify-content-between align-items-start mb-2">
                                <div>
                                    <h5 class="card-title mb-1">
                                        <i class="bi bi-building me-2 text-primary"></i>${hotel.name || 'Загрузка...'}
                                    </h5>
                                    <p class="text-muted small mb-2">
                                        ${hotel.city ? `<i class="bi bi-geo-alt me-1"></i>${hotel.city}` : ''}
                                        ${hotel.address ? `, ${hotel.address}` : ''}
                                    </p>
                                </div>
                                <span class="badge ${statusBadge.class} fs-6">${statusBadge.text}</span>
                            </div>
                            
                            <div class="row g-2 mt-2">
                                <div class="col-md-6">
                                    <p class="card-text mb-1">
                                        <i class="bi bi-door-open me-2 text-secondary"></i>
                                        <strong>Номер:</strong> ${room.room_number || 'N/A'}
                                    </p>
                                    <p class="card-text mb-1">
                                        <i class="bi bi-calendar-check me-2 text-success"></i>
                                        <strong>Заезд:</strong> ${checkIn}
                                    </p>
                                    <p class="card-text mb-1">
                                        <i class="bi bi-calendar-x me-2 text-danger"></i>
                                        <strong>Выезд:</strong> ${checkOut}
                                    </p>
                                </div>
                                <div class="col-md-6">
                                    <p class="card-text mb-1">
                                        <i class="bi bi-moon-stars me-2 text-info"></i>
                                        <strong>Ночей:</strong> ${nights}
                                    </p>
                                    <p class="card-text mb-1">
                                        <i class="bi bi-people me-2 text-warning"></i>
                                        <strong>Гостей:</strong> ${booking.guests_count || 1}
                                    </p>
                                    <p class="card-text mb-1">
                                        <i class="bi bi-cash-stack me-2 text-success"></i>
                                        <strong>Стоимость:</strong> ${parseFloat(booking.total_price || 0).toFixed(0)} ₽
                                    </p>
                                </div>
                            </div>
                            <p class="card-text text-muted small mt-2 mb-0">
                                <i class="bi bi-clock me-1"></i>Создано: ${createdAt}
                            </p>
                        </div>
                        <div class="col-md-4 d-flex flex-column justify-content-between align-items-end">
                            <div class="btn-group-vertical w-100" role="group">
                                ${canCancel ? `
                                    <button class="btn btn-outline-danger" onclick="bookings.cancelBooking(${booking.booking_id})">
                                        <i class="bi bi-x-circle me-1"></i>Отменить
                                    </button>
                                ` : ''}
                                ${booking.status === 'completed' && !booking.review ? `
                                    <button class="btn btn-outline-success ${canCancel ? 'mt-2' : ''}" onclick="bookings.addReview(${booking.booking_id}, ${room.hotel_id})">
                                        <i class="bi bi-star me-1"></i>Оставить отзыв
                                    </button>
                                ` : ''}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    getStatusBadge(status) {
        const statuses = {
            'pending': { text: 'Ожидает подтверждения', class: 'bg-warning' },
            'confirmed': { text: 'Подтверждено', class: 'bg-success' },
            'cancelled': { text: 'Отменено', class: 'bg-danger' },
            'checked_in': { text: 'Заселен', class: 'bg-info' },
            'completed': { text: 'Завершено', class: 'bg-secondary' }
        };
        return statuses[status] || { text: status, class: 'bg-secondary' };
    }

    async cancelBooking(bookingId) {
        if (!confirm('Вы уверены, что хотите отменить это бронирование?')) {
            return;
        }

        try {
            await API.request(`/bookings/${bookingId}`, {
                method: 'DELETE'
            });
            showSuccess('Бронирование отменено');
            this.loadMyBookings();
        } catch (error) {
            console.error('[Bookings] Error cancelling booking:', error);
            showError(error.message || 'Не удалось отменить бронирование');
        }
    }

    async showBookingDetails(bookingId) {
        try {
            const booking = await API.request(`/bookings/${bookingId}`);
            this.showBookingModal(booking);
        } catch (error) {
            console.error('[Bookings] Error loading booking details:', error);
            showError('Не удалось загрузить детали бронирования');
        }
    }

    async addReview(bookingId, hotelId) {
        const modalHtml = `
            <div class="modal fade" id="reviewModal" tabindex="-1">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">Оставить отзыв</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <form id="reviewForm">
                                <div class="mb-3">
                                    <label class="form-label">Оценка *</label>
                                    <div class="star-rating" id="starRating">
                                        ${[1, 2, 3, 4, 5].map(star => `
                                            <i class="bi bi-star fs-3 text-secondary star" data-rating="${star}" style="cursor: pointer;"></i>
                                        `).join('')}
                                    </div>
                                    <input type="hidden" id="rating" name="rating" required>
                                </div>
                                <div class="mb-3">
                                    <label for="comment" class="form-label">Комментарий</label>
                                    <textarea class="form-control" id="comment" name="comment" rows="4" placeholder="Поделитесь впечатлениями о вашем пребывании..."></textarea>
                                </div>
                            </form>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Отмена</button>
                            <button type="button" class="btn btn-primary" id="submitReview">Отправить</button>
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Удаляем старый модал если есть
        const oldModal = document.getElementById('reviewModal');
        if (oldModal) oldModal.remove();

        // Добавляем новый
        document.body.insertAdjacentHTML('beforeend', modalHtml);
        const modalEl = document.getElementById('reviewModal');
        const modal = new bootstrap.Modal(modalEl);
        modal.show();

        // Обработчик звезд рейтинга
        let selectedRating = 0;
        document.querySelectorAll('.star').forEach(star => {
            star.addEventListener('click', function() {
                selectedRating = parseInt(this.dataset.rating);
                document.getElementById('rating').value = selectedRating;
                
                // Обновляем визуал
                document.querySelectorAll('.star').forEach(s => {
                    const sRating = parseInt(s.dataset.rating);
                    if (sRating <= selectedRating) {
                        s.classList.remove('bi-star', 'text-secondary');
                        s.classList.add('bi-star-fill', 'text-warning');
                    } else {
                        s.classList.remove('bi-star-fill', 'text-warning');
                        s.classList.add('bi-star', 'text-secondary');
                    }
                });
            });
            
            // Hover эффект
            star.addEventListener('mouseenter', function() {
                const hoverRating = parseInt(this.dataset.rating);
                document.querySelectorAll('.star').forEach(s => {
                    const sRating = parseInt(s.dataset.rating);
                    if (sRating <= hoverRating) {
                        s.classList.remove('bi-star');
                        s.classList.add('bi-star-fill');
                    }
                });
            });

            star.addEventListener('mouseleave', function() {
                document.querySelectorAll('.star').forEach(s => {
                    const sRating = parseInt(s.dataset.rating);
                    if (sRating <= selectedRating) {
                        s.classList.add('bi-star-fill', 'text-warning');
                        s.classList.remove('bi-star', 'text-secondary');
                    } else {
                        s.classList.remove('bi-star-fill', 'text-warning');
                        s.classList.add('bi-star', 'text-secondary');
                    }
                });
            });
        });

        // Обработчик отправки
        document.getElementById('submitReview').addEventListener('click', async () => {
            const rating = document.getElementById('rating').value;
            const comment = document.getElementById('comment').value;

            if (!rating || rating < 1 || rating > 5) {
                showError('Пожалуйста, выберите оценку от 1 до 5');
                return;
            }

            try {
                await API.request('/reviews/', 'POST', {
                    booking_id: bookingId,
                    hotel_id: hotelId,
                    rating: parseInt(rating),
                    comment: comment || null
                });

                modal.hide();
                showSuccess('Спасибо за ваш отзыв!');
                this.loadMyBookings();
            } catch (error) {
                console.error('[Bookings] Error submitting review:', error);
                showError(error.message || 'Не удалось отправить отзыв');
            }
        });
    }

    showBookingModal(booking) {
        const checkIn = new Date(booking.check_in_date).toLocaleDateString('ru-RU');
        const checkOut = new Date(booking.check_out_date).toLocaleDateString('ru-RU');
        const statusBadge = this.getStatusBadge(booking.status);
        
        const room = this.rooms[booking.room_id] || {};
        const hotel = this.hotels[room.hotel_id] || {};

        const modalHtml = `
            <div class="modal fade" id="bookingDetailsModal" tabindex="-1">
                <div class="modal-dialog modal-lg">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">Детали бронирования #${booking.booking_id}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="row">
                                <div class="col-md-6">
                                    <h6>Информация об отеле</h6>
                                    <p><strong>${booking.hotel_name || 'Не указано'}</strong></p>
                                    <p class="text-muted small">${booking.hotel_address || ''}</p>
                                </div>
                                <div class="col-md-6">
                                    <h6>Информация о номере</h6>
                                    <p>Номер: <strong>${booking.room_number || 'N/A'}</strong></p>
                                    <p>Тип: ${booking.room_type || 'N/A'}</p>
                                </div>
                            </div>
                            <hr>
                            <div class="row">
                                <div class="col-md-6">
                                    <p><i class="bi bi-calendar-check me-2"></i>Заезд: <strong>${checkIn}</strong></p>
                                    <p><i class="bi bi-calendar-x me-2"></i>Выезд: <strong>${checkOut}</strong></p>
                                    <p><i class="bi bi-people me-2"></i>Гостей: <strong>${booking.number_of_guests || 1}</strong></p>
                                </div>
                                <div class="col-md-6">
                                    <p><i class="bi bi-cash me-2"></i>Стоимость: <strong>${booking.total_price || 0} ₽</strong></p>
                                    <p>Статус: <span class="badge ${statusBadge.class}">${statusBadge.text}</span></p>
                                </div>
                            </div>
                            ${booking.special_requests ? `
                                <hr>
                                <h6>Особые пожелания</h6>
                                <p>${booking.special_requests}</p>
                            ` : ''}
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Закрыть</button>
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Удалить старый модал если есть
        const oldModal = document.getElementById('bookingDetailsModal');
        if (oldModal) oldModal.remove();

        // Добавить новый модал
        document.body.insertAdjacentHTML('beforeend', modalHtml);
        const modal = new bootstrap.Modal(document.getElementById('bookingDetailsModal'));
        modal.show();
    }

    async createBooking(roomId, checkIn, checkOut, guests, specialRequests = '') {
        try {
            const booking = await API.createBooking({
                room_id: roomId,
                check_in_date: checkIn,
                check_out_date: checkOut,
                guests_count: guests
            });
            showSuccess('Бронирование создано успешно!');
            return booking;
        } catch (error) {
            console.error('[Bookings] Error creating booking:', error);
            throw error;
        }
    }
}

// Глобальный экземпляр
const bookings = new Bookings();
