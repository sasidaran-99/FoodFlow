import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useCart } from '../context/CartContext';
import { useAuth } from '../context/AuthContext';

export const CartPage: React.FC = () => {
  const { items, restaurantId, restaurantName, updateQuantity, removeItem, clearCart, totalAmount, totalItems } = useCart();
  const { isAuthenticated } = useAuth();
  const navigate = useNavigate();

  if (items.length === 0) {
    return (
      <div className="container page-content">
        <div className="empty-state-box">
          <span className="empty-state-icon">🛒</span>
          <h2>Your Cart is Empty</h2>
          <p>Looks like you haven't added any items to your cart yet.</p>
          <Link to="/" className="btn btn-primary" style={{ marginTop: '1rem' }}>
            Browse Restaurants
          </Link>
        </div>
      </div>
    );
  }

  const handleCheckout = () => {
    if (!isAuthenticated) {
      navigate('/login', { state: { from: { pathname: '/checkout' } } });
    } else {
      navigate('/checkout');
    }
  };

  return (
    <div className="container page-content">
      <div className="page-header-row">
        <div>
          <h1 className="page-title">Your Food Cart</h1>
          <p className="page-subtitle">
            Ordering from: <strong>{restaurantName || `Restaurant #${restaurantId}`}</strong>
          </p>
        </div>
        <button onClick={clearCart} className="btn btn-secondary btn-sm" title="Clear all items">
          🗑️ Clear Cart
        </button>
      </div>

      <div className="cart-layout">
        {/* Cart Item List */}
        <div className="cart-items-card card">
          <div className="cart-table-header">
            <span>Item</span>
            <span style={{ textAlign: 'center' }}>Quantity</span>
            <span style={{ textAlign: 'right' }}>Price</span>
            <span style={{ textAlign: 'right' }}>Subtotal</span>
            <span></span>
          </div>

          <div className="cart-items-list">
            {items.map((item) => (
              <div key={item.menuItemId} className="cart-item-row">
                <div className="cart-item-name">
                  <strong>{item.name}</strong>
                </div>

                <div className="cart-item-qty">
                  <div className="quantity-control-group">
                    <button
                      onClick={() => updateQuantity(item.menuItemId, item.quantity - 1)}
                      className="qty-btn"
                    >
                      -
                    </button>
                    <span className="qty-value">{item.quantity}</span>
                    <button
                      onClick={() => updateQuantity(item.menuItemId, item.quantity + 1)}
                      className="qty-btn"
                    >
                      +
                    </button>
                  </div>
                </div>

                <div className="cart-item-price" style={{ textAlign: 'right' }}>
                  ₹{Number(item.price).toFixed(2)}
                </div>

                <div className="cart-item-subtotal" style={{ textAlign: 'right' }}>
                  <strong>₹{(item.price * item.quantity).toFixed(2)}</strong>
                </div>

                <div className="cart-item-remove">
                  <button
                    onClick={() => removeItem(item.menuItemId)}
                    className="btn-icon"
                    title="Remove item"
                  >
                    ✕
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Order Summary Card */}
        <div className="cart-summary-card card">
          <h3>Order Summary</h3>
          <div className="summary-row">
            <span>Items Count:</span>
            <span>{totalItems}</span>
          </div>
          <div className="summary-row">
            <span>Items Subtotal:</span>
            <span>₹{totalAmount.toFixed(2)}</span>
          </div>
          <div className="summary-row">
            <span>Delivery Fee:</span>
            <span style={{ color: '#16a34a' }}>FREE</span>
          </div>
          <hr style={{ margin: '1rem 0', borderColor: '#e5e7eb' }} />
          <div className="summary-row total-row">
            <span>Total Payable:</span>
            <span>₹{totalAmount.toFixed(2)}</span>
          </div>

          <button onClick={handleCheckout} className="btn btn-primary btn-block" style={{ marginTop: '1.5rem' }}>
            {isAuthenticated ? 'Proceed to Checkout →' : 'Sign In to Checkout →'}
          </button>
        </div>
      </div>
    </div>
  );
};
