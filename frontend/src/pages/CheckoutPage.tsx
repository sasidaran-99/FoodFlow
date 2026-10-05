import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useCart } from '../context/CartContext';
import { useAuth } from '../context/AuthContext';
import { orderApi } from '../api/orderApi';
import { userApi } from '../api/userApi';
import { Address } from '../types';
import { ErrorMessage } from '../components/ErrorMessage';
import { getErrorMessage } from '../api/client';

export const CheckoutPage: React.FC = () => {
  const { items, restaurantId, restaurantName, totalAmount, clearCart } = useCart();
  const { user } = useAuth();
  const navigate = useNavigate();

  const [addresses, setAddresses] = useState<Address[]>([]);
  const [selectedAddressId, setSelectedAddressId] = useState<number | null>(null);
  const [isPlacingOrder, setIsPlacingOrder] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchUserAddresses = async () => {
      try {
        const addressList = await userApi.getAddresses();
        setAddresses(addressList);
        if (addressList.length > 0) {
          setSelectedAddressId(addressList[0].id || null);
        }
      } catch (err) {
        // Non-fatal if addresses can't be fetched
        console.warn('Could not load user addresses:', err);
      }
    };

    fetchUserAddresses();
  }, []);

  if (items.length === 0 || !restaurantId) {
    return (
      <div className="container page-content">
        <div className="empty-state-box">
          <span className="empty-state-icon">🛒</span>
          <h2>Your Cart is Empty</h2>
          <p>Please select items from a restaurant before checking out.</p>
          <Link to="/" className="btn btn-primary" style={{ marginTop: '1rem' }}>
            Browse Restaurants
          </Link>
        </div>
      </div>
    );
  }

  const handlePlaceOrder = async () => {
    setError(null);
    setIsPlacingOrder(true);

    try {
      const orderPayload = {
        restaurantId,
        items: items.map((item) => ({
          menuItemId: item.menuItemId,
          quantity: item.quantity,
        })),
      };

      const createdOrder = await orderApi.createOrder(orderPayload);
      clearCart();
      // Navigate to order details page where status tracking and Kafka events unfold
      navigate(`/orders/${createdOrder.id}?created=true`);
    } catch (err) {
      setError(getErrorMessage(err));
      setIsPlacingOrder(false);
    }
  };

  return (
    <div className="container page-content">
      <div className="page-header-row">
        <div>
          <h1 className="page-title">Checkout & Confirm Order</h1>
          <p className="page-subtitle">Review your order details before placing</p>
        </div>
      </div>

      {error && <ErrorMessage message={error} />}

      <div className="checkout-layout">
        {/* Left column: Order Review & Delivery Info */}
        <div className="checkout-main">
          {/* Customer & Address Card */}
          <div className="card" style={{ marginBottom: '1.5rem' }}>
            <h3 style={{ marginBottom: '1rem' }}>Delivery Information</h3>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem' }}>
              <div>
                <label className="text-muted">Customer Name</label>
                <p><strong>{user?.name}</strong></p>
              </div>
              <div>
                <label className="text-muted">Phone Number</label>
                <p><strong>{user?.phone}</strong></p>
              </div>
              <div>
                <label className="text-muted">Email</label>
                <p><strong>{user?.email}</strong></p>
              </div>
            </div>

            <hr style={{ margin: '1rem 0', borderColor: '#e5e7eb' }} />

            <div>
              <label className="text-muted">Delivery Address</label>
              {addresses.length > 0 ? (
                <div style={{ marginTop: '0.5rem' }}>
                  {addresses.map((addr) => (
                    <label key={addr.id} className="radio-address-option">
                      <input
                        type="radio"
                        name="addressSelection"
                        checked={selectedAddressId === addr.id}
                        onChange={() => setSelectedAddressId(addr.id || null)}
                      />
                      <span>
                        {addr.street}, {addr.city}, {addr.state} - {addr.zipCode}, {addr.country}
                      </span>
                    </label>
                  ))}
                </div>
              ) : (
                <p style={{ marginTop: '0.25rem', color: '#4b5563' }}>
                  Standard address associated with your account. You can manage saved addresses in your <Link to="/profile">Profile</Link>.
                </p>
              )}
            </div>
          </div>

          {/* Items Review Card */}
          <div className="card">
            <h3 style={{ marginBottom: '1rem' }}>
              Items from: {restaurantName || `Restaurant #${restaurantId}`}
            </h3>

            <div className="checkout-items-list">
              {items.map((item) => (
                <div key={item.menuItemId} className="checkout-item-row">
                  <div>
                    <strong>{item.name}</strong> &times; {item.quantity}
                  </div>
                  <div>
                    ₹{(item.price * item.quantity).toFixed(2)}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Right column: Summary & Payment Notice */}
        <div className="checkout-sidebar">
          <div className="card">
            <h3>Payment Summary</h3>
            <div className="summary-row">
              <span>Items Total:</span>
              <span>₹{totalAmount.toFixed(2)}</span>
            </div>
            <div className="summary-row">
              <span>Delivery Fee:</span>
              <span style={{ color: '#16a34a' }}>FREE</span>
            </div>
            <div className="summary-row">
              <span>Taxes & Charges:</span>
              <span>₹0.00</span>
            </div>

            <hr style={{ margin: '1rem 0', borderColor: '#e5e7eb' }} />

            <div className="summary-row total-row">
              <span>Total Payable:</span>
              <span>₹{totalAmount.toFixed(2)}</span>
            </div>

            <div className="payment-mode-notice">
              <span style={{ fontSize: '1.25rem' }}>⚡</span>
              <div>
                <strong>Asynchronous Mock Payment</strong>
                <p style={{ margin: 0, fontSize: '0.85rem', color: '#4b5563' }}>
                  Upon placing the order, the FoodFlow Kafka event pipeline automatically processes the payment and transitions your order to CONFIRMED.
                </p>
              </div>
            </div>

            <button
              onClick={handlePlaceOrder}
              disabled={isPlacingOrder}
              className="btn btn-primary btn-block btn-lg"
              style={{ marginTop: '1.5rem' }}
            >
              {isPlacingOrder ? 'Submitting Order...' : `Place Order (₹${totalAmount.toFixed(2)})`}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
