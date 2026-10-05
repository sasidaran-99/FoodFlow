import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { restaurantApi } from '../api/restaurantApi';
import { Restaurant, MenuItem } from '../types';
import { useCart } from '../context/CartContext';
import { useAuth } from '../context/AuthContext';
import { LoadingSpinner } from '../components/LoadingSpinner';
import { ErrorMessage } from '../components/ErrorMessage';
import { getErrorMessage } from '../api/client';

export const RestaurantDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const restaurantId = parseInt(id || '0', 10);
  const { isAuthenticated } = useAuth();

  const [restaurant, setRestaurant] = useState<Restaurant | null>(null);
  const [menu, setMenu] = useState<MenuItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const { items, addItem, updateQuantity, totalItems, totalAmount } = useCart();

  const fetchRestaurantAndMenu = async () => {
    if (!restaurantId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [restData, menuData] = await Promise.all([
        restaurantApi.getRestaurantById(restaurantId),
        restaurantApi.getMenu(restaurantId),
      ]);
      setRestaurant(restData);
      setMenu(menuData);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (isAuthenticated) {
      fetchRestaurantAndMenu();
    } else {
      setIsLoading(false);
    }
  }, [restaurantId, isAuthenticated]);

  const getItemQuantity = (menuItemId: number): number => {
    const item = items.find((i) => i.menuItemId === menuItemId);
    return item ? item.quantity : 0;
  };

  return (
    <div className="container page-content">
      {/* Back Link */}
      <Link to="/" className="back-link">
        &larr; Back to all restaurants
      </Link>

      {isLoading && <LoadingSpinner message="Loading restaurant and menu items..." />}
      {error && <ErrorMessage message={error} onRetry={fetchRestaurantAndMenu} />}

      {!isAuthenticated && !isLoading && (
        <div className="card empty-state-box" style={{ margin: '2rem auto', maxWidth: '520px' }}>
          <span className="empty-state-icon">🔐</span>
          <h2>Sign In Required</h2>
          <p>Please log in or create an account to view this restaurant's menu and place orders.</p>
          <div style={{ marginTop: '1.25rem', display: 'flex', gap: '0.75rem', justifyContent: 'center' }}>
            <Link to="/login" state={{ from: { pathname: `/restaurants/${restaurantId}` } }} className="btn btn-primary">
              Sign In to Order
            </Link>
            <Link to="/register" className="btn btn-secondary">
              Create Account
            </Link>
          </div>
        </div>
      )}

      {!isLoading && isAuthenticated && restaurant && (
        <>
          {/* Restaurant Banner Header */}
          <div className="restaurant-banner card">
            <div className="banner-details">
              <div className="banner-title-row">
                <h1 className="banner-title">{restaurant.name}</h1>
                <span className={`status-pill ${restaurant.open ? 'status-open' : 'status-closed'}`}>
                  {restaurant.open ? '● Open Now' : 'Closed for Orders'}
                </span>
              </div>
              <p className="banner-desc">{restaurant.description || 'Delicious freshly prepared meals.'}</p>
              <p className="banner-meta">
                <span>📍 {restaurant.address}</span>
              </p>
            </div>
          </div>

          {/* Menu Section */}
          <div className="menu-section">
            <div className="section-header">
              <h2>Menu Items ({menu.length})</h2>
              {!restaurant.open && (
                <span className="text-warning">
                  ⚠️ This restaurant is currently closed. Items cannot be added to cart.
                </span>
              )}
            </div>

            {menu.length === 0 ? (
              <div className="empty-state-box">
                <span className="empty-state-icon">📋</span>
                <h3>No Menu Items Available</h3>
                <p>This restaurant has not added any dishes to its menu yet.</p>
              </div>
            ) : (
              <div className="menu-list">
                {menu.map((dish) => {
                  const qty = getItemQuantity(dish.id);
                  const isAvailable = dish.available && restaurant.open;

                  return (
                    <div key={dish.id} className="menu-item-row card">
                      <div className="dish-info">
                        <div className="dish-name-row">
                          <h4 className="dish-name">{dish.name}</h4>
                          {!dish.available && <span className="badge badge-gray">Out of stock</span>}
                        </div>
                        {dish.description && <p className="dish-description">{dish.description}</p>}
                        <div className="dish-price">₹{Number(dish.price).toFixed(2)}</div>
                      </div>

                      <div className="dish-action">
                        {qty > 0 ? (
                          <div className="quantity-control-group">
                            <button
                              onClick={() => updateQuantity(dish.id, qty - 1)}
                              className="qty-btn"
                              title="Decrease"
                            >
                              -
                            </button>
                            <span className="qty-value">{qty}</span>
                            <button
                              onClick={() => updateQuantity(dish.id, qty + 1)}
                              className="qty-btn"
                              title="Increase"
                              disabled={!dish.available}
                            >
                              +
                            </button>
                          </div>
                        ) : (
                          <button
                            onClick={() => addItem(restaurant.id, restaurant.name, dish)}
                            className="btn btn-primary btn-sm"
                            disabled={!isAvailable}
                          >
                            + Add to Cart
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* Floating Cart Indicator */}
          {totalItems > 0 && (
            <div className="floating-cart-bar">
              <div className="container floating-cart-container">
                <div className="floating-cart-info">
                  <span className="floating-cart-qty">{totalItems} item{totalItems > 1 ? 's' : ''}</span>
                  <span className="floating-cart-total">Total: ₹{totalAmount.toFixed(2)}</span>
                </div>
                <Link to="/checkout" className="btn btn-primary">
                  Proceed to Checkout &rarr;
                </Link>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
};
