// Main Application
class App {
    static init() {
        Auth.init();
        this.setupNavigation();
        this.loadPage('hotels'); // Загрузить главную страницу
    }
    
    static setupNavigation() {
        document.getElementById('nav-hotels').addEventListener('click', (e) => {
            e.preventDefault();
            this.loadPage('hotels');
        });
        
        // Ссылка на бронирования ведет на отдельную страницу my-bookings.html
        // Не нужно перехватывать клик
        
        const adminLink = document.getElementById('nav-admin');
        if (adminLink) {
            adminLink.addEventListener('click', (e) => {
                e.preventDefault();
                this.loadPage('admin');
            });
        }
    }
    
    static loadPage(page) {
        // Проверить, заблокирован ли пользователь
        if (Auth.isAuthenticated() && !Auth.checkUserActive()) {
            Auth.showBlockedMessage();
            return;
        }

        // Обновить активный пункт меню
        document.querySelectorAll('.nav-link').forEach(link => {
            link.classList.remove('active');
        });
        
        switch(page) {
            case 'hotels':
                document.getElementById('nav-hotels').classList.add('active');
                Hotels.loadHotelsPage();
                break;
            
            case 'bookings':
                if (!Auth.isAuthenticated()) {
                    Auth.showLoginModal();
                    return;
                }
                document.getElementById('nav-bookings').classList.add('active');
                this.loadBookingsPage();
                break;
            
            case 'admin':
                if (!Auth.hasRole('hotel_admin', 'system_admin')) {
                    showError(document.getElementById('app-content'), 'Доступ запрещен');
                    return;
                }
                document.getElementById('nav-admin').classList.add('active');
                this.loadAdminPage();
                break;
            
            default:
                Hotels.loadHotelsPage();
        }
    }
    
    static loadBookingsPage() {
        const container = document.getElementById('app-content');
        
        container.innerHTML = `
            <div class="row">
                <div class="col-12">
                    <h2 class="mb-4">
                        <i class="bi bi-calendar-check"></i> Мои бронирования
                    </h2>
                </div>
            </div>
            
            <div class="row">
                <div class="col-12">
                    <div class="alert alert-info">
                        <i class="bi bi-info-circle"></i> Функционал бронирований в разработке
                    </div>
                </div>
            </div>
        `;
    }
    
    static loadAdminPage() {
        const container = document.getElementById('app-content');
        const user = Auth.getCurrentUser();
        
        container.innerHTML = `
            <div class="row">
                <div class="col-12">
                    <h2 class="mb-4">
                        <i class="bi bi-speedometer2"></i> Админ-панель
                    </h2>
                </div>
            </div>
            
            <div class="row">
                <div class="col-md-4">
                    <div class="stat-card">
                        <h3><i class="bi bi-building"></i></h3>
                        <p>Отели</p>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="stat-card">
                        <h3><i class="bi bi-door-open"></i></h3>
                        <p>Номера</p>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="stat-card">
                        <h3><i class="bi bi-calendar-check"></i></h3>
                        <p>Бронирования</p>
                    </div>
                </div>
            </div>
            
            <div class="row mt-4">
                <div class="col-12">
                    <div class="alert alert-info">
                        <i class="bi bi-info-circle"></i> Админ-панель в разработке. Доступна роль: <strong>${Auth.getRoleDisplay(user.role)}</strong>
                    </div>
                </div>
            </div>
        `;
    }
}

// Инициализация при загрузке страницы
document.addEventListener('DOMContentLoaded', () => {
    App.init();
});
