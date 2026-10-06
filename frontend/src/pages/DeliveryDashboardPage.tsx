import React, { useState, useEffect } from 'react';
import { deliveryApi } from '../api/deliveryApi';
import { orderApi } from '../api/orderApi';
import { Delivery, DeliveryStatus, Order } from '../types';
import { LoadingSpinner } from '../components/LoadingSpinner';
import { ErrorMessage } from '../components/ErrorMessage';
import { getErrorMessage } from '../api/client';

export const DeliveryDashboardPage: React.FC = () => {
  const [searchOrderId, setSearchOrderId] = useState('');
  const [activeDelivery, setActiveDelivery] = useState<Delivery | null>(null);
  const [recentOrders, setRecentOrders] = useState<Order[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Load recent orders to assist driver with testing
  useEffect(() => {
    orderApi.getMyOrders(0, 10)
      .then((data) => setRecentOrders(data.content || []))
      .catch(() => setRecentOrders([]));
  }, []);

  const handleLookupDelivery = async (orderIdNum?: number) => {
    const inputVal = orderIdNum !== undefined ? String(orderIdNum) : searchOrderId;
    if (!inputVal || !inputVal.trim()) {
      setError('Please enter an Order ID.');
      return;
    }
    const idToLookup = typeof orderIdNum === 'number' ? orderIdNum : parseInt(inputVal.trim(), 10);
    if (isNaN(idToLookup) || idToLookup <= 0) {
      setError('Please enter a valid numeric Order ID.');
      return;
    }

    setIsLoading(true);
    setError(null);
    setSuccessMsg(null);

    try {
      const data = await deliveryApi.getDeliveryByOrderId(idToLookup);
      setActiveDelivery(data);
    } catch (err: any) {
      if (err?.response?.status === 404) {
        setError(`No delivery found for Order #${idToLookup}`);
      } else {
        setError(getErrorMessage(err));
      }
      setActiveDelivery(null);
    } finally {
      setIsLoading(false);
    }
  };

  const handleAssignPartner = async () => {
    if (!activeDelivery) return;
    setActionLoading(true);
    setError(null);
    setSuccessMsg(null);

    try {
      const updated = await deliveryApi.assignPartner(activeDelivery.id);
      setActiveDelivery(updated);
      setSuccessMsg(`Delivery #${updated.id} successfully claimed and assigned to your driver account!`);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setActionLoading(false);
    }
  };

  const handleUpdateStatus = async (nextStatus: DeliveryStatus) => {
    if (!activeDelivery) return;
    setActionLoading(true);
    setError(null);
    setSuccessMsg(null);

    try {
      const updated = await deliveryApi.updateDeliveryStatus(activeDelivery.id, nextStatus);
      setActiveDelivery(updated);
      setSuccessMsg(`Delivery #${updated.id} status updated to: ${nextStatus}`);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="container page-content">
      <div className="page-header-row">
        <div>
          <h1 className="page-title">Delivery Partner Console</h1>
          <p className="page-subtitle">Track, claim, and advance delivery orders through their lifecycle</p>
        </div>
      </div>

      {successMsg && <div className="alert alert-success">{successMsg}</div>}
      {error && <ErrorMessage message={error} />}

      {/* Order Lookup Bar */}
      <div className="card" style={{ marginBottom: '1.5rem' }}>
        <h3 style={{ marginBottom: '0.75rem' }}>Find Delivery by Order ID</h3>
        <div style={{ display: 'flex', gap: '0.75rem', maxWidth: '500px' }}>
          <input
            type="number"
            className="form-input"
            placeholder="Enter Order ID (e.g. 28)"
            value={searchOrderId}
            onChange={(e) => setSearchOrderId(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleLookupDelivery()}
          />
          <button
            onClick={() => handleLookupDelivery()}
            className="btn btn-primary"
            disabled={isLoading}
          >
            {isLoading ? 'Searching...' : 'Search'}
          </button>
        </div>

        {/* Quick select from recent orders */}
        {recentOrders.length > 0 && (
          <div style={{ marginTop: '1rem', fontSize: '0.85rem' }}>
            <span className="text-muted">Recent System Orders: </span>
            {recentOrders.map((ord) => (
              <button
                key={ord.id}
                onClick={() => {
                  setSearchOrderId(ord.id.toString());
                  handleLookupDelivery(ord.id);
                }}
                className="btn btn-secondary btn-sm"
                style={{ marginRight: '0.5rem', marginBottom: '0.25rem', padding: '0.2rem 0.5rem' }}
              >
                #{ord.id} ({ord.status})
              </button>
            ))}
          </div>
        )}
      </div>

      {isLoading && <LoadingSpinner message="Searching for delivery record..." />}

      {/* Active Delivery Card */}
      {activeDelivery && (
        <div className="card">
          <div className="card-header-flex">
            <div>
              <h2 style={{ margin: 0 }}>Delivery Record #{activeDelivery.id}</h2>
              <span className="text-muted">
                Order #{activeDelivery.orderId} &bull; Restaurant #{activeDelivery.restaurantId}
              </span>
            </div>
            <span className="badge badge-blue" style={{ fontSize: '0.95rem' }}>
              {activeDelivery.status.replace(/_/g, ' ')}
            </span>
          </div>

          <hr style={{ margin: '1.25rem 0', borderColor: '#e5e7eb' }} />

          <div className="info-list" style={{ maxWidth: '450px' }}>
            <div className="info-item">
              <span className="info-label">Current Status:</span>
              <span className="info-value"><strong>{activeDelivery.status}</strong></span>
            </div>
            <div className="info-item">
              <span className="info-label">Assigned Partner:</span>
              <span className="info-value">
                {activeDelivery.deliveryPartnerId ? `Partner #${activeDelivery.deliveryPartnerId}` : 'None (Pending Assignment)'}
              </span>
            </div>
          </div>

          <div style={{ marginTop: '2rem' }}>
            <h4>Available Driver Actions</h4>
            
            {activeDelivery.status === 'ASSIGNMENT_PENDING' && (
              <div style={{ marginTop: '0.75rem' }}>
                <p className="text-muted" style={{ marginBottom: '0.5rem' }}>
                  This order is confirmed and waiting for an available delivery partner to accept.
                </p>
                <button
                  onClick={handleAssignPartner}
                  className="btn btn-primary"
                  disabled={actionLoading}
                >
                  {actionLoading ? 'Assigning...' : '✋ Accept & Assign to Me'}
                </button>
              </div>
            )}

            {activeDelivery.status === 'ASSIGNED' && (
              <div style={{ marginTop: '0.75rem' }}>
                <p className="text-muted" style={{ marginBottom: '0.5rem' }}>
                  You are assigned to this order. Proceed to the restaurant and pick up the package.
                </p>
                <button
                  onClick={() => handleUpdateStatus('PICKED_UP')}
                  className="btn btn-primary"
                  disabled={actionLoading}
                >
                  {actionLoading ? 'Updating...' : '📦 Confirm Food Picked Up'}
                </button>
              </div>
            )}

            {activeDelivery.status === 'PICKED_UP' && (
              <div style={{ marginTop: '0.75rem' }}>
                <p className="text-muted" style={{ marginBottom: '0.5rem' }}>
                  Food has been picked up from the kitchen. Start heading to the customer location.
                </p>
                <button
                  onClick={() => handleUpdateStatus('OUT_FOR_DELIVERY')}
                  className="btn btn-primary"
                  disabled={actionLoading}
                >
                  {actionLoading ? 'Updating...' : '🛵 Start Ride (Out for Delivery)'}
                </button>
              </div>
            )}

            {activeDelivery.status === 'OUT_FOR_DELIVERY' && (
              <div style={{ marginTop: '0.75rem' }}>
                <p className="text-muted" style={{ marginBottom: '0.5rem' }}>
                  You are on the way to the customer address. Confirm delivery upon customer handoff.
                </p>
                <button
                  onClick={() => handleUpdateStatus('DELIVERED')}
                  className="btn btn-primary"
                  disabled={actionLoading}
                  style={{ backgroundColor: '#16a34a', borderColor: '#16a34a' }}
                >
                  {actionLoading ? 'Updating...' : '✅ Complete Delivery (Delivered)'}
                </button>
              </div>
            )}

            {activeDelivery.status === 'DELIVERED' && (
              <div className="alert alert-success" style={{ marginTop: '0.75rem' }}>
                🎉 <strong>Delivery Completed!</strong> This order has been successfully fulfilled.
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
