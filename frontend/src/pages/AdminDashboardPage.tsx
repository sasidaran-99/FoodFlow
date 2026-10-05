import React, { useState } from 'react';
import { deliveryApi } from '../api/deliveryApi';
import { orderApi } from '../api/orderApi';
import { OrderStatus, DeliveryPartner } from '../types';
import { ErrorMessage } from '../components/ErrorMessage';
import { getErrorMessage } from '../api/client';

export const AdminDashboardPage: React.FC = () => {
  // Create Partner Form
  const [partnerName, setPartnerName] = useState('');
  const [isCreatingPartner, setIsCreatingPartner] = useState(false);
  const [createdPartner, setCreatedPartner] = useState<DeliveryPartner | null>(null);

  // Order Override Form
  const [targetOrderId, setTargetOrderId] = useState('');
  const [targetOrderStatus, setTargetOrderStatus] = useState<OrderStatus>('CONFIRMED');
  const [isOverridingOrder, setIsOverridingOrder] = useState(false);

  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  const handleCreatePartner = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsCreatingPartner(true);
    setError(null);
    setSuccessMsg(null);

    try {
      const partner = await deliveryApi.createPartner(partnerName.trim());
      setCreatedPartner(partner);
      setSuccessMsg(`Delivery Partner "${partner.name}" (ID #${partner.id}) registered successfully!`);
      setPartnerName('');
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsCreatingPartner(false);
    }
  };

  const handleUpdateOrderStatus = async (e: React.FormEvent) => {
    e.preventDefault();
    const orderIdNum = parseInt(targetOrderId, 10);
    if (!orderIdNum || isNaN(orderIdNum)) {
      setError('Please provide a valid numeric Order ID.');
      return;
    }

    setIsOverridingOrder(true);
    setError(null);
    setSuccessMsg(null);

    try {
      const updatedOrder = await orderApi.updateOrderStatus(orderIdNum, targetOrderStatus);
      setSuccessMsg(`Order #${updatedOrder.id} status successfully transitioned to "${updatedOrder.status}"!`);
      setTargetOrderId('');
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsOverridingOrder(false);
    }
  };

  return (
    <div className="container page-content">
      <div className="page-header-row">
        <div>
          <h1 className="page-title">System Administrator Console</h1>
          <p className="page-subtitle">Configure delivery fleets, system resources, and manage live orders</p>
        </div>
      </div>

      {successMsg && <div className="alert alert-success">{successMsg}</div>}
      {error && <ErrorMessage message={error} />}

      <div className="profile-grid">
        {/* Create Delivery Partner Card */}
        <div className="card">
          <h3>Create Delivery Partner</h3>
          <p className="text-muted" style={{ fontSize: '0.85rem', marginBottom: '1rem' }}>
            Registers a new delivery rider profile in the delivery fleet system (`delivery_db`).
          </p>

          <form onSubmit={handleCreatePartner}>
            <div className="form-group">
              <label>Partner / Courier Name</label>
              <input
                type="text"
                required
                className="form-input"
                placeholder="e.g. Alex Courier Express"
                value={partnerName}
                onChange={(e) => setPartnerName(e.target.value)}
                disabled={isCreatingPartner}
              />
            </div>

            <button
              type="submit"
              className="btn btn-primary"
              disabled={isCreatingPartner || !partnerName.trim()}
              style={{ marginTop: '0.5rem' }}
            >
              {isCreatingPartner ? 'Registering...' : 'Register Partner'}
            </button>
          </form>

          {createdPartner && (
            <div className="alert alert-info" style={{ marginTop: '1rem', fontSize: '0.85rem' }}>
              <strong>Active Partner Created:</strong>
              <div>Name: {createdPartner.name}</div>
              <div>ID: #{createdPartner.id}</div>
              <div>Status: {createdPartner.status}</div>
            </div>
          )}
        </div>

        {/* Order Status Management Card */}
        <div className="card">
          <h3>Admin Order Status Control</h3>
          <p className="text-muted" style={{ fontSize: '0.85rem', marginBottom: '1rem' }}>
            Directly update an order's state machine status (`order-service`).
          </p>

          <form onSubmit={handleUpdateOrderStatus}>
            <div className="form-group">
              <label>Target Order ID</label>
              <input
                type="number"
                required
                className="form-input"
                placeholder="e.g. 28"
                value={targetOrderId}
                onChange={(e) => setTargetOrderId(e.target.value)}
                disabled={isOverridingOrder}
              />
            </div>

            <div className="form-group">
              <label>New Status</label>
              <select
                className="form-select"
                value={targetOrderStatus}
                onChange={(e) => setTargetOrderStatus(e.target.value as OrderStatus)}
                disabled={isOverridingOrder}
              >
                <option value="CONFIRMED">CONFIRMED</option>
                <option value="RESTAURANT_ACCEPTED">RESTAURANT_ACCEPTED</option>
                <option value="PREPARING">PREPARING</option>
                <option value="READY_FOR_PICKUP">READY_FOR_PICKUP</option>
                <option value="OUT_FOR_DELIVERY">OUT_FOR_DELIVERY</option>
                <option value="DELIVERED">DELIVERED</option>
                <option value="CANCELLED">CANCELLED</option>
              </select>
            </div>

            <button
              type="submit"
              className="btn btn-secondary"
              disabled={isOverridingOrder || !targetOrderId.trim()}
              style={{ marginTop: '0.5rem' }}
            >
              {isOverridingOrder ? 'Updating...' : 'Update Order Status'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};
