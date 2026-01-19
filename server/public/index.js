// WiFi form handling
const wifiForm = document.getElementById('wifi-form');
const submitBtn = document.getElementById('submit-btn');
const messageDiv = document.getElementById('message');

function showMessage(text, type) {
    messageDiv.textContent = text;
    messageDiv.className = `message ${type}`;
    messageDiv.style.display = 'block';
}

function hideMessage() {
    messageDiv.style.display = 'none';
}

wifiForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const ssid = document.getElementById('ssid').value.trim();
    const password = document.getElementById('password').value;
    
    if (!ssid) {
        showMessage('Please enter a WiFi network name', 'error');
        return;
    }
    
    submitBtn.disabled = true;
    submitBtn.textContent = 'Connecting...';
    hideMessage();
    
    try {
        const response = await fetch('/api/connect-wifi', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ ssid, password }),
        });
        
        const data = await response.json();
        
        if (response.ok) {
            showMessage(data.message || 'WiFi credentials received. The device is now connecting to your network. This may take a minute...', 'success');
            submitBtn.textContent = 'Connected';
        } else {
            showMessage(data.error || 'Failed to connect to WiFi. Please try again.', 'error');
            submitBtn.disabled = false;
            submitBtn.textContent = 'Connect to WiFi';
        }
    } catch (error) {
        console.error('Error:', error);
        showMessage('Network error. Please check your connection and try again.', 'error');
        submitBtn.disabled = false;
        submitBtn.textContent = 'Connect to WiFi';
    }
    });
