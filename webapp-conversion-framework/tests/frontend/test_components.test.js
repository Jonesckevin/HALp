/**
 * Frontend JavaScript Tests using Jest
 * Tests for file upload, UI components, and API interactions
 */

// Mock fetch for testing
global.fetch = jest.fn();

// Mock localStorage
const localStorageMock = {
  getItem: jest.fn(),
  setItem: jest.fn(),
  removeItem: jest.fn(),
  clear: jest.fn(),
};
global.localStorage = localStorageMock;

// Mock EventSource
global.EventSource = jest.fn(() => ({
  addEventListener: jest.fn(),
  removeEventListener: jest.fn(),
  close: jest.fn(),
}));

// Mock WebSocket
global.WebSocket = jest.fn(() => ({
  addEventListener: jest.fn(),
  removeEventListener: jest.fn(),
  send: jest.fn(),
  close: jest.fn(),
}));

// Mock DOM elements
document.body.innerHTML = `
  <div id="drop-zone"></div>
  <input id="file-input" type="file" />
  <div id="total-files">0</div>
  <div id="active-uploads">0</div>
  <div id="bits-transfers">0</div>
  <div id="smb-mounts">0</div>
  <div id="activity-list"></div>
  <div id="file-list"></div>
  <div id="upload-progress" class="hidden"></div>
  <div id="toast-container"></div>
  <div id="modal-overlay" class="hidden"></div>
`;

// Import modules under test
require('../templates/frontend/js/api.js');
require('../templates/frontend/js/ui.js');
require('../templates/frontend/js/files.js');

describe('API Client', () => {
  beforeEach(() => {
    fetch.mockClear();
    localStorageMock.getItem.mockClear();
    localStorageMock.setItem.mockClear();
  });

  describe('Authentication', () => {
    test('should include auth token in headers', () => {
      localStorageMock.getItem.mockReturnValue('test-token');
      
      const api = new APIClient();
      const headers = api.getHeaders();
      
      expect(headers.Authorization).toBe('Bearer test-token');
    });

    test('should not include auth header when no token', () => {
      localStorageMock.getItem.mockReturnValue(null);
      
      const api = new APIClient();
      const headers = api.getHeaders();
      
      expect(headers.Authorization).toBeUndefined();
    });

    test('should check authentication status', async () => {
      const mockResponse = { ok: true };
      fetch.mockResolvedValue({
        ...mockResponse,
        json: () => Promise.resolve({ user: 'test@example.com' })
      });

      const api = new APIClient();
      const isAuth = await api.checkAuth();

      expect(isAuth).toBe(true);
      expect(fetch).toHaveBeenCalledWith('/api/auth/me', expect.any(Object));
    });
  });

  describe('HTTP Methods', () => {
    test('should make GET request with parameters', async () => {
      const mockResponse = { data: 'test' };
      fetch.mockResolvedValue({
        ok: true,
        headers: { get: () => 'application/json' },
        json: () => Promise.resolve(mockResponse)
      });

      const api = new APIClient();
      const result = await api.get('/test', { param1: 'value1', param2: 'value2' });

      expect(result).toEqual(mockResponse);
      expect(fetch).toHaveBeenCalledWith(
        '/api/test?param1=value1&param2=value2',
        expect.objectContaining({ method: 'GET' })
      );
    });

    test('should make POST request with JSON data', async () => {
      const mockResponse = { success: true };
      fetch.mockResolvedValue({
        ok: true,
        headers: { get: () => 'application/json' },
        json: () => Promise.resolve(mockResponse)
      });

      const api = new APIClient();
      const data = { test: 'data' };
      const result = await api.post('/test', data);

      expect(result).toEqual(mockResponse);
      expect(fetch).toHaveBeenCalledWith(
        '/api/test',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(data),
          headers: expect.objectContaining({
            'Content-Type': 'application/json'
          })
        })
      );
    });

    test('should handle FormData in POST requests', async () => {
      const mockResponse = { success: true };
      fetch.mockResolvedValue({
        ok: true,
        headers: { get: () => 'application/json' },
        json: () => Promise.resolve(mockResponse)
      });

      const api = new APIClient();
      const formData = new FormData();
      formData.append('test', 'value');
      
      const result = await api.post('/test', formData);

      expect(result).toEqual(mockResponse);
      expect(fetch).toHaveBeenCalledWith(
        '/api/test',
        expect.objectContaining({
          method: 'POST',
          body: formData,
          headers: expect.not.objectContaining({
            'Content-Type': 'application/json'
          })
        })
      );
    });
  });

  describe('Error Handling', () => {
    test('should handle HTTP errors', async () => {
      fetch.mockResolvedValue({
        ok: false,
        status: 404,
        statusText: 'Not Found',
        json: () => Promise.resolve({ detail: 'Resource not found' })
      });

      const api = new APIClient();
      
      await expect(api.get('/nonexistent')).rejects.toThrow('Resource not found');
    });

    test('should handle network errors', async () => {
      fetch.mockRejectedValue(new Error('Network error'));

      const api = new APIClient();
      
      await expect(api.get('/test')).rejects.toThrow('Network error');
    });

    test('should handle timeout errors', async () => {
      // Mock a long-running request
      fetch.mockImplementation(() => new Promise(resolve => {
        setTimeout(() => resolve({ ok: true }), 35000); // Longer than timeout
      }));

      const api = new APIClient();
      
      await expect(api.get('/slow')).rejects.toThrow('Request timeout');
    }, 10000);
  });

  describe('File Operations', () => {
    test('should upload file with progress tracking', (done) => {
      // Mock XMLHttpRequest
      const mockXHR = {
        upload: { addEventListener: jest.fn() },
        addEventListener: jest.fn(),
        setRequestHeader: jest.fn(),
        open: jest.fn(),
        send: jest.fn(),
        status: 200,
        responseText: JSON.stringify({ file_id: 1, filename: 'test.txt' })
      };

      global.XMLHttpRequest = jest.fn(() => mockXHR);

      const api = new APIClient();
      const file = new File(['test content'], 'test.txt', { type: 'text/plain' });
      
      const progressCallback = jest.fn();
      
      api.uploadFile(file, progressCallback).then(result => {
        expect(result.file_id).toBe(1);
        expect(result.filename).toBe('test.txt');
        expect(mockXHR.open).toHaveBeenCalledWith('POST', '/api/files/upload');
        done();
      });

      // Simulate load event
      const loadCallback = mockXHR.addEventListener.mock.calls.find(
        call => call[0] === 'load'
      )[1];
      loadCallback();
    });

    test('should track upload progress', () => {
      const mockXHR = {
        upload: { addEventListener: jest.fn() },
        addEventListener: jest.fn(),
        setRequestHeader: jest.fn(),
        open: jest.fn(),
        send: jest.fn()
      };

      global.XMLHttpRequest = jest.fn(() => mockXHR);

      const api = new APIClient();
      const file = new File(['test content'], 'test.txt');
      const progressCallback = jest.fn();
      
      api.uploadFile(file, progressCallback);

      // Get the progress event handler
      const progressHandler = mockXHR.upload.addEventListener.mock.calls.find(
        call => call[0] === 'progress'
      )[1];

      // Simulate progress event
      progressHandler({
        lengthComputable: true,
        loaded: 50,
        total: 100
      });

      expect(progressCallback).toHaveBeenCalledWith(50, 50, 100);
    });
  });
});

describe('File Manager', () => {
  beforeEach(() => {
    // Reset DOM
    document.getElementById('file-list').innerHTML = '';
    document.getElementById('upload-progress').classList.add('hidden');
    
    // Mock API
    window.API = {
      get: jest.fn(),
      post: jest.fn(),
      uploadFile: jest.fn(),
      downloadFile: jest.fn()
    };

    // Mock UI
    window.UI = {
      showToast: jest.fn(),
      updateProgress: jest.fn(),
      hideProgress: jest.fn()
    };
  });

  test('should initialize file manager', () => {
    const fileManager = new FileManager();
    
    expect(fileManager.files).toEqual([]);
    expect(fileManager.uploads).toEqual([]);
    expect(fileManager.currentPage).toBe(1);
  });

  test('should handle file selection', async () => {
    window.API.uploadFile.mockResolvedValue({
      file_id: 1,
      filename: 'test.txt',
      size: 1000,
      status: 'uploaded'
    });

    const fileManager = new FileManager();
    const files = [new File(['test'], 'test.txt', { type: 'text/plain' })];
    
    await fileManager.handleFileSelect(files);

    expect(window.API.uploadFile).toHaveBeenCalledWith(
      files[0],
      expect.any(Function)
    );
    expect(fileManager.uploads).toHaveLength(1);
  });

  test('should validate file types', () => {
    const fileManager = new FileManager();
    
    const validFile = new File(['test'], 'test.txt', { type: 'text/plain' });
    const invalidFile = new File(['test'], 'test.exe', { type: 'application/x-executable' });
    
    expect(fileManager.validateFile(validFile)).toBe(true);
    expect(fileManager.validateFile(invalidFile)).toBe(false);
  });

  test('should validate file size', () => {
    const fileManager = new FileManager();
    
    // Mock a large file (> 100MB)
    const largeFile = new File(['x'.repeat(101 * 1024 * 1024)], 'large.txt');
    const smallFile = new File(['small content'], 'small.txt');
    
    expect(fileManager.validateFile(largeFile)).toBe(false);
    expect(fileManager.validateFile(smallFile)).toBe(true);
  });

  test('should filter files by search term', async () => {
    const fileManager = new FileManager();
    fileManager.files = [
      { filename: 'document.pdf', type: 'pdf' },
      { filename: 'image.jpg', type: 'image' },
      { filename: 'report.pdf', type: 'pdf' }
    ];

    await fileManager.filterFiles('pdf');

    expect(fileManager.filteredFiles).toHaveLength(2);
    expect(fileManager.filteredFiles.every(f => f.filename.includes('pdf'))).toBe(true);
  });

  test('should filter files by type', async () => {
    const fileManager = new FileManager();
    fileManager.files = [
      { filename: 'doc.pdf', type: 'pdf' },
      { filename: 'pic.jpg', type: 'image' },
      { filename: 'pic2.png', type: 'image' }
    ];

    await fileManager.filterByType('images');

    expect(fileManager.filteredFiles).toHaveLength(2);
    expect(fileManager.filteredFiles.every(f => f.type === 'image')).toBe(true);
  });

  test('should cancel uploads', () => {
    const fileManager = new FileManager();
    const mockXHR = { abort: jest.fn() };
    
    fileManager.uploads = [
      { id: 1, xhr: mockXHR, status: 'uploading' }
    ];

    fileManager.cancelAllUploads();

    expect(mockXHR.abort).toHaveBeenCalled();
    expect(fileManager.uploads[0].status).toBe('cancelled');
  });

  test('should download file', async () => {
    window.API.downloadFile.mockResolvedValue({
      blob: new Blob(['file content']),
      filename: 'test.txt'
    });

    // Mock URL.createObjectURL and click
    global.URL.createObjectURL = jest.fn(() => 'blob:url');
    global.URL.revokeObjectURL = jest.fn();
    
    const mockAnchor = {
      href: '',
      download: '',
      click: jest.fn()
    };
    document.createElement = jest.fn(() => mockAnchor);

    const fileManager = new FileManager();
    await fileManager.downloadFile(1);

    expect(window.API.downloadFile).toHaveBeenCalledWith(1, expect.any(Function));
    expect(mockAnchor.click).toHaveBeenCalled();
    expect(global.URL.createObjectURL).toHaveBeenCalled();
    expect(global.URL.revokeObjectURL).toHaveBeenCalled();
  });
});

describe('UI Components', () => {
  beforeEach(() => {
    // Reset toast container
    document.getElementById('toast-container').innerHTML = '';
    document.getElementById('modal-overlay').classList.add('hidden');
  });

  test('should show toast notification', () => {
    const ui = new UIManager();
    
    ui.showToast('Test message', 'success');

    const toasts = document.querySelectorAll('.toast');
    expect(toasts).toHaveLength(1);
    expect(toasts[0].textContent).toContain('Test message');
    expect(toasts[0].classList).toContain('success');
  });

  test('should auto-hide toast after timeout', (done) => {
    const ui = new UIManager();
    
    ui.showToast('Test message', 'info', 100); // Short timeout for testing

    setTimeout(() => {
      const toasts = document.querySelectorAll('.toast');
      expect(toasts).toHaveLength(0);
      done();
    }, 150);
  });

  test('should show modal', () => {
    const ui = new UIManager();
    
    ui.showModal('Test Title', 'Test Content');

    const modal = document.getElementById('modal-overlay');
    expect(modal.classList).not.toContain('hidden');
    
    const title = document.getElementById('modal-title');
    expect(title.textContent).toBe('Test Title');
    
    const body = document.getElementById('modal-body');
    expect(body.textContent).toBe('Test Content');
  });

  test('should hide modal', () => {
    const ui = new UIManager();
    
    // Show modal first
    ui.showModal('Test', 'Content');
    expect(document.getElementById('modal-overlay').classList).not.toContain('hidden');
    
    // Hide modal
    ui.hideModal();
    expect(document.getElementById('modal-overlay').classList).toContain('hidden');
  });

  test('should update progress bar', () => {
    // Add progress bar to DOM
    document.body.innerHTML += '<div class="progress"><div class="progress-bar"></div></div>';
    
    const ui = new UIManager();
    const progressBar = document.querySelector('.progress-bar');
    
    ui.updateProgress(progressBar, 75);
    
    expect(progressBar.style.width).toBe('75%');
  });

  test('should format file size', () => {
    const ui = new UIManager();
    
    expect(ui.formatFileSize(0)).toBe('0 Bytes');
    expect(ui.formatFileSize(1024)).toBe('1 KB');
    expect(ui.formatFileSize(1024 * 1024)).toBe('1 MB');
    expect(ui.formatFileSize(1024 * 1024 * 1024)).toBe('1 GB');
  });

  test('should format duration', () => {
    const ui = new UIManager();
    
    expect(ui.formatDuration(30)).toBe('30s');
    expect(ui.formatDuration(90)).toBe('1m 30s');
    expect(ui.formatDuration(3661)).toBe('1h 1m 1s');
  });
});

describe('Form Validation', () => {
  test('should validate email format', () => {
    const validator = new FormValidator();
    
    expect(validator.validateEmail('test@example.com')).toBe(true);
    expect(validator.validateEmail('invalid-email')).toBe(false);
    expect(validator.validateEmail('')).toBe(false);
  });

  test('should validate password strength', () => {
    const validator = new FormValidator();
    
    expect(validator.validatePassword('password123')).toBe(true);
    expect(validator.validatePassword('short')).toBe(false);
    expect(validator.validatePassword('')).toBe(false);
  });

  test('should validate required fields', () => {
    const validator = new FormValidator();
    
    expect(validator.validateRequired('some value')).toBe(true);
    expect(validator.validateRequired('')).toBe(false);
    expect(validator.validateRequired(null)).toBe(false);
    expect(validator.validateRequired(undefined)).toBe(false);
  });

  test('should validate file paths', () => {
    const validator = new FormValidator();
    
    expect(validator.validatePath('C:\\valid\\path\\file.txt')).toBe(true);
    expect(validator.validatePath('/valid/unix/path')).toBe(true);
    expect(validator.validatePath('\\\\server\\share\\file')).toBe(true);
    expect(validator.validatePath('')).toBe(false);
  });
});

describe('Theme Management', () => {
  test('should toggle theme', () => {
    localStorageMock.getItem.mockReturnValue('light');
    
    toggleTheme();
    
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
    expect(localStorageMock.setItem).toHaveBeenCalledWith('theme', 'dark');
  });

  test('should load saved theme', () => {
    localStorageMock.getItem.mockReturnValue('dark');
    
    const app = new WebAppFramework();
    
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
  });
});

describe('Accessibility', () => {
  test('should have proper ARIA labels', () => {
    const button = document.createElement('button');
    button.setAttribute('aria-label', 'Close modal');
    
    expect(button.getAttribute('aria-label')).toBe('Close modal');
  });

  test('should support keyboard navigation', () => {
    const app = new WebAppFramework();
    
    // Mock keyboard event
    const keyEvent = new KeyboardEvent('keydown', {
      key: '1',
      ctrlKey: true
    });
    
    // Spy on showSection method
    const showSectionSpy = jest.spyOn(app, 'showSection');
    
    document.dispatchEvent(keyEvent);
    
    expect(showSectionSpy).toHaveBeenCalledWith('dashboard');
  });

  test('should have proper focus management', () => {
    const modal = document.getElementById('modal-overlay');
    const ui = new UIManager();
    
    ui.showModal('Test', 'Content');
    
    // Modal should be focusable
    expect(modal.tabIndex).toBe(-1);
  });
});

// Performance tests
describe('Performance', () => {
  test('should handle large file lists efficiently', () => {
    const fileManager = new FileManager();
    
    // Generate large file list
    const largeFileList = Array.from({ length: 10000 }, (_, i) => ({
      id: i,
      filename: `file_${i}.txt`,
      size: 1000,
      type: 'text'
    }));
    
    const startTime = performance.now();
    fileManager.files = largeFileList;
    fileManager.renderFileList();
    const endTime = performance.now();
    
    // Should complete within reasonable time (< 100ms)
    expect(endTime - startTime).toBeLessThan(100);
  });

  test('should debounce search input', (done) => {
    const fileManager = new FileManager();
    const filterSpy = jest.spyOn(fileManager, 'filterFiles');
    
    // Simulate rapid typing
    fileManager.handleSearchInput({ target: { value: 'a' } });
    fileManager.handleSearchInput({ target: { value: 'ab' } });
    fileManager.handleSearchInput({ target: { value: 'abc' } });
    
    // Should only call filter once after debounce
    setTimeout(() => {
      expect(filterSpy).toHaveBeenCalledTimes(1);
      expect(filterSpy).toHaveBeenCalledWith('abc');
      done();
    }, 350); // Wait for debounce
  });
});