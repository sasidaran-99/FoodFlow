import React from 'react';
import { Navigate, useLocation, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Role } from '../types';
import { LoadingSpinner } from './LoadingSpinner';

interface ProtectedRouteProps {
  children: React.ReactNode;
  allowedRoles?: Role[];
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ children, allowedRoles }) => {
  const { isAuthenticated, isLoading, user } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return <LoadingSpinner message="Authenticating..." />;
  }

  if (!isAuthenticated || !user) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  if (allowedRoles && allowedRoles.length > 0 && !allowedRoles.includes(user.role)) {
    return (
      <div className="container page-content">
        <div className="card" style={{ maxWidth: '600px', margin: '3rem auto', textAlign: 'center' }}>
          <h2 style={{ color: '#dc2626', marginBottom: '1rem' }}>403 - Access Denied</h2>
          <p style={{ color: '#4b5563', marginBottom: '1.5rem' }}>
            Your account role is <strong>{user.role}</strong>, which does not have permission to access this page.
          </p>
          <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center' }}>
            <Link to="/" className="btn btn-primary">
              Return to Restaurants
            </Link>
            {user.role === 'RESTAURANT_OWNER' && (
              <Link to="/owner/restaurants" className="btn btn-secondary">
                Go to Owner Dashboard
              </Link>
            )}
            {user.role === 'DELIVERY_PARTNER' && (
              <Link to="/delivery" className="btn btn-secondary">
                Go to Delivery Dashboard
              </Link>
            )}
            {user.role === 'ADMIN' && (
              <Link to="/admin" className="btn btn-secondary">
                Go to Admin Dashboard
              </Link>
            )}
          </div>
        </div>
      </div>
    );
  }

  return <>{children}</>;
};
