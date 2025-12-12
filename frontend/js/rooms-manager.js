// rooms-manager.js - Управление номерами отеля

class RoomsManager {
    constructor() {
        this.hotelId = null;
        this.hotel = null;
        this.rooms = [];
        this.allRooms = [];
        this.roomTypes = [];
        this.amenities = [];
        this.roomModal = null;
        this.deleteRoomModal = null;
        this.roomToDelete = null;
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

            // Инициализация модальных окон
            this.roomModal = new bootstrap.Modal(document.getElementById('roomModal'));
            this.deleteRoomModal = new bootstrap.Modal(document.getElementById('deleteRoomModal'));

            // Загружаем данные
            await Promise.all([
                this.loadHotelInfo(),
                this.loadRoomTypes(),
                this.loadAmenities()
            ]);

            await this.loadRooms();
            
        } catch (error) {
            console.error('[RoomsManager] Init error:', error);
            showError('Ошибка инициализации');
        }
    }

    async loadHotelInfo() {
        try {
            this.hotel = await API.request(`/hotels/${this.hotelId}`);
            document.getElementById('hotel-name').textContent = this.hotel.name;
        } catch (error) {
            console.error('[RoomsManager] Error loading hotel:', error);
            document.getElementById('hotel-name').textContent = 'Ошибка загрузки';
        }
    }

    async loadRoomTypes() {
        try {
            this.roomTypes = await API.request('/roomtypes/');
            
            // Заполняем селект в модальном окне
            const roomTypeSelect = document.getElementById('room-type');
            roomTypeSelect.innerHTML = '<option value="">Выберите тип</option>' +
                this.roomTypes.map(type => 
                    `<option value="${type.roomtype_id}">${type.type_name} (до ${type.max_occupancy} чел.)</option>`
                ).join('');
            
            // Заполняем фильтр
            const filterSelect = document.getElementById('filter-roomtype');
            filterSelect.innerHTML = '<option value="">Все типы</option>' +
                this.roomTypes.map(type => 
                    `<option value="${type.roomtype_id}">${type.type_name}</option>`
                ).join('');
                
        } catch (error) {
            console.error('[RoomsManager] Error loading room types:', error);
            showError('Ошибка загрузки типов номеров');
        }
    }

    async loadAmenities() {
        try {
            this.amenities = await API.request('/amenities/');
            
            // Заполняем чекбоксы удобств
            const container = document.getElementById('amenities-checkboxes');
            container.innerHTML = this.amenities.map(amenity => `
                <div class="col-md-4">
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" 
                               id="amenity-${amenity.amenity_id}" 
                               value="${amenity.amenity_id}">
                        <label class="form-check-label" for="amenity-${amenity.amenity_id}">
                            ${amenity.amenity_name}
                        </label>
                    </div>
                </div>
            `).join('');
            
        } catch (error) {
            console.error('[RoomsManager] Error loading amenities:', error);
        }
    }

    async loadRooms() {
        const container = document.getElementById('rooms-container');
        container.innerHTML = '<div class="text-center my-5"><div class="spinner-border text-primary"></div></div>';
        
        try {
            this.allRooms = await API.request(`/rooms/hotel/${this.hotelId}`);
            this.rooms = [...this.allRooms];
            
            this.renderRooms();
            
        } catch (error) {
            console.error('[RoomsManager] Error loading rooms:', error);
            container.innerHTML = '<div class="alert alert-danger">Ошибка загрузки номеров</div>';
        }
    }

    renderRooms() {
        const container = document.getElementById('rooms-container');
        
        if (this.rooms.length === 0) {
            container.innerHTML = '<div class="alert alert-info"><i class="bi bi-info-circle me-2"></i>Номера не найдены</div>';
            return;
        }

        container.innerHTML = this.rooms.map(room => {
            const roomType = this.roomTypes.find(t => t.roomtype_id === room.roomtype_id);
            const roomTypeName = roomType ? roomType.type_name : 'Не указан';
            
            return `
                <div class="card mb-3 shadow-sm">
                    <div class="card-body">
                        <div class="row align-items-center">
                            <div class="col-md-8">
                                <div class="d-flex align-items-center mb-2">
                                    <h4 class="mb-0 me-3">
                                        <i class="bi bi-door-open text-primary me-2"></i>
                                        Номер ${room.room_number}
                                    </h4>
                                    <span class="badge ${room.is_available ? 'bg-success' : 'bg-secondary'}">
                                        ${room.is_available ? 'Доступен' : 'Недоступен'}
                                    </span>
                                </div>
                                
                                <div class="row text-muted">
                                    <div class="col-md-6">
                                        <p class="mb-1">
                                            <i class="bi bi-tag me-2"></i>
                                            <strong>Тип:</strong> ${roomTypeName}
                                        </p>
                                        <p class="mb-1">
                                            <i class="bi bi-building me-2"></i>
                                            <strong>Этаж:</strong> ${room.floor || 'Не указан'}
                                        </p>
                                    </div>
                                    <div class="col-md-6">
                                        <p class="mb-1">
                                            <i class="bi bi-cash me-2"></i>
                                            <strong>Цена:</strong> ${room.price_per_night} ₽/ночь
                                        </p>
                                    </div>
                                </div>
                                
                                ${room.amenities && room.amenities.length > 0 ? `
                                    <div class="mt-2">
                                        <small class="text-muted">
                                            <i class="bi bi-star me-1"></i>
                                            <strong>Удобства:</strong> ${room.amenities.map(a => a.amenity_name).join(', ')}
                                        </small>
                                    </div>
                                ` : ''}
                            </div>
                            
                            <div class="col-md-4 text-end">
                                <button class="btn btn-primary mb-2 w-100" 
                                        onclick="roomsManager.showEditRoomModal(${room.room_id})">
                                    <i class="bi bi-pencil-square me-1"></i>Редактировать
                                </button>
                                <button class="btn btn-danger w-100" 
                                        onclick="roomsManager.showDeleteRoomModal(${room.room_id}, '${room.room_number}')">
                                    <i class="bi bi-trash me-1"></i>Удалить
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            `;
        }).join('');
    }

    applyFilters() {
        const typeFilter = document.getElementById('filter-roomtype').value;

        this.rooms = this.allRooms.filter(room => {
            if (typeFilter && room.roomtype_id != typeFilter) return false;
            return true;
        });

        this.renderRooms();
    }

    resetFilters() {
        document.getElementById('filter-roomtype').value = '';
        this.rooms = [...this.allRooms];
        this.renderRooms();
    }

    showAddRoomModal() {
        document.getElementById('roomModalTitle').textContent = 'Добавить номер';
        document.getElementById('roomForm').reset();
        document.getElementById('room-id').value = '';
        
        // Сбрасываем все чекбоксы удобств
        this.amenities.forEach(amenity => {
            document.getElementById(`amenity-${amenity.amenity_id}`).checked = false;
        });
        
        this.roomModal.show();
    }

    async showEditRoomModal(roomId) {
        const room = this.allRooms.find(r => r.room_id === roomId);
        if (!room) {
            showError('Номер не найден');
            return;
        }

        document.getElementById('roomModalTitle').textContent = 'Редактировать номер';
        document.getElementById('room-id').value = room.room_id;
        document.getElementById('room-number').value = room.room_number;
        document.getElementById('room-floor').value = room.floor || '';
        document.getElementById('room-type').value = room.roomtype_id;
        document.getElementById('room-price').value = room.price_per_night;
        document.getElementById('room-available').checked = room.is_available;

        // Загружаем удобства номера
        try {
            const roomAmenities = room.amenities || [];
            const amenityIds = roomAmenities.map(a => a.amenity_id);
            
            this.amenities.forEach(amenity => {
                const checkbox = document.getElementById(`amenity-${amenity.amenity_id}`);
                if (checkbox) {
                    checkbox.checked = amenityIds.includes(amenity.amenity_id);
                }
            });
        } catch (error) {
            console.error('[RoomsManager] Error loading room amenities:', error);
        }

        this.roomModal.show();
    }

    async saveRoom() {
        const roomId = document.getElementById('room-id').value;
        const roomNumber = document.getElementById('room-number').value.trim();
        const floor = document.getElementById('room-floor').value;
        const typeId = document.getElementById('room-type').value;
        const price = document.getElementById('room-price').value;
        const isAvailable = document.getElementById('room-available').checked;

        if (!roomNumber || !typeId || !price) {
            showError('Заполните все обязательные поля');
            return;
        }

        // Собираем выбранные удобства
        const selectedAmenities = this.amenities
            .filter(amenity => document.getElementById(`amenity-${amenity.amenity_id}`).checked)
            .map(amenity => amenity.amenity_id);

        const roomData = {
            hotel_id: this.hotelId,
            room_number: roomNumber,
            floor: floor ? parseInt(floor) : null,
            roomtype_id: parseInt(typeId),
            price_per_night: parseFloat(price),
            is_available: isAvailable,
            amenity_ids: selectedAmenities
        };

        try {
            if (roomId) {
                // Обновление существующего номера
                await API.request(`/rooms/${roomId}`, {
                    method: 'PUT',
                    body: JSON.stringify(roomData)
                });
                showSuccess('Номер успешно обновлен');
            } else {
                // Создание нового номера
                await API.request('/rooms/', {
                    method: 'POST',
                    body: JSON.stringify(roomData)
                });
                showSuccess('Номер успешно добавлен');
            }

            this.roomModal.hide();
            await this.loadRooms();
            
        } catch (error) {
            console.error('[RoomsManager] Error saving room:', error);
            showError(error.message || 'Ошибка сохранения номера');
        }
    }

    showDeleteRoomModal(roomId, roomNumber) {
        this.roomToDelete = roomId;
        document.getElementById('delete-room-number').textContent = roomNumber;
        this.deleteRoomModal.show();
    }

    async confirmDeleteRoom() {
        if (!this.roomToDelete) return;

        try {
            await API.request(`/rooms/${this.roomToDelete}`, {
                method: 'DELETE'
            });

            showSuccess('Номер успешно удален');
            this.deleteRoomModal.hide();
            this.roomToDelete = null;
            await this.loadRooms();
            
        } catch (error) {
            console.error('[RoomsManager] Error deleting room:', error);
            showError(error.message || 'Ошибка удаления номера');
        }
    }
}

// Создаем глобальный экземпляр
const roomsManager = new RoomsManager();
