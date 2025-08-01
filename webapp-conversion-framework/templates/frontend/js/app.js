/**
 * Main Application JavaScript
 * Handles navigation, theming, and application initialization
 */

class WebAppFramework {
    constructor() {
        this.currentSection = 'dashboard';
        this.theme = localStorage.getItem('theme') || 'light';
        this.user = null;
        this.init();
    }

    /**
     * Initialize the application
     */
    init() {
        this.setupEventListeners();
        this.setupTheme();
        this.setupNavigation();
        this.loadUserData();
        this.startPeriodicUpdates();
        
        // Initialize modules
        if (window.FileManager) {
            this.fileManager = new FileManager();
        }
        if (window.TransferManager) {
            this.transferManager = new TransferManager();
        }
        if (window.MountManager) {
            this.mountManager = new MountManager();
        }
        
        this.showSection('dashboard');
        this.loadDashboardData();
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Navigation clicks
        document.querySelectorAll('.nav-link').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const section = link.getAttribute('href').substring(1);
                this.showSection(section);
            });
        });

        // File input change
        const fileInput = document.getElementById('file-input');
        if (fileInput) {
            fileInput.addEventListener('change', (e) => {
                if (this.fileManager) {
                    this.fileManager.handleFileSelect(e.target.files);
                }
            });
        }

        // Drop zone events
        const dropZone = document.getElementById('drop-zone');
        if (dropZone) {
            this.setupDropZone(dropZone);
        }

        // Form submissions
        const bitsForm = document.getElementById('bits-form');
        if (bitsForm) {
            bitsForm.addEventListener('submit', (e) => {
                e.preventDefault();
                if (this.transferManager) {
                    this.transferManager.startBITSTransfer();
                }
            });
        }

        const smbForm = document.getElementById('smb-form');
        if (smbForm) {
            smbForm.addEventListener('submit', (e) => {
                e.preventDefault();
                if (this.mountManager) {
                    this.mountManager.mountSMBShare();
                }
            });
        }

        // Search and filter
        const fileSearch = document.getElementById('file-search');
        if (fileSearch) {
            fileSearch.addEventListener('input', (e) => {
                if (this.fileManager) {
                    this.fileManager.filterFiles(e.target.value);
                }
            });
        }

        const fileFilter = document.getElementById('file-filter');
        if (fileFilter) {
            fileFilter.addEventListener('change', (e) => {
                if (this.fileManager) {
                    this.fileManager.filterByType(e.target.value);
                }
            });
        }

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey || e.metaKey) {
                switch (e.key) {
                    case '1':
                        e.preventDefault();
                        this.showSection('dashboard');
                        break;
                    case '2':
                        e.preventDefault();
                        this.showSection('files');
                        break;
                    case '3':
                        e.preventDefault();
                        this.showSection('transfers');
                        break;
                    case '4':
                        e.preventDefault();
                        this.showSection('mounts');
                        break;
                }
            }
        });
    }

    /**
     * Setup drag and drop for file upload
     */
    setupDropZone(dropZone) {
        dropZone.addEventListener('dragover', (e) => {
            e.preventDefault();
            dropZone.classList.add('dragover');
        });

        dropZone.addEventListener('dragleave', (e) => {
            e.preventDefault();
            dropZone.classList.remove('dragover');
        });

        dropZone.addEventListener('drop', (e) => {
            e.preventDefault();
            dropZone.classList.remove('dragover');
            
            if (this.fileManager) {
                this.fileManager.handleFileSelect(e.dataTransfer.files);
            }
        });

        // Paste support
        document.addEventListener('paste', (e) => {
            const items = e.clipboardData?.items;
            if (items) {
                const files = [];
                for (let item of items) {
                    if (item.kind === 'file') {
                        files.push(item.getAsFile());
                    }
                }
                if (files.length > 0 && this.fileManager) {
                    this.fileManager.handleFileSelect(files);
                }
            }
        });
    }

    /**
     * Setup theme
     */
    setupTheme() {
        document.documentElement.setAttribute('data-theme', this.theme);
        
        const themeButton = document.querySelector('.theme-toggle');
        if (themeButton) {
            themeButton.textContent = this.theme === 'dark' ? '☀️' : '🌙';
        }
    }

    /**
     * Setup navigation
     */
    setupNavigation() {
        // Set active nav link
        this.updateActiveNavLink();
    }

    /**
     * Update active navigation link
     */
    updateActiveNavLink() {
        document.querySelectorAll('.nav-link').forEach(link => {
            link.classList.remove('active');
            if (link.getAttribute('href') === `#${this.currentSection}`) {
                link.classList.add('active');
            }
        });
    }

    /**
     * Show a specific section
     */
    showSection(sectionName) {
        // Hide all sections
        document.querySelectorAll('.section').forEach(section => {
            section.classList.remove('active');
        });

        // Show target section
        const targetSection = document.getElementById(sectionName);
        if (targetSection) {
            targetSection.classList.add('active');
            this.currentSection = sectionName;
            this.updateActiveNavLink();

            // Load section-specific data
            this.loadSectionData(sectionName);
        }
    }

    /**
     * Load data for specific section
     */
    loadSectionData(sectionName) {
        switch (sectionName) {
            case 'dashboard':
                this.loadDashboardData();
                break;
            case 'files':
                if (this.fileManager) {
                    this.fileManager.loadFiles();
                }
                break;
            case 'transfers':
                if (this.transferManager) {
                    this.transferManager.loadTransfers();
                }
                break;
            case 'mounts':
                if (this.mountManager) {
                    this.mountManager.loadMounts();
                }
                break;
        }
    }

    /**
     * Load dashboard statistics
     */
    async loadDashboardData() {
        try {
            const stats = await API.get('/api/stats');
            
            // Update stat cards
            this.updateStatCard('total-files', stats.total_files || 0);
            this.updateStatCard('active-uploads', stats.active_uploads || 0);
            this.updateStatCard('bits-transfers', stats.bits_transfers || 0);
            this.updateStatCard('smb-mounts', stats.smb_mounts || 0);

            // Load recent activity
            const activity = await API.get('/api/activity');
            this.updateActivityList(activity.items || []);

        } catch (error) {
            console.error('Failed to load dashboard data:', error);
            UI.showToast('Failed to load dashboard data', 'error');
        }
    }

    /**
     * Update stat card value
     */
    updateStatCard(elementId, value) {
        const element = document.getElementById(elementId);
        if (element) {
            element.textContent = value.toLocaleString();
        }
    }

    /**
     * Update activity list
     */
    updateActivityList(activities) {
        const container = document.getElementById('activity-list');
        if (!container) return;

        if (activities.length === 0) {
            container.innerHTML = '<p class="text-center text-muted">No recent activity</p>';
            return;
        }

        container.innerHTML = activities.map(activity => `
            <div class="list-item">
                <div class="list-item-content">
                    <div class="list-item-title">${this.escapeHtml(activity.action)}</div>
                    <div class="list-item-subtitle">
                        ${this.escapeHtml(activity.details)} • ${this.formatDate(activity.timestamp)}
                    </div>
                </div>
                <div class="activity-icon">${this.getActivityIcon(activity.type)}</div>
            </div>
        `).join('');
    }

    /**
     * Get icon for activity type
     */
    getActivityIcon(type) {
        const icons = {
            upload: '⬆️',
            download: '⬇️',
            transfer: '🔄',
            mount: '🗂️',
            delete: '🗑️',
            share: '📤'
        };
        return icons[type] || '📝';
    }

    /**
     * Load user data
     */
    async loadUserData() {
        try {
            const user = await API.get('/api/user/me');
            this.user = user;
            
            const userEmailElement = document.getElementById('user-email');
            if (userEmailElement) {
                userEmailElement.textContent = user.email;
            }
        } catch (error) {
            console.error('Failed to load user data:', error);
            // Redirect to login if unauthorized
            if (error.status === 401) {
                this.logout();
            }
        }
    }

    /**
     * Start periodic updates
     */
    startPeriodicUpdates() {
        // Update dashboard every 30 seconds
        setInterval(() => {
            if (this.currentSection === 'dashboard') {
                this.loadDashboardData();
            }
        }, 30000);

        // Update transfers every 5 seconds
        setInterval(() => {
            if (this.transferManager && this.currentSection === 'transfers') {
                this.transferManager.updateTransferStatus();
            }
        }, 5000);

        // Check for file processing updates every 10 seconds
        setInterval(() => {
            if (this.fileManager && this.currentSection === 'files') {
                this.fileManager.updateFileStatus();
            }
        }, 10000);
    }

    /**
     * Save settings
     */
    async saveSettings() {
        try {
            const settings = {
                max_file_size: parseInt(document.getElementById('max-file-size')?.value) || 100,
                auto_process: document.getElementById('auto-process')?.checked || false,
                default_priority: document.getElementById('default-priority')?.value || 'normal',
                resume_transfers: document.getElementById('resume-transfers')?.checked || true,
                notify_uploads: document.getElementById('notify-uploads')?.checked || true,
                notify_transfers: document.getElementById('notify-transfers')?.checked || true
            };

            await API.post('/api/user/settings', settings);
            UI.showToast('Settings saved successfully', 'success');
        } catch (error) {
            console.error('Failed to save settings:', error);
            UI.showToast('Failed to save settings', 'error');
        }
    }

    /**
     * Logout user
     */
    logout() {
        localStorage.removeItem('access_token');
        window.location.href = '/login.html';
    }

    /**
     * Utility functions
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    formatDate(dateString) {
        const date = new Date(dateString);
        return date.toLocaleString();
    }

    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    formatDuration(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;
        
        if (hours > 0) {
            return `${hours}h ${minutes}m ${secs}s`;
        } else if (minutes > 0) {
            return `${minutes}m ${secs}s`;
        } else {
            return `${secs}s`;
        }
    }
}

/**
 * Global functions
 */
function toggleTheme() {
    const currentTheme = document.documentElement.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    
    document.documentElement.setAttribute('data-theme', newTheme);
    localStorage.setItem('theme', newTheme);
    
    const themeButton = document.querySelector('.theme-toggle');
    if (themeButton) {
        themeButton.textContent = newTheme === 'dark' ? '☀️' : '🌙';
    }
}

function logout() {
    if (window.app) {
        window.app.logout();
    }
}

function saveSettings() {
    if (window.app) {
        window.app.saveSettings();
    }
}

function closeModal() {
    if (window.UI) {
        window.UI.hideModal();
    }
}

function cancelUploads() {
    if (window.app && window.app.fileManager) {
        window.app.fileManager.cancelAllUploads();
    }
}

// Initialize application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.app = new WebAppFramework();
});

// Handle unhandled promise rejections
window.addEventListener('unhandledrejection', (event) => {
    console.error('Unhandled promise rejection:', event.reason);
    if (window.UI) {
        window.UI.showToast('An unexpected error occurred', 'error');
    }
});

// Handle errors
window.addEventListener('error', (event) => {
    console.error('JavaScript error:', event.error);
});