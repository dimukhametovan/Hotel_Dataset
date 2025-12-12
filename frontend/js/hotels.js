// Hotels Module
class Hotels {
    static readOnlyMode = false;

    static async loadHotelsPage() {
        this.readOnlyMode = false;
        const container = document.getElementById('app-content');
        
        container.innerHTML = `
            <div class="row">
                <div class="col-12">
                    <h2 class="mb-4">
                        <i class="bi bi-building"></i> Доступные отели
                    </h2>
                </div>
            </div>
            
            <!-- Фильтры -->
            <div class="filter-section">
                <div class="row">
                    <div class="col-md-4">
                        <input type="text" class="form-control" id="city-filter" placeholder="Поиск по городу...">
                    </div>
                    <div class="col-md-3">
                        <button class="btn btn-primary" id="apply-filters">
                            <i class="bi bi-search"></i> Поиск
                        </button>
                        <button class="btn btn-secondary" id="reset-filters">
                            <i class="bi bi-arrow-clockwise"></i> Сбросить
                        </button>
                    </div>
                    <div class="col-md-5 text-end">
                        ${Auth.hasRole('system_admin') ? `
                            <button class="btn btn-success" id="add-hotel-btn">
                                <i class="bi bi-plus-circle"></i> Добавить отель
                            </button>
                        ` : ''}
                    </div>
                </div>
            </div>
            
            <!-- Список отелей -->
            <div class="row" id="hotels-list"></div>
        `;
        
        // Загрузить отели
        await this.loadHotels();
        
        // Обработчики событий
        document.getElementById('apply-filters').addEventListener('click', () => this.loadHotels());
        document.getElementById('reset-filters').addEventListener('click', () => {
            document.getElementById('city-filter').value = '';
            this.loadHotels();
        });
        
        if (Auth.hasRole('system_admin')) {
            document.getElementById('add-hotel-btn').addEventListener('click', () => this.showAddHotelModal());
        }
    }
    
    static async loadHotels() {
        const listContainer = document.getElementById('hotels-list');
        showSpinner(listContainer);
        
        try {
            const city = document.getElementById('city-filter').value;
            const params = city ? { city } : {};
            
            const hotels = await API.getHotels(params);
            
            if (hotels.length === 0) {
                listContainer.innerHTML = `
                    <div class="col-12">
                        <div class="alert alert-info">
                            <i class="bi bi-info-circle"></i> Отели не найдены
                        </div>
                    </div>
                `;
                return;
            }
            
            listContainer.innerHTML = hotels.map(hotel => this.renderHotelCard(hotel)).join('');
            
        } catch (error) {
            showError(listContainer, error.message);
        }
    }
    
    static renderHotelCard(hotel) {
        const stars = hotel.star_rating ? '⭐'.repeat(Math.floor(hotel.star_rating)) : '';
        const viewMethod = this.readOnlyMode ? 'viewHotelReadOnly' : 'viewHotel';
        
        return `
            <div class="col-md-6 col-lg-4 mb-4 fade-in">
                <div class="card hotel-card" onclick="Hotels.${viewMethod}(${hotel.hotel_id})">
                    <div class="hotel-image">
                        <i class="bi bi-building"></i>
                    </div>
                    <div class="card-body">
                        <h5 class="card-title">${hotel.name}</h5>
                        <p class="card-text">
                            <i class="bi bi-geo-alt"></i> ${hotel.city}, ${hotel.country}
                        </p>
                        <p class="card-text">
                            <small class="text-muted">${hotel.address}</small>
                        </p>
                        <div class="d-flex justify-content-between align-items-center">
                            <div class="stars">${stars}</div>
                            <button class="btn btn-primary btn-sm">
                                Подробнее <i class="bi bi-arrow-right"></i>
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }
    
    static async viewHotel(hotelId) {
        const container = document.getElementById('app-content');
        showSpinner(container);
        
        try {
            const hotel = await API.getHotel(hotelId);
            
            // Загружаем типы номеров и удобства
            const [roomTypes, amenities] = await Promise.all([
                API.request('/roomtypes/'),
                API.request('/amenities/')
            ]);
            
            const stars = hotel.star_rating ? '⭐'.repeat(Math.floor(hotel.star_rating)) : '';
            
            container.innerHTML = `
                <div class="row">
                    <div class="col-12">
                        <button class="btn btn-link mb-3" onclick="App.loadPage('hotels')">
                            <i class="bi bi-arrow-left"></i> Назад к списку
                        </button>
                    </div>
                </div>
                
                <div class="row">
                    <div class="col-12">
                        <div class="card">
                            <div class="hotel-image" style="height: 300px;">
                                <i class="bi bi-building"></i>
                            </div>
                            <div class="card-body">
                                <h2 class="card-title">${hotel.name}</h2>
                                <div class="stars mb-3">${stars}</div>
                                
                                <div class="row">
                                    <div class="col-md-6">
                                        <p><i class="bi bi-geo-alt"></i> <strong>Адрес:</strong> ${hotel.address}</p>
                                        <p><i class="bi bi-pin-map"></i> <strong>Город:</strong> ${hotel.city}, ${hotel.country}</p>
                                        <p><i class="bi bi-telephone"></i> <strong>Телефон:</strong> ${hotel.phone || 'Не указан'}</p>
                                        <p><i class="bi bi-envelope"></i> <strong>Email:</strong> ${hotel.email || 'Не указан'}</p>
                                    </div>
                                    <div class="col-md-6">
                                        <p>${hotel.description || 'Описание отсутствует'}</p>
                                    </div>
                                </div>
                                
                                <hr>
                                
                                <h4 class="mb-3">Доступные номера</h4>
                                
                                <!-- Фильтры номеров -->
                                <div class="card mb-3 bg-light">
                                    <div class="card-body">
                                        <h6 class="card-title">
                                            <i class="bi bi-funnel me-2"></i>Фильтры поиска номеров
                                        </h6>
                                        <div class="row g-3">
                                            <div class="col-md-9">
                                                <label class="form-label">Тип номера</label>
                                                <select class="form-select" id="roomtype-filter">
                                                    <option value="">Все типы</option>
                                                    ${roomTypes.map(rt => `
                                                        <option value="${rt.roomtype_id}">${rt.type_name}</option>
                                                    `).join('')}
                                                </select>
                                            </div>
                                            <div class="col-md-3">
                                                <label class="form-label d-block">&nbsp;</label>
                                                <button class="btn btn-primary w-100" id="apply-room-filters">
                                                    <i class="bi bi-search me-1"></i>Применить
                                                </button>
                                            </div>
                                        </div>
                                        
                                        <div class="row g-3 mt-2">
                                            <div class="col-12">
                                                <label class="form-label">Удобства (будут показаны номера, имеющие ВСЕ выбранные удобства)</label>
                                                <div class="amenities-filter" id="amenities-filter">
                                                    ${amenities.map(amenity => `
                                                        <div class="form-check form-check-inline">
                                                            <input class="form-check-input amenity-checkbox" type="checkbox" 
                                                                id="amenity-${amenity.amenity_id}" 
                                                                value="${amenity.amenity_id}">
                                                            <label class="form-check-label" for="amenity-${amenity.amenity_id}">
                                                                ${amenity.amenity_name}
                                                            </label>
                                                        </div>
                                                    `).join('')}
                                                </div>
                                            </div>
                                        </div>
                                        
                                        <div class="row g-3 mt-2">
                                            <div class="col-12">
                                                <button class="btn btn-secondary btn-sm" id="reset-room-filters">
                                                    <i class="bi bi-arrow-clockwise me-1"></i>Сбросить фильтры
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                
                                <div id="hotel-rooms">
                                    <div class="text-center">
                                        <div class="spinner-border" role="status"></div>
                                    </div>
                                </div>
                                
                                <hr class="my-4">
                                
                                <h4 class="mb-3">
                                    <i class="bi bi-chat-left-text me-2"></i>Отзывы гостей
                                </h4>
                                <div id="hotel-reviews">
                                    <div class="text-center">
                                        <div class="spinner-border" role="status"></div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            `;
            
            // Обработчики фильтров
            document.getElementById('apply-room-filters').addEventListener('click', () => this.loadHotelRooms(hotelId));
            document.getElementById('reset-room-filters').addEventListener('click', () => {
                document.getElementById('roomtype-filter').value = '';
                document.querySelectorAll('.amenity-checkbox').forEach(cb => cb.checked = false);
                this.loadHotelRooms(hotelId);
            });
            
            // Загрузить номера отеля и отзывы
            await this.loadHotelRooms(hotelId);
            await this.loadHotelReviews(hotelId);
            
        } catch (error) {
            showError(container, error.message);
        }
    }
    
    static async loadHotelRooms(hotelId) {
        const roomsContainer = document.getElementById('hotel-rooms');
        roomsContainer.innerHTML = '<div class="text-center"><div class="spinner-border" role="status"></div></div>';
        
        try {
            // Собираем параметры фильтров
            const roomtypeId = document.getElementById('roomtype-filter')?.value;
            
            // Собираем выбранные удобства
            const selectedAmenities = Array.from(document.querySelectorAll('.amenity-checkbox:checked'))
                .map(cb => cb.value);
            
            // Формируем URL с параметрами
            let url = `/rooms/hotel/${hotelId}`;
            const params = [];
            
            if (roomtypeId) {
                params.push(`roomtype_id=${roomtypeId}`);
            }
            
            if (params.length > 0) {
                url += '?' + params.join('&');
            }
            
            const rooms = await API.request(url);
            
            // Фильтруем по удобствам на клиенте (номера должны иметь ВСЕ выбранные удобства)
            let filteredRooms = rooms;
            if (selectedAmenities.length > 0) {
                filteredRooms = rooms.filter(room => {
                    // Проверяем, что номер имеет ВСЕ выбранные удобства
                    if (!room.amenities || room.amenities.length === 0) {
                        return false;
                    }
                    
                    const roomAmenityIds = room.amenities.map(a => String(a.amenity_id));
                    
                    // Проверяем что каждое выбранное удобство есть у номера
                    return selectedAmenities.every(selectedId => 
                        roomAmenityIds.includes(String(selectedId))
                    );
                });
            }
            
            if (filteredRooms.length === 0) {
                roomsContainer.innerHTML = `
                    <div class="alert alert-info">
                        <i class="bi bi-info-circle me-2"></i>
                        Номера не найдены по заданным критериям. Попробуйте изменить фильтры.
                    </div>
                `;
                return;
            }
            
            const isAuthenticated = Auth.isAuthenticated();
            
            roomsContainer.innerHTML = filteredRooms.map(room => `
                <div class="card mb-3 room-card-item shadow-sm">
                    <div class="card-body">
                        <div class="row align-items-center">
                            <div class="col-md-6">
                                <div class="d-flex align-items-center mb-2">
                                    <h5 class="card-title mb-0 me-3">
                                        <i class="bi bi-door-open me-2 text-primary"></i>Номер ${room.room_number}
                                    </h5>
                                    <span class="badge ${room.is_available ? 'bg-success' : 'bg-secondary'}">
                                        ${room.is_available ? 'Доступен' : 'Занят'}
                                    </span>
                                </div>
                                <p class="card-text text-muted">${room.description || 'Комфортабельный номер'}</p>
                                <div class="room-details">
                                    <p class="mb-1">
                                        <i class="bi bi-building me-2 text-secondary"></i>
                                        <small>Этаж: ${room.floor || 'Не указан'}</small>
                                    </p>
                                    ${room.roomtype_name ? `
                                        <p class="mb-1">
                                            <i class="bi bi-tag me-2 text-secondary"></i>
                                            <small>Тип: <strong>${room.roomtype_name}</strong></small>
                                        </p>
                                    ` : ''}
                                </div>
                            </div>
                            <div class="col-md-3 text-center">
                                <div class="price-box p-3 bg-light rounded">
                                    <h3 class="text-primary mb-1">${formatPrice(room.price_per_night)}</h3>
                                    <p class="text-muted mb-0 small">за ночь</p>
                                </div>
                            </div>
                            <div class="col-md-3 text-end">
                                ${room.is_available && isAuthenticated ? `
                                    <button class="btn btn-primary w-100 mb-2" onclick="Hotels.showBookingModal(${room.room_id}, '${room.room_number}', ${room.price_per_night}, ${hotelId})">
                                        <i class="bi bi-calendar-check me-1"></i>
                                        Забронировать
                                    </button>
                                    <button class="btn btn-outline-info btn-sm w-100" onclick="Hotels.showRoomDetails(${room.room_id})">
                                        <i class="bi bi-info-circle me-1"></i>
                                        Подробнее
                                    </button>
                                ` : room.is_available && !isAuthenticated ? `
                                    <button class="btn btn-primary w-100" onclick="Auth.showLoginModal()">
                                        <i class="bi bi-box-arrow-in-right me-1"></i>
                                        Войти для бронирования
                                    </button>
                                ` : `
                                    <button class="btn btn-secondary w-100" disabled>
                                        <i class="bi bi-x-circle me-1"></i>
                                        Недоступен
                                    </button>
                                `}
                            </div>
                        </div>
                    </div>
                </div>
            `).join('');
            
        } catch (error) {
            roomsContainer.innerHTML = `<p class="text-danger">Ошибка загрузки номеров: ${error.message}</p>`;
        }
    }
    
    static async showRoomDetails(roomId) {
        try {
            const room = await API.request(`/rooms/${roomId}`);
            
            const modalHtml = `
                <div class="modal fade" id="roomDetailsModal" tabindex="-1">
                    <div class="modal-dialog modal-lg">
                        <div class="modal-content">
                            <div class="modal-header">
                                <h5 class="modal-title">
                                    <i class="bi bi-door-open me-2"></i>Номер ${room.room_number}
                                </h5>
                                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                            </div>
                            <div class="modal-body">
                                <div class="row">
                                    <div class="col-md-6">
                                        <h6 class="text-muted">Основная информация</h6>
                                        <p><strong>Этаж:</strong> ${room.floor || 'Не указан'}</p>
                                        <p><strong>Цена за ночь:</strong> ${formatPrice(room.price_per_night)}</p>
                                        <p><strong>Статус:</strong> 
                                            <span class="badge ${room.is_available ? 'bg-success' : 'bg-secondary'}">
                                                ${room.is_available ? 'Доступен' : 'Занят'}
                                            </span>
                                        </p>
                                    </div>
                                    <div class="col-md-6">
                                        <h6 class="text-muted">Описание</h6>
                                        <p>${room.description || 'Описание отсутствует'}</p>
                                    </div>
                                </div>
                                ${room.amenities && room.amenities.length > 0 ? `
                                    <hr>
                                    <div class="row">
                                        <div class="col-12">
                                            <h6 class="text-muted">
                                                <i class="bi bi-star me-2"></i>Удобства
                                            </h6>
                                            <div class="d-flex flex-wrap gap-2">
                                                ${room.amenities.map(amenity => `
                                                    <span class="badge bg-info">
                                                        <i class="bi bi-check-circle me-1"></i>${amenity.amenity_name}
                                                    </span>
                                                `).join('')}
                                            </div>
                                        </div>
                                    </div>
                                ` : ''}
                            </div>
                            <div class="modal-footer">
                                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Закрыть</button>
                                ${room.is_available ? `
                                    <button type="button" class="btn btn-primary" onclick="Hotels.showBookingModal(${room.room_id}, '${room.room_number}', ${room.price_per_night}, ${room.hotel_id}); bootstrap.Modal.getInstance(document.getElementById('roomDetailsModal')).hide();">
                                        <i class="bi bi-calendar-check me-1"></i>Забронировать
                                    </button>
                                ` : ''}
                            </div>
                        </div>
                    </div>
                </div>
            `;
            
            // Удаляем старый модал если есть
            const oldModal = document.getElementById('roomDetailsModal');
            if (oldModal) oldModal.remove();
            
            document.body.insertAdjacentHTML('beforeend', modalHtml);
            const modal = new bootstrap.Modal(document.getElementById('roomDetailsModal'));
            modal.show();
            
        } catch (error) {
            showError('Не удалось загрузить информацию о номере');
        }
    }
    
    static showAddHotelModal() {
        // TODO: Реализовать модальное окно добавления отеля
        alert('Функция добавления отеля в разработке');
    }
    
    static showBookingModal(roomId, roomNumber, pricePerNight, hotelId) {
        // Создать модальное окно
        const modalHtml = `
            <div class="modal fade" id="bookingModal" tabindex="-1">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">Забронировать номер ${roomNumber}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <form id="booking-form">
                            <div class="modal-body">
                                <div class="alert alert-info">
                                    <i class="bi bi-info-circle me-2"></i>
                                    Стоимость: <strong>${formatPrice(pricePerNight)}</strong> за ночь
                                </div>
                                
                                <div class="mb-3">
                                    <label for="check-in-date" class="form-label">Дата заезда *</label>
                                    <input type="date" class="form-control" id="check-in-date" required min="${new Date().toISOString().split('T')[0]}">
                                </div>
                                
                                <div class="mb-3">
                                    <label for="check-out-date" class="form-label">Дата выезда *</label>
                                    <input type="date" class="form-control" id="check-out-date" required min="${new Date().toISOString().split('T')[0]}">
                                </div>
                                
                                <div class="mb-3">
                                    <label for="num-guests" class="form-label">Количество гостей *</label>
                                    <input type="number" class="form-control" id="num-guests" min="1" max="10" value="1" required>
                                </div>
                                
                                <div id="total-price" class="alert alert-success d-none">
                                    <strong>Итого:</strong> <span id="total-amount">0</span> ₽
                                </div>
                                
                                <div id="booking-error" class="alert alert-danger d-none"></div>
                            </div>
                            <div class="modal-footer">
                                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Отмена</button>
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-check-circle me-1"></i>
                                    Подтвердить бронирование
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        `;
        
        // Удалить старый модал если есть
        const oldModal = document.getElementById('bookingModal');
        if (oldModal) oldModal.remove();
        
        // Добавить новый модал
        document.body.insertAdjacentHTML('beforeend', modalHtml);
        const modalElement = document.getElementById('bookingModal');
        const modal = new bootstrap.Modal(modalElement);
        
        // Расчёт стоимости
        const calculateTotal = () => {
            const checkIn = document.getElementById('check-in-date').value;
            const checkOut = document.getElementById('check-out-date').value;
            
            if (checkIn && checkOut) {
                const days = Math.ceil((new Date(checkOut) - new Date(checkIn)) / (1000 * 60 * 60 * 24));
                if (days > 0) {
                    const total = days * pricePerNight;
                    document.getElementById('total-amount').textContent = formatPrice(total);
                    document.getElementById('total-price').classList.remove('d-none');
                } else {
                    document.getElementById('total-price').classList.add('d-none');
                }
            }
        };
        
        document.getElementById('check-in-date').addEventListener('change', calculateTotal);
        document.getElementById('check-out-date').addEventListener('change', calculateTotal);
        
        // Обработчик формы
        document.getElementById('booking-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const checkIn = document.getElementById('check-in-date').value;
            const checkOut = document.getElementById('check-out-date').value;
            const guests = parseInt(document.getElementById('num-guests').value);
            const errorDiv = document.getElementById('booking-error');
            
            // Валидация дат
            if (new Date(checkOut) <= new Date(checkIn)) {
                errorDiv.textContent = 'Дата выезда должна быть позже даты заезда';
                errorDiv.classList.remove('d-none');
                return;
            }
            
            try {
                await bookings.createBooking(roomId, checkIn, checkOut, guests);
                modal.hide();
                showSuccess('Бронирование создано! Перенаправление на страницу бронирований...');
                setTimeout(() => {
                    window.location.href = 'my-bookings.html';
                }, 1500);
            } catch (error) {
                errorDiv.textContent = error.message || 'Не удалось создать бронирование';
                errorDiv.classList.remove('d-none');
            }
        });
        
        modal.show();
    }
    
    static async loadHotelReviews(hotelId) {
        const reviewsContainer = document.getElementById('hotel-reviews');
        
        try {
            const reviews = await API.request(`/reviews/hotel/${hotelId}`);
            
            if (reviews.length === 0) {
                reviewsContainer.innerHTML = `
                    <div class="alert alert-info">
                        <i class="bi bi-info-circle me-2"></i>
                        Пока нет отзывов об этом отеле. Будьте первым, кто оставит отзыв!
                    </div>
                `;
                return;
            }
            
            reviewsContainer.innerHTML = reviews.map(review => {
                const reviewDate = new Date(review.created_at).toLocaleDateString('ru-RU');
                const stars = '⭐'.repeat(review.rating);
                const userName = review.user ? `${review.user.first_name} ${review.user.last_name}` : 'Гость';
                
                return `
                    <div class="card mb-3 shadow-sm">
                        <div class="card-body">
                            <div class="d-flex justify-content-between align-items-start mb-2">
                                <div>
                                    <h6 class="card-title mb-1">
                                        <i class="bi bi-person-circle me-2"></i>${userName}
                                    </h6>
                                    <div class="text-warning mb-1">${stars}</div>
                                </div>
                                <small class="text-muted">${reviewDate}</small>
                            </div>
                            ${review.comment ? `
                                <p class="card-text mb-0">${review.comment}</p>
                            ` : '<p class="card-text text-muted mb-0"><em>Без комментария</em></p>'}
                        </div>
                    </div>
                `;
            }).join('');
            
        } catch (error) {
            reviewsContainer.innerHTML = `
                <div class="alert alert-danger">
                    <i class="bi bi-exclamation-triangle me-2"></i>
                    Не удалось загрузить отзывы
                </div>
            `;
        }
    }

    // Метод для загрузки страницы отелей в режиме только просмотра (для hotel_admin)
    static async loadHotelsPageReadOnly() {
        this.readOnlyMode = true;
        const container = document.getElementById('app-content');
        
        container.innerHTML = `
            <div class="row">
                <div class="col-12">
                    <h2 class="mb-4">
                        <i class="bi bi-building"></i> Доступные отели
                    </h2>
                </div>
            </div>
            
            <!-- Фильтры -->
            <div class="filter-section">
                <div class="row">
                    <div class="col-md-4">
                        <input type="text" class="form-control" id="city-filter" placeholder="Поиск по городу...">
                    </div>
                    <div class="col-md-3">
                        <button class="btn btn-primary" id="apply-filters">
                            <i class="bi bi-search"></i> Поиск
                        </button>
                        <button class="btn btn-secondary" id="reset-filters">
                            <i class="bi bi-arrow-clockwise"></i> Сбросить
                        </button>
                    </div>
                </div>
            </div>
            
            <!-- Список отелей -->
            <div class="row" id="hotels-list"></div>
        `;
        
        // Загрузить отели
        await this.loadHotels();
        
        // Обработчики событий
        document.getElementById('apply-filters').addEventListener('click', () => this.loadHotels());
        document.getElementById('reset-filters').addEventListener('click', () => {
            document.getElementById('city-filter').value = '';
            this.loadHotels();
        });
    }

    // Метод для просмотра отеля в режиме только чтения (без кнопки бронирования)
    static async viewHotelReadOnly(hotelId) {
        const container = document.getElementById('app-content');
        showSpinner(container);
        
        try {
            const hotel = await API.getHotel(hotelId);
            
            // Загружаем типы номеров и удобства
            const [roomTypes, amenities] = await Promise.all([
                API.request('/roomtypes/'),
                API.request('/amenities/')
            ]);
            
            const stars = hotel.star_rating ? '⭐'.repeat(Math.floor(hotel.star_rating)) : '';
            
            container.innerHTML = `
                <div class="row">
                    <div class="col-12">
                        <button class="btn btn-link mb-3" onclick="Hotels.loadHotelsPageReadOnly()">
                            <i class="bi bi-arrow-left"></i> Назад к списку
                        </button>
                    </div>
                </div>
                
                <div class="row">
                    <div class="col-12">
                        <div class="card">
                            <div class="hotel-image" style="height: 300px;">
                                <i class="bi bi-building"></i>
                            </div>
                            <div class="card-body">
                                <h2 class="card-title">${hotel.name}</h2>
                                <div class="stars mb-3">${stars}</div>
                                
                                <div class="row">
                                    <div class="col-md-6">
                                        <p><i class="bi bi-geo-alt"></i> <strong>Адрес:</strong> ${hotel.address}</p>
                                        <p><i class="bi bi-pin-map"></i> <strong>Город:</strong> ${hotel.city}, ${hotel.country}</p>
                                        <p><i class="bi bi-telephone"></i> <strong>Телефон:</strong> ${hotel.phone || 'Не указан'}</p>
                                        <p><i class="bi bi-envelope"></i> <strong>Email:</strong> ${hotel.email || 'Не указан'}</p>
                                    </div>
                                    <div class="col-md-6">
                                        <p>${hotel.description || 'Описание отсутствует'}</p>
                                    </div>
                                </div>
                                
                                <hr>
                                
                                <h4 class="mb-3">Доступные номера</h4>
                                
                                <!-- Фильтры номеров -->
                                <div class="card mb-3 bg-light">
                                    <div class="card-body">
                                        <h6 class="card-title">
                                            <i class="bi bi-funnel me-2"></i>Фильтры поиска номеров
                                        </h6>
                                        <div class="row g-3">
                                            <div class="col-md-9">
                                                <label class="form-label">Тип номера</label>
                                                <select class="form-select" id="roomtype-filter">
                                                    <option value="">Все типы</option>
                                                    ${roomTypes.map(rt => `
                                                        <option value="${rt.roomtype_id}">${rt.type_name}</option>
                                                    `).join('')}
                                                </select>
                                            </div>
                                            <div class="col-md-3">
                                                <label class="form-label d-block">&nbsp;</label>
                                                <button class="btn btn-primary w-100" id="apply-room-filters">
                                                    <i class="bi bi-search me-1"></i>Применить
                                                </button>
                                            </div>
                                        </div>
                                        
                                        <div class="row g-3 mt-2">
                                            <div class="col-12">
                                                <label class="form-label">Удобства (будут показаны номера, имеющие ВСЕ выбранные удобства)</label>
                                                <div class="amenities-filter" id="amenities-filter">
                                                    ${amenities.map(amenity => `
                                                        <div class="form-check form-check-inline">
                                                            <input class="form-check-input amenity-checkbox" type="checkbox" 
                                                                id="amenity-${amenity.amenity_id}" 
                                                                value="${amenity.amenity_id}">
                                                            <label class="form-check-label" for="amenity-${amenity.amenity_id}">
                                                                ${amenity.amenity_name}
                                                            </label>
                                                        </div>
                                                    `).join('')}
                                                </div>
                                            </div>
                                        </div>
                                        
                                        <div class="row g-3 mt-2">
                                            <div class="col-12">
                                                <button class="btn btn-secondary btn-sm" id="reset-room-filters">
                                                    <i class="bi bi-arrow-clockwise me-1"></i>Сбросить фильтры
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                
                                <div id="hotel-rooms">
                                    <div class="text-center">
                                        <div class="spinner-border" role="status"></div>
                                    </div>
                                </div>
                                
                                <hr class="my-4">
                                
                                <h4 class="mb-3">
                                    <i class="bi bi-chat-left-text me-2"></i>Отзывы гостей
                                </h4>
                                <div id="hotel-reviews">
                                    <div class="text-center">
                                        <div class="spinner-border" role="status"></div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            `;
            
            // Обработчики фильтров
            document.getElementById('apply-room-filters').addEventListener('click', () => this.loadHotelRoomsReadOnly(hotelId));
            document.getElementById('reset-room-filters').addEventListener('click', () => {
                document.getElementById('roomtype-filter').value = '';
                document.querySelectorAll('.amenity-checkbox').forEach(cb => cb.checked = false);
                this.loadHotelRoomsReadOnly(hotelId);
            });
            
            // Загрузить номера отеля и отзывы
            await this.loadHotelRoomsReadOnly(hotelId);
            await this.loadHotelReviews(hotelId);
            
        } catch (error) {
            showError(container, error.message);
        }
    }

    // Метод для загрузки номеров отеля без кнопки бронирования
    static async loadHotelRoomsReadOnly(hotelId) {
        const roomsContainer = document.getElementById('hotel-rooms');
        roomsContainer.innerHTML = '<div class="text-center"><div class="spinner-border" role="status"></div></div>';
        
        try {
            // Собираем параметры фильтров
            const roomtypeId = document.getElementById('roomtype-filter')?.value;
            
            // Собираем выбранные удобства
            const selectedAmenities = Array.from(document.querySelectorAll('.amenity-checkbox:checked'))
                .map(cb => cb.value);
            
            // Формируем URL с параметрами
            let url = `/rooms/hotel/${hotelId}`;
            const params = [];
            
            if (roomtypeId) {
                params.push(`roomtype_id=${roomtypeId}`);
            }
            
            if (params.length > 0) {
                url += '?' + params.join('&');
            }
            
            const rooms = await API.request(url);
            
            // Фильтруем по удобствам на клиенте
            let filteredRooms = rooms;
            if (selectedAmenities.length > 0) {
                filteredRooms = rooms.filter(room => {
                    if (!room.amenities || room.amenities.length === 0) {
                        return false;
                    }
                    
                    const roomAmenityIds = room.amenities.map(a => String(a.amenity_id));
                    return selectedAmenities.every(selectedId => 
                        roomAmenityIds.includes(String(selectedId))
                    );
                });
            }
            
            if (filteredRooms.length === 0) {
                roomsContainer.innerHTML = `
                    <div class="alert alert-info">
                        <i class="bi bi-info-circle me-2"></i>
                        Номера не найдены по заданным критериям. Попробуйте изменить фильтры.
                    </div>
                `;
                return;
            }
            
            roomsContainer.innerHTML = filteredRooms.map(room => `
                <div class="card mb-3 room-card-item shadow-sm">
                    <div class="card-body">
                        <div class="row align-items-center">
                            <div class="col-md-6">
                                <div class="d-flex align-items-center mb-2">
                                    <h5 class="card-title mb-0 me-3">
                                        <i class="bi bi-door-open me-2 text-primary"></i>Номер ${room.room_number}
                                    </h5>
                                    <span class="badge ${room.is_available ? 'bg-success' : 'bg-secondary'}">
                                        ${room.is_available ? 'Доступен' : 'Занят'}
                                    </span>
                                </div>
                                <p class="card-text text-muted">${room.description || 'Комфортабельный номер'}</p>
                                <div class="room-details">
                                    <p class="mb-1">
                                        <i class="bi bi-building me-2 text-secondary"></i>
                                        <small>Этаж: ${room.floor || 'Не указан'}</small>
                                    </p>
                                    ${room.roomtype_name ? `
                                        <p class="mb-1">
                                            <i class="bi bi-tag me-2 text-secondary"></i>
                                            <small>Тип: <strong>${room.roomtype_name}</strong></small>
                                        </p>
                                    ` : ''}
                                </div>
                            </div>
                            <div class="col-md-6 text-center">
                                <div class="price-box p-3 bg-light rounded">
                                    <h3 class="text-primary mb-1">${formatPrice(room.price_per_night)}</h3>
                                    <p class="text-muted mb-0 small">за ночь</p>
                                </div>
                            </div>
                        </div>
                        
                        ${room.amenities && room.amenities.length > 0 ? `
                            <div class="mt-3">
                                <h6 class="text-muted mb-2">
                                    <i class="bi bi-star me-1"></i>Удобства:
                                </h6>
                                <div class="amenities-list">
                                    ${room.amenities.map(amenity => `
                                        <span class="badge bg-light text-dark me-1 mb-1">
                                            <i class="bi bi-check-circle-fill text-success me-1"></i>
                                            ${amenity.amenity_name}
                                        </span>
                                    `).join('')}
                                </div>
                            </div>
                        ` : ''}
                    </div>
                </div>
            `).join('');
            
        } catch (error) {
            roomsContainer.innerHTML = `
                <div class="alert alert-danger">
                    <i class="bi bi-exclamation-triangle me-2"></i>
                    Не удалось загрузить номера
                </div>
            `;
        }
    }
}

function formatPrice(price) {
    return new Intl.NumberFormat('ru-RU', { 
        style: 'currency', 
        currency: 'RUB',
        minimumFractionDigits: 0
    }).format(price);
}
