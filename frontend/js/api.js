// API Configuration
const API_BASE_URL = "http://localhost:8000/api/v1";

// API Helper Functions
class API {
  static async request(endpoint, options = {}) {
    const token = localStorage.getItem("access_token");

    console.log(
      "[API Request]",
      endpoint,
      "Token:",
      token ? "present" : "missing"
    );

    const headers = options.headers || {};

    // Добавляем Content-Type только если не задан
    if (!headers["Content-Type"]) {
      headers["Content-Type"] = "application/json";
    }

    if (token) {
      headers["Authorization"] = `Bearer ${token}`;
    }

    const config = {
      ...options,
      headers,
    };

    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`, config);

      if (!response.ok) {
        if (response.status === 401) {
          // Токен истек - выход
          localStorage.removeItem("access_token");
          localStorage.removeItem("user_data");
          window.location.reload();
        }

        const error = await response.json().catch(() => ({}));
        console.error("[API] Error response:", error);

        // Если это массив ошибок валидации (422)
        if (error.detail && Array.isArray(error.detail)) {
          const messages = error.detail
            .map((e) => `${e.loc.join(".")}: ${e.msg}`)
            .join(", ");
          throw new Error(messages);
        }

        throw new Error(error.detail || "Ошибка сервера");
      }

      // Если ответ 204 No Content
      if (response.status === 204) {
        return null;
      }

      return await response.json();
    } catch (error) {
      console.error("API Error:", error);
      throw error;
    }
  }

  // Auth endpoints
  static async login(email, password) {
    const formData = new URLSearchParams();
    formData.append("username", email);
    formData.append("password", password);

    return await this.request("/auth/login", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: formData,
    });
  }

  static async register(userData) {
    return await this.request("/auth/register", {
      method: "POST",
      body: JSON.stringify(userData),
    });
  }

  static async getCurrentUser() {
    return await this.request("/auth/me");
  }

  // Hotels endpoints
  static async getHotels(params = {}) {
    const queryString = new URLSearchParams(params).toString();
    return await this.request(`/hotels?${queryString}`);
  }

  static async getHotel(hotelId) {
    return await this.request(`/hotels/${hotelId}`);
  }

  static async createHotel(hotelData) {
    return await this.request("/hotels", {
      method: "POST",
      body: JSON.stringify(hotelData),
    });
  }

  static async updateHotel(hotelId, hotelData) {
    return await this.request(`/hotels/${hotelId}`, {
      method: "PATCH",
      body: JSON.stringify(hotelData),
    });
  }

  // Rooms endpoints
  static async getHotelRooms(hotelId, params = {}) {
    const queryString = new URLSearchParams(params).toString();
    const query = queryString ? `?${queryString}` : "";
    return await this.request(`/rooms/hotel/${hotelId}${query}`);
  }

  static async getRoom(roomId) {
    return await this.request(`/rooms/${roomId}`);
  }

  static async deleteHotel(hotelId) {
    return await this.request(`/hotels/${hotelId}`, {
      method: "DELETE",
    });
  }

  // Rooms endpoints
  static async getRooms(hotelId) {
    return await this.request(`/rooms?hotel_id=${hotelId}`);
  }

  static async getRoom(roomId) {
    return await this.request(`/rooms/${roomId}`);
  }

  // Bookings endpoints
  static async getBookings() {
    return await this.request("/bookings");
  }

  static async createBooking(bookingData) {
    return await this.request("/bookings", {
      method: "POST",
      body: JSON.stringify(bookingData),
    });
  }

  static async cancelBooking(bookingId) {
    return await this.request(`/bookings/${bookingId}/cancel`, {
      method: "POST",
    });
  }

  // Reviews endpoints
  static async getReviews(hotelId) {
    return await this.request(`/reviews?hotel_id=${hotelId}`);
  }

  static async createReview(reviewData) {
    return await this.request("/reviews/", {
      method: "POST",
      body: JSON.stringify(reviewData),
    });
  }

  // Users endpoints (admin only)
  static async getUsers() {
    return await this.request("/users");
  }

  static async getUser(userId) {
    return await this.request(`/users/${userId}`);
  }

  static async updateUser(userId, userData) {
    return await this.request(`/users/${userId}`, {
      method: "PATCH",
      body: JSON.stringify(userData),
    });
  }
}

// Utility functions
function showSpinner(container) {
  container.innerHTML = `
        <div class="spinner-container">
            <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">Загрузка...</span>
            </div>
        </div>
    `;
}

function showError(container, message) {
  container.innerHTML = `
        <div class="error-container">
            <i class="bi bi-exclamation-circle text-danger" style="font-size: 3rem;"></i>
            <h4 class="mt-3">Ошибка</h4>
            <p class="text-muted">${message}</p>
        </div>
    `;
}

function showSuccess(message) {
  // Можно использовать toast уведомления
  const alert = document.createElement("div");
  alert.className =
    "alert alert-success alert-dismissible fade show position-fixed top-0 start-50 translate-middle-x mt-3";
  alert.style.zIndex = "9999";
  alert.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
  document.body.appendChild(alert);

  setTimeout(() => {
    alert.remove();
  }, 3000);
}

function formatDate(dateString) {
  return new Date(dateString).toLocaleDateString("ru-RU");
}

function formatDateTime(dateString) {
  return new Date(dateString).toLocaleString("ru-RU");
}

function formatPrice(price) {
  return new Intl.NumberFormat("ru-RU", {
    style: "currency",
    currency: "RUB",
  }).format(price);
}
