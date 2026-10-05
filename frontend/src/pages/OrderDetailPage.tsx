import React, { useState, useEffect, useCallback } from 'react';
import { useParams, useLocation, Link } from 'react-router-dom';
import { orderApi } from '../api/orderApi';
import { paymentApi } from '../api/paymentApi';
import { notificationApi } from '../api/notificationApi';
import { deliveryApi } from '../api/deliveryApi';
import { Order, Payment, Notification, Delivery } from '../types';
import { LoadingSpinner } from '../components/LoadingSpinner';
import { ErrorMessage } from '../components/ErrorMessage';
import { getErrorMessage } from '../api/client';

export const OrderDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const orderId = parseInt(id || '0', 10);
  const location = useLocation();

  const [order, setOrder] = useState<Order | null>(null);
  const [payment, setPayment] = useState<Payment | null>(null);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [delivery, setDelivery] = useState<Delivery | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [autoRefresh, setAutoRefresh] = useState(true);

  const isJustCreated = location.search.includes('created=true');

  const fetchOrderDetails = useCallback(async () => {
    if (!orderId) return;
    setError(null);

    try {
      // 1. Fetch Order (Primary)
      const orderData = await orderApi.getOrderById(orderId);
      setOrder(orderData);

      // 2. Fetch Payment (Parallel tolerant)
      paymentApi.getPaymentByOrderId(orderId)
        .then((p) => setPayment(p))
        .catch(() => setPayment(null));

      // 3. Fetch Notifications (Parallel tolerant)
      notificationApi.getOrderNotifications(orderId)
        .then((nList) => setNotifications(Array.isArray(nList) ? nList : [nList].filter(Boolean)))
        .catch(() => setNotifications([]));

      // 4. Fetch Delivery (Parallel tolerant)
      deliveryApi.getDeliveryByOrderId(orderId)
        .then((d) => setDelivery(d))
        .catch(() => setDelivery(null));

    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }, [orderId]);

  useEffect(() => {
    fetchOrderDetails();
  }, [fetchOrderDetails]);

  // Polling for live status updates if order is in transient state
  useEffect(() => {
    if (!autoRefresh) return;
    // If order has reached terminal state, stop polling
    if (order && (order.status === 'DELIVERED' || order.status === 'PAYMENT_FAILED' || order.status === 'CANCELLED')) {
      return;
    }

    const interval = setInterval(() => {
      fetchOrderDetails();
    }, 3000);

    return () => clearInterval(interval);
  }, [autoRefresh, order, fetchOrderDetails]);

  const getStepStatus = (stepName: string) => {
    if (!order) return 'upcoming';

    if (order.status === 'PAYMENT_FAILED') {
      return stepName === 'PAYMENT_PENDING' ? 'failed' : 'upcoming';
    }

    const orderStatusFlow = [
      'PAYMENT_PENDING',
      'CONFIRMED',
      'ASSIGNED',
      'PICKED_UP',
      'OUT_FOR_DELIVERY',
      'DELIVERED',
    ];

    // Map delivery status if present
    let currentEffectiveStatus = order.status as string;
    if (delivery && delivery.status && delivery.status !== 'ASSIGNMENT_PENDING') {
      currentEffectiveStatus = delivery.status;
    }

    const currentIndex = orderStatusFlow.indexOf(currentEffectiveStatus);
    const stepIndex = orderStatusFlow.indexOf(stepName);

    if (currentIndex >= stepIndex) return 'completed';
    if (currentIndex === stepIndex - 1) return 'current';
    return 'upcoming';
  };

  return (
    <div className="container page-content">
      {/* Top back navigation */}
      <Link to="/orders" className="back-link">
        &larr; Back to My Orders
      </Link>

      {/* Success banner if just placed */}
      {isJustCreated && (
        <div className="alert alert-success" style={{ marginBottom: '1.5rem' }}>
          🎉 <strong>Order #{orderId} Placed Successfully!</strong> The Kafka event pipeline is actively processing your payment.
        </div>
      )}

      {/* Header */}
      <div className="page-header-row">
        <div>
          <h1 className="page-title">Order #{orderId}</h1>
          <p className="page-subtitle">
            {order ? `Placed on ${new Date(order.createdAt).toLocaleString()} &bull; Restaurant #${order.restaurantId}` : 'Loading order details...'}
          </p>
        </div>
        <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
          <label className="checkbox-label" style={{ fontSize: '0.85rem' }}>
            <input
              type="checkbox"
              checked={autoRefresh}
              onChange={(e) => setAutoRefresh(e.target.checked)}
            />
            Auto-refresh (3s)
          </label>
          <button onClick={fetchOrderDetails} className="btn btn-secondary btn-sm" disabled={isLoading}>
            🔄 Refresh Now
          </button>
        </div>
      </div>

      {isLoading && <LoadingSpinner message="Retrieving order details and tracking status..." />}
      {error && <ErrorMessage message={error} onRetry={fetchOrderDetails} />}

      {!isLoading && order && (
        <>
          {/* Status Tracker Bar */}
          <div className="card" style={{ marginBottom: '1.5rem' }}>
            <h3 style={{ marginBottom: '1.5rem' }}>Live Order Status Progression</h3>
            
            <div className="status-timeline">
              {[
                { key: 'PAYMENT_PENDING', label: 'Payment Pending' },
                { key: 'CONFIRMED', label: 'Confirmed' },
                { key: 'ASSIGNED', label: 'Driver Assigned' },
                { key: 'PICKED_UP', label: 'Food Picked Up' },
                { key: 'OUT_FOR_DELIVERY', label: 'Out for Delivery' },
                { key: 'DELIVERED', label: 'Delivered' },
              ].map((step, idx) => {
                const stepState = getStepStatus(step.key);
                return (
                  <div key={idx} className={`timeline-step step-${stepState}`}>
                    <div className="step-circle">
                      {stepState === 'completed' ? '✓' : idx + 1}
                    </div>
                    <span className="step-label">{step.label}</span>
                  </div>
                );
              })}
            </div>

            {order.status === 'PAYMENT_FAILED' && (
              <div className="alert alert-error" style={{ marginTop: '1.5rem' }}>
                ❌ <strong>Payment Failed:</strong> This order could not be completed due to payment rejection.
              </div>
            )}
          </div>

          <div className="order-details-grid">
            {/* Left Column: Ordered Items */}
            <div className="card">
              <h3>Ordered Items</h3>
              <div className="order-items-table">
                {order.items && order.items.map((item, idx) => (
                  <div key={idx} className="order-detail-item-row">
                    <div>
                      <strong>{item.name || `Menu Item #${item.menuItemId}`}</strong>
                      <span className="text-muted" style={{ display: 'block', fontSize: '0.85rem' }}>
                        Qty: {item.quantity} &times; ₹{Number(item.price).toFixed(2)}
                      </span>
                    </div>
                    <div style={{ textAlign: 'right' }}>
                      <strong>₹{(Number(item.price) * item.quantity).toFixed(2)}</strong>
                    </div>
                  </div>
                ))}
              </div>

              <hr style={{ margin: '1rem 0', borderColor: '#e5e7eb' }} />

              <div className="summary-row total-row">
                <span>Total Amount:</span>
                <span>₹{Number(order.totalAmount).toFixed(2)}</span>
              </div>
            </div>

            {/* Right Column: Payment & Delivery Subsystems */}
            <div className="order-subsystems-column">
              {/* Payment Details */}
              <div className="card" style={{ marginBottom: '1.5rem' }}>
                <h3>Payment Verification</h3>
                {payment ? (
                  <div className="info-list">
                    <div className="info-item">
                      <span className="info-label">Payment ID:</span>
                      <span className="info-value">#{payment.id}</span>
                    </div>
                    <div className="info-item">
                      <span className="info-label">Status:</span>
                      <span className={`badge ${payment.status === 'SUCCESS' ? 'badge-green' : 'badge-red'}`}>
                        {payment.status}
                      </span>
                    </div>
                    <div className="info-item">
                      <span className="info-label">Reference Number:</span>
                      <span className="info-value"><code>{payment.referenceNumber}</code></span>
                    </div>
                    <div className="info-item">
                      <span className="info-label">Amount:</span>
                      <span className="info-value">₹{Number(payment.amount).toFixed(2)}</span>
                    </div>
                    <div className="info-item">
                      <span className="info-label">Processed At:</span>
                      <span className="info-value">{new Date(payment.createdAt).toLocaleTimeString()}</span>
                    </div>
                  </div>
                ) : (
                  <p className="text-muted" style={{ fontSize: '0.9rem' }}>
                    Payment processing through Kafka... (Click Refresh to check)
                  </p>
                )}
              </div>

              {/* Delivery Details */}
              <div className="card">
                <h3>Delivery Status</h3>
                {delivery ? (
                  <div className="info-list">
                    <div className="info-item">
                      <span className="info-label">Delivery ID:</span>
                      <span className="info-value">#{delivery.id}</span>
                    </div>
                    <div className="info-item">
                      <span className="info-label">Status:</span>
                      <span className="badge badge-blue">{delivery.status.replace(/_/g, ' ')}</span>
                    </div>
                    <div className="info-item">
                      <span className="info-label">Delivery Partner:</span>
                      <span className="info-value">
                        {delivery.deliveryPartnerId ? `Partner #${delivery.deliveryPartnerId}` : 'Awaiting Driver Assignment'}
                      </span>
                    </div>
                  </div>
                ) : (
                  <p className="text-muted" style={{ fontSize: '0.9rem' }}>
                    Delivery record will initialize once payment is confirmed.
                  </p>
                )}
              </div>
            </div>
          </div>

          {/* Notifications Log */}
          {notifications.length > 0 && (
            <div className="card" style={{ marginTop: '1.5rem' }}>
              <h3>Order Event Notifications ({notifications.length})</h3>
              <div className="notifications-list" style={{ marginTop: '1rem' }}>
                {notifications.map((notif) => (
                  <div key={notif.id} className="notification-item">
                    <span className="notif-badge">{notif.type}</span>
                    <div className="notif-body">
                      <p className="notif-msg">{notif.message}</p>
                      <span className="notif-time">{new Date(notif.createdAt).toLocaleTimeString()}</span>
                    </div>
                    <span className="badge badge-gray">{notif.status}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
};
