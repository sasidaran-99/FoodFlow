import React from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useCart } from '../context/CartContext';

export const Navbar: React.FC = () => {
  const { user, isAuthenticated, logout } = useAuth();
  const { totalItems } = useCart();
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const isActive = (path: string) => {
    return location.pathname === path ? 'nav-link active' : 'nav-link';
  };

  return (
    <header className="navbar-wrapper">
      <div className="container navbar-container">
        {/* Brand */}
        <Link to="/" className="navbar-brand">
          <span className="brand-icon">🍔</span>
          <span className="brand-name">FoodFlow</span>
        </Link>

        {/* Main Navigation */}
        <nav className="navbar-links">
          {(!isAuthenticated || user?.role === 'CUSTOMER') && (
            <>
              <Link to="/" className={isActive('/')}>
                Restaurants
              </Link>
              {isAuthenticated && (
                <>
                  <Link to="/orders" className={isActive('/orders')}>
                    My Orders
                  </Link>
                  <Link to="/notifications" className={isActive('/notifications')}>
                    Notifications
                  </Link>
                </>
              )}
            </>
          )}

          {user?.role === 'RESTAURANT_OWNER' && (
            <>
              <Link to="/owner/restaurants" className={isActive('/owner/restaurants')}>
                My Restaurants
              </Link>
              <Link to="/orders" className={isActive('/orders')}>
                All Orders
              </Link>
              <Link to="/notifications" className={isActive('/notifications')}>
                Notifications
              </Link>
            </>
          )}

          {user?.role === 'DELIVERY_PARTNER' && (
            <>
              <Link to="/delivery" className={isActive('/delivery')}>
                Delivery Dashboard
              </Link>
              <Link to="/notifications" className={isActive('/notifications')}>
                Notifications
              </Link>
            </>
          )}

          {user?.role === 'ADMIN' && (
            <>
              <Link to="/admin" className={isActive('/admin')}>
                Admin Console
              </Link>
              <Link to="/orders" className={isActive('/orders')}>
                System Orders
              </Link>
              <Link to="/notifications" className={isActive('/notifications')}>
                Notifications
              </Link>
            </>
          )}
        </nav>

        {/* Right Actions */}
        <div className="navbar-actions">
          {isAuthenticated ? (
            <>
              {(!user || user.role === 'CUSTOMER') && (
                <Link to="/cart" className="cart-badge-link" title="View Cart">
                  <span className="cart-icon">🛒</span>
                  <span>Cart</span>
                  {totalItems > 0 && <span className="cart-count">{totalItems}</span>}
                </Link>
              )}

              <div className="user-profile-badge">
                <span className={`role-pill role-${user?.role?.toLowerCase()}`}>
                  {user?.role?.replace('_', ' ')}
                </span>
                <Link to="/profile" className="user-name-link" title="View Profile">
                  👤 {user?.name || user?.email}
                </Link>
              </div>

              <button onClick={handleLogout} className="btn btn-secondary btn-sm">
                Log Out
              </button>
            </>
          ) : (
            <div className="auth-nav-buttons">
              <Link to="/cart" className="cart-badge-link" title="View Cart">
                <span className="cart-icon">🛒</span>
                <span>Cart</span>
                {totalItems > 0 && <span className="cart-count">{totalItems}</span>}
              </Link>
              <Link to="/login" className="btn btn-secondary btn-sm">
                Log In
              </Link>
              <Link to="/register" className="btn btn-primary btn-sm">
                Sign Up
              </Link>
            </div>
          )}
        </div>
      </div>
    </header>
  );
};
