/**
 * API Client for WebApp Framework
 * Handles all HTTP requests to the backend API
 */

class APIClient {
    constructor() {
        this.baseURL = '/api';
        this.timeout = 30000; // 30 seconds
        this.defaultHeaders = {
            'Content-Type': 'application/json',
        };
    }

    /**
     * Get authentication token
     */
    getAuthToken() {
        return localStorage.getItem('access_token');
    }

    /**
     * Get request headers with authentication
     */
    getHeaders(additionalHeaders = {}) {
        const headers = { ...this.defaultHeaders, ...additionalHeaders };
        
        const token = this.getAuthToken();
        if (token) {
            headers['Authorization'] = `Bearer ${token}`;
        }
        
        return headers;
    }

    /**
     * Handle API response
     */
    async handleResponse(response) {
        if (!response.ok) {
            const error = new Error(`HTTP ${response.status}: ${response.statusText}`);
            error.status = response.status;
            error.statusText = response.statusText;
            
            try {
                const errorData = await response.json();
                error.data = errorData;
                error.message = errorData.detail || errorData.message || error.message;
            } catch (e) {
                // Response is not JSON
            }
            
            throw error;
        }
        
        const contentType = response.headers.get('content-type');
        if (contentType && contentType.includes('application/json')) {
            return await response.json();
        } else {
            return response;
        }
    }

    /**
     * Make HTTP request
     */
    async request(method, endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;
        const config = {
            method,
            headers: this.getHeaders(options.headers),
            ...options
        };

        // Add timeout
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), this.timeout);
        config.signal = controller.signal;

        try {
            const response = await fetch(url, config);
            clearTimeout(timeoutId);
            return await this.handleResponse(response);
        } catch (error) {
            clearTimeout(timeoutId);
            
            if (error.name === 'AbortError') {
                throw new Error('Request timeout');
            }
            
            throw error;
        }
    }

    /**
     * GET request
     */
    async get(endpoint, params = {}) {
        const url = new URL(`${this.baseURL}${endpoint}`, window.location.origin);
        Object.keys(params).forEach(key => {
            if (params[key] !== undefined && params[key] !== null) {
                url.searchParams.append(key, params[key]);
            }
        });
        
        return this.request('GET', url.pathname + url.search);
    }

    /**
     * POST request
     */
    async post(endpoint, data = null) {
        const options = {};
        
        if (data) {
            if (data instanceof FormData) {
                // Don't set Content-Type for FormData, let browser set it with boundary
                options.headers = this.getHeaders({ 'Content-Type': undefined });
                delete options.headers['Content-Type'];
                options.body = data;
            } else {
                options.body = JSON.stringify(data);
            }
        }
        
        return this.request('POST', endpoint, options);
    }

    /**
     * PUT request
     */
    async put(endpoint, data = null) {
        const options = {};
        
        if (data) {
            options.body = JSON.stringify(data);
        }
        
        return this.request('PUT', endpoint, options);
    }

    /**
     * DELETE request
     */
    async delete(endpoint) {
        return this.request('DELETE', endpoint);
    }

    /**
     * Upload file with progress tracking
     */
    async uploadFile(file, onProgress = null) {
        const formData = new FormData();
        formData.append('file', file);
        
        return new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            
            // Track upload progress
            if (onProgress) {
                xhr.upload.addEventListener('progress', (e) => {
                    if (e.lengthComputable) {
                        const percentComplete = (e.loaded / e.total) * 100;
                        onProgress(percentComplete, e.loaded, e.total);
                    }
                });
            }
            
            // Handle completion
            xhr.addEventListener('load', () => {
                if (xhr.status >= 200 && xhr.status < 300) {
                    try {
                        const response = JSON.parse(xhr.responseText);
                        resolve(response);
                    } catch (e) {
                        resolve(xhr.responseText);
                    }
                } else {
                    const error = new Error(`HTTP ${xhr.status}: ${xhr.statusText}`);
                    error.status = xhr.status;
                    try {
                        const errorData = JSON.parse(xhr.responseText);
                        error.data = errorData;
                        error.message = errorData.detail || errorData.message || error.message;
                    } catch (e) {
                        // Response is not JSON
                    }
                    reject(error);
                }
            });
            
            // Handle errors
            xhr.addEventListener('error', () => {
                reject(new Error('Network error'));
            });
            
            xhr.addEventListener('abort', () => {
                reject(new Error('Upload cancelled'));
            });
            
            // Set headers
            const token = this.getAuthToken();
            if (token) {
                xhr.setRequestHeader('Authorization', `Bearer ${token}`);
            }
            
            // Start upload
            xhr.open('POST', `${this.baseURL}/files/upload`);
            xhr.send(formData);
            
            // Return xhr for cancellation support
            return xhr;
        });
    }

    /**
     * Download file with progress tracking
     */
    async downloadFile(fileId, onProgress = null) {
        return new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            xhr.responseType = 'blob';
            
            // Track download progress
            if (onProgress) {
                xhr.addEventListener('progress', (e) => {
                    if (e.lengthComputable) {
                        const percentComplete = (e.loaded / e.total) * 100;
                        onProgress(percentComplete, e.loaded, e.total);
                    }
                });
            }
            
            // Handle completion
            xhr.addEventListener('load', () => {
                if (xhr.status >= 200 && xhr.status < 300) {
                    // Get filename from Content-Disposition header
                    const contentDisposition = xhr.getResponseHeader('Content-Disposition');
                    let filename = `file_${fileId}`;
                    
                    if (contentDisposition) {
                        const filenameMatch = contentDisposition.match(/filename="(.+)"/);
                        if (filenameMatch) {
                            filename = filenameMatch[1];
                        }
                    }
                    
                    resolve({
                        blob: xhr.response,
                        filename: filename
                    });
                } else {
                    const error = new Error(`HTTP ${xhr.status}: ${xhr.statusText}`);
                    error.status = xhr.status;
                    reject(error);
                }
            });
            
            // Handle errors
            xhr.addEventListener('error', () => {
                reject(new Error('Network error'));
            });
            
            xhr.addEventListener('abort', () => {
                reject(new Error('Download cancelled'));
            });
            
            // Set headers
            const token = this.getAuthToken();
            if (token) {
                xhr.setRequestHeader('Authorization', `Bearer ${token}`);
            }
            
            // Start download
            xhr.open('GET', `${this.baseURL}/files/${fileId}/download`);
            xhr.send();
            
            // Return xhr for cancellation support
            return xhr;
        });
    }

    /**
     * Server-Sent Events connection
     */
    createEventSource(endpoint) {
        const url = `${this.baseURL}${endpoint}`;
        const token = this.getAuthToken();
        
        if (token) {
            // Add token as query parameter for SSE
            const urlWithToken = new URL(url, window.location.origin);
            urlWithToken.searchParams.append('token', token);
            return new EventSource(urlWithToken.toString());
        } else {
            return new EventSource(url);
        }
    }

    /**
     * WebSocket connection
     */
    createWebSocket(endpoint) {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const url = `${protocol}//${window.location.host}${this.baseURL}${endpoint}`;
        const token = this.getAuthToken();
        
        if (token) {
            // Add token as query parameter for WebSocket
            const urlWithToken = new URL(url);
            urlWithToken.searchParams.append('token', token);
            return new WebSocket(urlWithToken.toString());
        } else {
            return new WebSocket(url);
        }
    }

    /**
     * Retry failed requests
     */
    async retryRequest(requestFn, maxRetries = 3, delay = 1000) {
        let lastError;
        
        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                return await requestFn();
            } catch (error) {
                lastError = error;
                
                // Don't retry on authentication errors
                if (error.status === 401 || error.status === 403) {
                    throw error;
                }
                
                // Don't retry on client errors (except rate limiting)
                if (error.status >= 400 && error.status < 500 && error.status !== 429) {
                    throw error;
                }
                
                // Wait before retrying
                if (attempt < maxRetries) {
                    await new Promise(resolve => setTimeout(resolve, delay * Math.pow(2, attempt)));
                }
            }
        }
        
        throw lastError;
    }

    /**
     * Health check
     */
    async healthCheck() {
        try {
            const response = await this.get('/health');
            return response.status === 'healthy';
        } catch (error) {
            return false;
        }
    }

    /**
     * Check authentication status
     */
    async checkAuth() {
        try {
            await this.get('/auth/me');
            return true;
        } catch (error) {
            if (error.status === 401) {
                return false;
            }
            throw error;
        }
    }
}

// Create global API instance
window.API = new APIClient();

// Auto-refresh token before expiration
setInterval(async () => {
    const token = localStorage.getItem('access_token');
    if (token) {
        try {
            // Check if token is still valid
            const isValid = await window.API.checkAuth();
            if (!isValid) {
                // Token expired, redirect to login
                localStorage.removeItem('access_token');
                window.location.href = '/login.html';
            }
        } catch (error) {
            console.error('Token validation error:', error);
        }
    }
}, 5 * 60 * 1000); // Check every 5 minutes