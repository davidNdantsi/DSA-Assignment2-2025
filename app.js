const API_BASE = {
    PASSENGER: 'http://localhost:9090/passengers',
    TRANSPORT: 'http://localhost:9091/transport',
    TICKETING: 'http://localhost:9092/ticketing',
    PAYMENT: 'http://localhost:9093/payment'
};

let currentUser = null;
let authToken = null;

document.addEventListener('DOMContentLoaded', () => {
    initializeApp();
    attachEventListeners();
});

function initializeApp() {
    const savedUser = localStorage.getItem('currentUser');
    const savedToken = localStorage.getItem('authToken');

    if (savedUser && savedToken) {
        currentUser = JSON.parse(savedUser);
        authToken = savedToken;
        showDashboard();
    } else {
        showAuthSection();
    }
}

function attachEventListeners() {
    document.querySelectorAll('.auth-tab').forEach(tab => {
        tab.addEventListener('click', (e) => {
            document.querySelectorAll('.auth-tab').forEach(t => t.classList.remove('active'));
            e.target.classList.add('active');

            const authType = e.target.dataset.auth;
            document.getElementById('login-form').classList.toggle('hidden', authType !== 'login');
            document.getElementById('register-form').classList.toggle('hidden', authType !== 'register');
        });
    });

    document.getElementById('login-form-element').addEventListener('submit', handleLogin);
    document.getElementById('register-form-element').addEventListener('submit', handleRegister);

    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const tab = e.target.dataset.tab;
            switchTab(tab);
        });
    });

    document.getElementById('logout-btn')?.addEventListener('click', handleLogout);
    document.getElementById('refresh-routes-btn')?.addEventListener('click', loadRoutes);
    document.getElementById('refresh-tickets-btn')?.addEventListener('click', loadTickets);
    document.getElementById('refresh-payments-btn')?.addEventListener('click', loadPayments);

    document.querySelector('.modal-close')?.addEventListener('click', closeModal);

    window.addEventListener('click', (e) => {
        const modal = document.getElementById('modal');
        if (e.target === modal) {
            closeModal();
        }
    });
}

async function handleLogin(e) {
    e.preventDefault();

    const username = document.getElementById('login-username').value;
    const password = document.getElementById('login-password').value;

    try {
        const response = await fetch(`${API_BASE.PASSENGER}/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });

        const data = await response.json();

        if (response.ok) {
            currentUser = {
                passengerId: data.passengerId,
                username: data.username,
                email: data.email,
                firstName: data.firstName,
                lastName: data.lastName
            };
            authToken = data.token;

            localStorage.setItem('currentUser', JSON.stringify(currentUser));
            localStorage.setItem('authToken', authToken);

            showNotification('Login successful!', 'success');
            showDashboard();
        } else {
            showNotification(data.message || 'Login failed', 'error');
        }
    } catch (error) {
        showNotification('Connection error. Please check if services are running.', 'error');
        console.error('Login error:', error);
    }
}

async function handleRegister(e) {
    e.preventDefault();

    const userData = {
        username: document.getElementById('reg-username').value,
        email: document.getElementById('reg-email').value,
        password: document.getElementById('reg-password').value,
        firstName: document.getElementById('reg-firstname').value,
        lastName: document.getElementById('reg-lastname').value,
        phoneNumber: document.getElementById('reg-phone').value
    };

    try {
        const response = await fetch(`${API_BASE.PASSENGER}/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(userData)
        });

        const data = await response.json();

        if (response.ok) {
            showNotification('Registration successful! Please login.', 'success');
            document.querySelector('[data-auth="login"]').click();
            document.getElementById('register-form-element').reset();
        } else {
            showNotification(data.message || 'Registration failed', 'error');
        }
    } catch (error) {
        showNotification('Connection error. Please check if services are running.', 'error');
        console.error('Registration error:', error);
    }
}

function handleLogout() {
    currentUser = null;
    authToken = null;
    localStorage.removeItem('currentUser');
    localStorage.removeItem('authToken');
    showNotification('Logged out successfully', 'info');
    showAuthSection();
}

function showAuthSection() {
    document.getElementById('auth-section').classList.remove('hidden');
    document.getElementById('dashboard-section').classList.add('hidden');
    document.getElementById('routes-section').classList.add('hidden');
    document.getElementById('tickets-section').classList.add('hidden');
    document.getElementById('payments-section').classList.add('hidden');
    document.getElementById('nav-tabs').classList.add('hidden');
    document.getElementById('user-info').classList.add('hidden');
}

function showDashboard() {
    document.getElementById('auth-section').classList.add('hidden');
    document.getElementById('nav-tabs').classList.remove('hidden');
    document.getElementById('user-info').classList.remove('hidden');

    document.getElementById('user-name').textContent =
        `Welcome, ${currentUser.firstName} ${currentUser.lastName}`;

    switchTab('dashboard');
    loadDashboardData();
}

function switchTab(tabName) {
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabName);
    });

    document.querySelectorAll('.section').forEach(section => {
        section.classList.add('hidden');
    });

    const targetSection = document.getElementById(`${tabName}-section`);
    if (targetSection) {
        targetSection.classList.remove('hidden');
    }

    switch(tabName) {
        case 'dashboard':
            loadDashboardData();
            break;
        case 'routes':
            loadRoutes();
            break;
        case 'tickets':
            loadTickets();
            break;
        case 'payments':
            loadPayments();
            break;
    }
}

async function loadDashboardData() {
    try {
        const [routes, trips, tickets, payments] = await Promise.all([
            fetch(`${API_BASE.TRANSPORT}/routes`).then(r => r.json()),
            fetch(`${API_BASE.TRANSPORT}/trips`).then(r => r.json()),
            fetch(`${API_BASE.TICKETING}/tickets?passengerId=${currentUser.passengerId}`).then(r => r.json()),
            fetch(`${API_BASE.PAYMENT}/payments?passengerId=${currentUser.passengerId}`).then(r => r.json())
        ]);

        document.getElementById('total-routes').textContent = routes.data?.length || 0;
        document.getElementById('total-trips').textContent = trips.data?.length || 0;
        document.getElementById('total-tickets').textContent = tickets.data?.length || 0;

        const totalAmount = payments.data?.reduce((sum, p) => {
            return sum + (p.status === 'SUCCESS' ? parseFloat(p.amount) : 0);
        }, 0) || 0;
        document.getElementById('total-payments').textContent = `$${totalAmount.toFixed(2)}`;
    } catch (error) {
        console.error('Error loading dashboard data:', error);
    }
}

async function loadRoutes() {
    const routesList = document.getElementById('routes-list');
    routesList.innerHTML = '<p class="loading">Loading routes...</p>';

    try {
        const response = await fetch(`${API_BASE.TRANSPORT}/routes`);
        const data = await response.json();

        if (response.ok && data.data && data.data.length > 0) {
            routesList.innerHTML = data.data.map(route => `
                <div class="route-card">
                    <div class="card-header">
                        <div class="card-title">${route.routeNumber} - ${route.routeName}</div>
                        <span class="status-badge status-${route.status.toLowerCase()}">${route.status}</span>
                    </div>
                    <div class="card-info">
                        <div class="info-row">
                            <span class="info-label">From:</span>
                            <span class="info-value">${route.startLocation}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">To:</span>
                            <span class="info-value">${route.endLocation}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Distance:</span>
                            <span class="info-value">${route.distance} km</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Duration:</span>
                            <span class="info-value">${route.estimatedDuration} min</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Fare:</span>
                            <span class="info-value">$${parseFloat(route.fare).toFixed(2)}</span>
                        </div>
                    </div>
                    <div class="card-actions">
                        <button class="btn-small btn-view" onclick="viewTrips('${route.routeId}')">View Trips</button>
                    </div>
                </div>
            `).join('');
        } else {
            routesList.innerHTML = '<p class="loading">No routes available</p>';
        }
    } catch (error) {
        routesList.innerHTML = '<p class="loading">Error loading routes</p>';
        console.error('Error loading routes:', error);
    }
}

async function viewTrips(routeId) {
    try {
        const response = await fetch(`${API_BASE.TRANSPORT}/trips?routeId=${routeId}&status=SCHEDULED`);
        const data = await response.json();

        const tripsContainer = document.getElementById('trips-container');
        const tripsList = document.getElementById('trips-list');

        if (response.ok && data.data && data.data.length > 0) {
            tripsList.innerHTML = data.data.map(trip => `
                <div class="trip-card">
                    <div class="card-header">
                        <div class="card-title">Trip ${trip.tripId}</div>
                        <span class="status-badge status-${trip.status.toLowerCase()}">${trip.status}</span>
                    </div>
                    <div class="card-info">
                        <div class="info-row">
                            <span class="info-label">Route:</span>
                            <span class="info-value">${trip.routeNumber}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Departure:</span>
                            <span class="info-value">${formatDateTime(trip.departureTime)}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Arrival:</span>
                            <span class="info-value">${formatDateTime(trip.arrivalTime)}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Vehicle:</span>
                            <span class="info-value">${trip.vehicleId}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Driver:</span>
                            <span class="info-value">${trip.driverName}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Available Seats:</span>
                            <span class="info-value">${trip.availableSeats}/${trip.totalSeats}</span>
                        </div>
                    </div>
                    <div class="card-actions">
                        <button class="btn-small btn-purchase" onclick="purchaseTicket('${trip.tripId}')"
                            ${trip.availableSeats <= 0 ? 'disabled' : ''}>
                            Purchase Ticket
                        </button>
                    </div>
                </div>
            `).join('');

            tripsContainer.classList.remove('hidden');
            tripsContainer.scrollIntoView({ behavior: 'smooth' });
        } else {
            tripsList.innerHTML = '<p class="loading">No trips available for this route</p>';
            tripsContainer.classList.remove('hidden');
        }
    } catch (error) {
        showNotification('Error loading trips', 'error');
        console.error('Error loading trips:', error);
    }
}

async function purchaseTicket(tripId) {
    if (!currentUser) {
        showNotification('Please login first', 'error');
        return;
    }

    try {
        const response = await fetch(`${API_BASE.TICKETING}/tickets`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                passengerId: currentUser.passengerId,
                tripId: tripId
            })
        });

        const data = await response.json();

        if (response.ok) {
            showNotification('Ticket purchased! Please proceed to payment.', 'success');
            switchTab('tickets');
        } else {
            showNotification(data.error?.message || 'Ticket purchase failed', 'error');
        }
    } catch (error) {
        showNotification('Error purchasing ticket', 'error');
        console.error('Error purchasing ticket:', error);
    }
}

async function loadTickets() {
    if (!currentUser) return;

    const ticketsList = document.getElementById('tickets-list');
    ticketsList.innerHTML = '<p class="loading">Loading tickets...</p>';

    try {
        const response = await fetch(`${API_BASE.TICKETING}/tickets?passengerId=${currentUser.passengerId}`);
        const data = await response.json();

        if (response.ok && data.data && data.data.length > 0) {
            ticketsList.innerHTML = data.data.map(ticket => `
                <div class="ticket-card">
                    <div class="card-header">
                        <div class="card-title">Ticket ${ticket.ticketId}</div>
                        <span class="status-badge status-${ticket.status.toLowerCase()}">${ticket.status}</span>
                    </div>
                    <div class="card-info">
                        <div class="info-row">
                            <span class="info-label">Route:</span>
                            <span class="info-value">${ticket.routeNumber}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Trip ID:</span>
                            <span class="info-value">${ticket.tripId}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Fare:</span>
                            <span class="info-value">$${parseFloat(ticket.fare).toFixed(2)}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Purchased:</span>
                            <span class="info-value">${formatDateTime(ticket.purchasedAt)}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Valid Until:</span>
                            <span class="info-value">${formatDateTime(ticket.validUntil)}</span>
                        </div>
                        ${ticket.qrCode ? `
                        <div class="info-row">
                            <span class="info-label">QR Code:</span>
                        </div>
                        <div class="qr-code">${ticket.qrCode}</div>
                        ` : ''}
                    </div>
                    <div class="card-actions">
                        ${ticket.status === 'CREATED' ? `
                            <button class="btn-small btn-pay" onclick="payForTicket('${ticket.ticketId}', ${ticket.fare})">
                                Pay Now
                            </button>
                        ` : ''}
                        ${ticket.status === 'PAID' ? `
                            <button class="btn-small btn-view" onclick="validateTicket('${ticket.ticketId}')">
                                Validate
                            </button>
                        ` : ''}
                    </div>
                </div>
            `).join('');
        } else {
            ticketsList.innerHTML = '<p class="loading">No tickets found</p>';
        }
    } catch (error) {
        ticketsList.innerHTML = '<p class="loading">Error loading tickets</p>';
        console.error('Error loading tickets:', error);
    }
}

async function payForTicket(ticketId, amount) {
    try {
        const paymentResponse = await fetch(`${API_BASE.PAYMENT}/payments`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                ticketId: ticketId,
                passengerId: currentUser.passengerId,
                amount: parseFloat(amount),
                paymentMethod: 'CARD'
            })
        });

        const paymentData = await paymentResponse.json();

        if (paymentResponse.ok && paymentData.data?.status === 'SUCCESS') {
            const confirmResponse = await fetch(`${API_BASE.TICKETING}/tickets/${ticketId}/confirm-payment`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    paymentId: paymentData.data.paymentId
                })
            });

            if (confirmResponse.ok) {
                showNotification('Payment successful!', 'success');
                loadTickets();
                loadDashboardData();
            } else {
                showNotification('Payment processed but confirmation failed', 'error');
            }
        } else {
            showNotification('Payment failed', 'error');
        }
    } catch (error) {
        showNotification('Error processing payment', 'error');
        console.error('Error processing payment:', error);
    }
}

async function validateTicket(ticketId) {
    try {
        const response = await fetch(`${API_BASE.TICKETING}/tickets/${ticketId}/validate`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                validatedBy: 'CONDUCTOR',
                location: 'Bus Station'
            })
        });

        const data = await response.json();

        if (response.ok) {
            showNotification('Ticket validated successfully!', 'success');
            loadTickets();
        } else {
            showNotification(data.error?.message || 'Validation failed', 'error');
        }
    } catch (error) {
        showNotification('Error validating ticket', 'error');
        console.error('Error validating ticket:', error);
    }
}

async function loadPayments() {
    if (!currentUser) return;

    const paymentsList = document.getElementById('payments-list');
    paymentsList.innerHTML = '<p class="loading">Loading payments...</p>';

    try {
        const response = await fetch(`${API_BASE.PAYMENT}/payments?passengerId=${currentUser.passengerId}`);
        const data = await response.json();

        if (response.ok && data.data && data.data.length > 0) {
            paymentsList.innerHTML = data.data.map(payment => `
                <div class="payment-card">
                    <div class="card-header">
                        <div class="card-title">Payment ${payment.paymentId}</div>
                        <span class="status-badge status-${payment.status.toLowerCase()}">${payment.status}</span>
                    </div>
                    <div class="card-info">
                        <div class="info-row">
                            <span class="info-label">Ticket ID:</span>
                            <span class="info-value">${payment.ticketId}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Amount:</span>
                            <span class="info-value">$${parseFloat(payment.amount).toFixed(2)}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Method:</span>
                            <span class="info-value">${payment.paymentMethod}</span>
                        </div>
                        <div class="info-row">
                            <span class="info-label">Date:</span>
                            <span class="info-value">${formatDateTime(payment.createdAt)}</span>
                        </div>
                        ${payment.transactionId ? `
                        <div class="info-row">
                            <span class="info-label">Transaction:</span>
                            <span class="info-value">${payment.transactionId}</span>
                        </div>
                        ` : ''}
                    </div>
                </div>
            `).join('');
        } else {
            paymentsList.innerHTML = '<p class="loading">No payments found</p>';
        }
    } catch (error) {
        paymentsList.innerHTML = '<p class="loading">Error loading payments</p>';
        console.error('Error loading payments:', error);
    }
}

function showNotification(message, type = 'info') {
    const notification = document.getElementById('notification');
    const notificationMessage = document.getElementById('notification-message');

    notificationMessage.textContent = message;
    notification.className = `notification ${type}`;
    notification.classList.remove('hidden');

    setTimeout(() => {
        notification.classList.add('hidden');
    }, 4000);
}

function closeModal() {
    document.getElementById('modal').classList.add('hidden');
}

function formatDateTime(dateString) {
    if (!dateString) return 'N/A';
    try {
        const date = new Date(dateString);
        return date.toLocaleString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    } catch {
        return dateString;
    }
}

window.switchTab = switchTab;
window.viewTrips = viewTrips;
window.purchaseTicket = purchaseTicket;
window.payForTicket = payForTicket;
window.validateTicket = validateTicket;
