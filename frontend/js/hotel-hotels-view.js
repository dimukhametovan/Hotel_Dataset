// hotel-hotels-view.js - Просмотр отелей для админа отеля

class HotelHotelsView {
    constructor() {
        this.hotels = [];
        this.filteredHotels = [];
    }

    async init() {
        try {
            await this.loadHotels();
            this.setupEventListeners();
        } catch (error) {
            console.error('[HotelHotelsView] Init error:', error);
            showError('Ошибка инициализации');
        }
    }

    setupEventListeners() {
        document.getElementById('search-input').addEventListener('input', () => this.filterHotels());
        document.getElementById('city-filter').addEventListener('change', () => this.filterHotels());
        document.getElementById('reset-filters').addEventListener('click', () => this.resetFilters());
    }

    async loadHotels() {
        try {
            this.hotels = await API.request('/hotels/', 'GET');
            this.filteredHotels = [...this.hotels];
            this.populateCityFilter();
            this.renderHotels();
        } catch (error) {
            console.error('[HotelHotelsView] Error loading hotels:', error);
            showError('Ошибка загрузки отелей');
        }
    }

    populateCityFilter() {
        const cities = [...new Set(this.hotels.map(h => h.city))].sort();
        const select = document.getElementById('city-filter');
        select.innerHTML = '<option value="">Все города</option>' +
            cities.map(city => `<option value="${city}">${city}</option>`).join('');
    }

    filterHotels() {
        const searchText = document.getElementById('search-input').value.toLowerCase();
        const selectedCity = document.getElementById('city-filter').value;

        this.filteredHotels = this.hotels.filter(hotel => {
            const matchesSearch = !searchText || 
                hotel.name.toLowerCase().includes(searchText) ||
                hotel.city.toLowerCase().includes(searchText) ||
                (hotel.address && hotel.address.toLowerCase().includes(searchText));
            
            const matchesCity = !selectedCity || hotel.city === selectedCity;

            return matchesSearch && matchesCity;
        });

        this.renderHotels();
    }

    resetFilters() {
        document.getElementById('search-input').value = '';
        document.getElementById('city-filter').value = '';
        this.filteredHotels = [...this.hotels];
        this.renderHotels();
    }

    renderHotels() {
        const container = document.getElementById('hotels-list');

        if (this.filteredHotels.length === 0) {
            container.innerHTML = `
                <div class="alert alert-info text-center">
                    <i class="bi bi-info-circle me-2"></i>
                    Отели не найдены
                </div>
            `;
            return;
        }

        container.innerHTML = `
            <div class="row g-4">
                ${this.filteredHotels.map(hotel => this.renderHotelCard(hotel)).join('')}
            </div>
        `;
    }

    renderHotelCard(hotel) {
        const stars = hotel.star_rating ? '⭐'.repeat(Math.round(hotel.star_rating)) : '';
        
        return `
            <div class="col-md-6 col-lg-4">
                <div class="card h-100 shadow-sm">
                    <div class="card-body">
                        <h5 class="card-title">
                            ${hotel.name}
                            ${hotel.star_rating ? `<span class="text-warning ms-2">${stars}</span>` : ''}
                        </h5>
                        <p class="card-text text-muted mb-2">
                            <i class="bi bi-geo-alt me-1"></i>${hotel.city}, ${hotel.country}
                        </p>
                        <p class="card-text small text-muted mb-2">
                            <i class="bi bi-building me-1"></i>${hotel.address}
                        </p>
                        ${hotel.phone ? `
                            <p class="card-text small text-muted mb-2">
                                <i class="bi bi-telephone me-1"></i>${hotel.phone}
                            </p>
                        ` : ''}
                        ${hotel.description ? `
                            <p class="card-text small mt-3">${hotel.description.substring(0, 100)}${hotel.description.length > 100 ? '...' : ''}</p>
                        ` : ''}
                    </div>
                </div>
            </div>
        `;
    }
}

// Создаем глобальный экземпляр
const hotelHotelsView = new HotelHotelsView();
