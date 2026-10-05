import axios, { AxiosError } from 'axios';

export const API_BASE_URL = (import.meta as { env?: Record<string, string> }).env?.VITE_API_BASE_URL || 'http://localhost:8080';

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 10000,
});

// Request Interceptor: Attach JWT Bearer Token
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('foodflow_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response Interceptor: Normalized Error Handling
apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response) {
      const status = error.response.status;

      if (status === 401) {
        // Clear stale session
        localStorage.removeItem('foodflow_token');
        localStorage.removeItem('foodflow_user');
        if (window.location.pathname !== '/login' && window.location.pathname !== '/register') {
          window.location.href = '/login?expired=true';
        }
      } else if (status === 403) {
        console.warn('Access Forbidden: Insufficient permissions for resource.');
      } else if (status === 429) {
        console.warn('Rate Limit Exceeded: Too many requests sent in rapid succession.');
      }
    }
    return Promise.reject(error);
  }
);

// Helper function to extract user-friendly error message
export const getErrorMessage = (error: unknown): string => {
  if (axios.isAxiosError(error)) {
    if (error.response) {
      const status = error.response.status;
      const data = error.response.data;

      if (typeof data === 'string' && data.trim().length > 0) {
        return data;
      }
      if (typeof data === 'object' && data !== null) {
        const errorObj = data as Record<string, unknown>;
        if (errorObj.message && typeof errorObj.message === 'string') {
          return errorObj.message;
        }
        if (errorObj.error && typeof errorObj.error === 'string') {
          return errorObj.error;
        }
      }

      if (status === 400) return 'Invalid request data. Please check your inputs.';
      if (status === 401) return 'Invalid credentials or expired session. Please log in.';
      if (status === 403) return 'You do not have permission to perform this action.';
      if (status === 404) return 'Requested resource not found.';
      if (status === 409) return 'Conflict: Resource already exists.';
      if (status === 429) return 'Too many requests. Please wait a moment and try again.';
      if (status >= 500) return 'Backend server error. Please try again later.';
    } else if (error.request) {
      return 'Cannot reach API Gateway at http://localhost:8080. Ensure backend services are running.';
    }
  }
  return (error as Error)?.message || 'An unexpected error occurred.';
};
