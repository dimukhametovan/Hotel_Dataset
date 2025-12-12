// Authentication Module
class Auth {
    static init() {
        this.setupEventListeners();
        this.checkAuthStatus();
    }
    
    static setupEventListeners() {
        // Login modal
        document.getElementById('nav-login').addEventListener('click', (e) => {
            e.preventDefault();
            this.showLoginModal();
        });
        
        // Register link
        document.getElementById('show-register').addEventListener('click', (e) => {
            e.preventDefault();
            this.showRegisterModal();
        });
        
        // Login form
        document.getElementById('login-form').addEventListener('submit', (e) => {
            e.preventDefault();
            this.handleLogin();
        });
        
        // Register form
        document.getElementById('register-form').addEventListener('submit', (e) => {
            e.preventDefault();
            this.handleRegister();
        });
        
        // Logout
        document.getElementById('nav-logout').addEventListener('click', (e) => {
            e.preventDefault();
            this.logout();
        });
    }
    
    static showLoginModal() {
        const modal = new bootstrap.Modal(document.getElementById('loginModal'));
        modal.show();
    }
    
    static showRegisterModal() {
        // Закрыть login modal
        const loginModal = bootstrap.Modal.getInstance(document.getElementById('loginModal'));
        if (loginModal) {
            loginModal.hide();
        }
        
        // Открыть register modal
        const modal = new bootstrap.Modal(document.getElementById('registerModal'));
        modal.show();
    }
    
    static async handleLogin() {
        const email = document.getElementById('login-email').value;
        const password = document.getElementById('login-password').value;
        const errorDiv = document.getElementById('login-error');
        
        try {
            console.log('[Auth] Attempting login...');
            const data = await API.login(email, password);
            console.log('[Auth] Login response:', data);
            
            // Сохранить токен
            localStorage.setItem('access_token', data.access_token);
            console.log('[Auth] Token saved:', data.access_token);
            
            // Получить данные пользователя
            console.log('[Auth] Fetching user data...');
            const userData = await API.getCurrentUser();
            console.log('[Auth] User data received:', userData);
            localStorage.setItem('user_data', JSON.stringify(userData));
            
            // Закрыть модал
            const modal = bootstrap.Modal.getInstance(document.getElementById('loginModal'));
            modal.hide();
            
            // Обновить UI
            this.updateUI(userData);
            
            showSuccess('Вы успешно вошли в систему!');
            
            // Перенаправить в зависимости от роли
            if (userData.role === 'guest') {
                window.location.href = 'my-bookings.html';
            } else if (userData.role === 'hotel_admin') {
                window.location.href = 'hotel-admin.html';
            } else if (userData.role === 'system_admin') {
                window.location.href = 'system-admin.html';
            } else {
                App.loadPage('hotels');
            }
            
        } catch (error) {
            console.error('[Auth] Login error:', error);
            errorDiv.textContent = error.message;
            errorDiv.classList.remove('d-none');
        }
    }
    
    static async handleRegister() {
        const userData = {
            email: document.getElementById('reg-email').value,
            password: document.getElementById('reg-password').value,
            first_name: document.getElementById('reg-first-name').value,
            last_name: document.getElementById('reg-last-name').value,
            phone: document.getElementById('reg-phone').value || null
        };
        
        const errorDiv = document.getElementById('register-error');
        
        try {
            await API.register(userData);
            
            // Закрыть модал
            const modal = bootstrap.Modal.getInstance(document.getElementById('registerModal'));
            modal.hide();
            
            showSuccess('Регистрация успешна! Теперь войдите в систему.');
            
            // Показать login modal
            this.showLoginModal();
            
            // Заполнить email
            document.getElementById('login-email').value = userData.email;
            
        } catch (error) {
            errorDiv.textContent = error.message;
            errorDiv.classList.remove('d-none');
        }
    }
    
    static logout() {
        localStorage.removeItem('access_token');
        localStorage.removeItem('user_data');
        
        // Перенаправить на главную страницу сразу
        window.location.href = 'index.html';
    }
    
    static checkAuthStatus() {
        const token = localStorage.getItem('access_token');
        const userData = localStorage.getItem('user_data');
        
        if (token && userData) {
            try {
                const user = JSON.parse(userData);
                this.updateUI(user);
            } catch (error) {
                console.error('Error parsing user data:', error);
                this.logout();
            }
        }
    }
    
    static updateUI(user) {
        const loginItem = document.getElementById('login-item');
        const logoutItem = document.getElementById('logout-item');
        const userInfoItem = document.getElementById('user-info-item');
        const bookingsItem = document.getElementById('nav-bookings-item');
        const adminItem = document.getElementById('nav-admin-item');
        
        if (user) {
            // Пользователь авторизован
            loginItem.classList.add('d-none');
            logoutItem.classList.remove('d-none');
            userInfoItem.classList.remove('d-none');
            
            document.getElementById('user-name').textContent = `${user.first_name} ${user.last_name}`;
            document.getElementById('user-role').textContent = this.getRoleDisplay(user.role);
            
            // Показать раздел бронирований
            bookingsItem.classList.remove('d-none');
            
            // Показать админ-панель для админов
            if (user.role === 'hotel_admin' || user.role === 'system_admin') {
                adminItem.classList.remove('d-none');
            }
        } else {
            // Пользователь не авторизован
            loginItem.classList.remove('d-none');
            logoutItem.classList.add('d-none');
            userInfoItem.classList.add('d-none');
            bookingsItem.classList.add('d-none');
            adminItem.classList.add('d-none');
        }
    }
    
    static getRoleDisplay(role) {
        const roles = {
            'guest': 'Гость',
            'hotel_admin': 'Админ отеля',
            'system_admin': 'Системный админ'
        };
        return roles[role] || role;
    }
    
    static isAuthenticated() {
        return !!localStorage.getItem('access_token');
    }
    
    static getCurrentUser() {
        const userData = localStorage.getItem('user_data');
        return userData ? JSON.parse(userData) : null;
    }
    
    static hasRole(...roles) {
        const user = this.getCurrentUser();
        return user && roles.includes(user.role);
    }

    static checkUserActive() {
        const user = this.getCurrentUser();
        if (user && !user.is_active) {
            return false;
        }
        return true;
    }

    static showBlockedMessage() {
        const container = document.getElementById('app-content') || document.querySelector('.container');
        if (container) {
            container.innerHTML = `
                <div class="alert alert-danger text-center mt-5">
                    <h3><i class="bi bi-exclamation-triangle-fill me-2"></i>Аккаунт заблокирован</h3>
                    <p class="mb-3">Извините, ваш аккаунт был заблокирован администратором.</p>
                    <p class="mb-0">Для получения дополнительной информации обратитесь к системному администратору.</p>
                    <hr>
                    <button class="btn btn-primary" onclick="Auth.logout()">
                        <i class="bi bi-box-arrow-right me-1"></i>Выйти
                    </button>
                </div>
            `;
        }
    }
}
