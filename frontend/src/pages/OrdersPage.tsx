import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { orderApi } from '../api/orderApi';
import { Order, SpringPage } from '../types';
import { LoadingSpinner } from '../components/LoadingSpinner';
import { ErrorMessage } from '../components/ErrorMessage';
import { getErrorMessage } from '../api/client';

export const OrdersPage: React.FC = () => {
  const [ordersPage, setOrdersPage] = useState<SpringPage<Order> | null>(null);
  const [page, setPage] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchOrders = async (pageNum: number) => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await orderApi.getMyOrders(pageNum, 10);
      setOrdersPage(data);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchOrders(page);
  }, [page]);

  const getStatusBadgeClass = (status: string) => {
    switch (status) {
      case 'CONFIRMED':
      case 'DELIVERED':
        return 'badge badge-green';
      case 'PAYMENT_PENDING':
      case 'PREPARING':
      case 'ASSIGNED':
      case 'PICKED_UP':
      case 'OUT_FOR_DELIVERY':
        return 'badge badge-blue';
      case 'PAYMENT_FAILED':
      case 'REJECTED':
      case 'CANCELLED':
        return 'badge badge-red';
      default:
        return 'badge badge-gray';
    }
  };

  const orders = ordersPage?.content || [];

  return (
    <div className="container page-content">
      <div className="page-header-row">
        <div>
          <h1 className="page-title">My Orders</h1>
          <p className="page-subtitle">Track, view details, and review your past orders</p>
        </div>
        <button onClick={() => fetchOrders(page)} className="btn btn-secondary btn-sm" disabled={isLoading}>
          🔄 Refresh
        </button>
      </div>

      {isLoading && <LoadingSpinner message="Fetching your orders..." />}
      {error && <ErrorMessage message={error} onRetry={() => fetchOrders(page)} />}

      {!isLoading && !error && orders.length === 0 && (
        <div className="empty-state-box">
          <span className="empty-state-icon">📦</span>
          <h3>No Orders Found</h3>
          <p>You have not placed any food orders yet.</p>
          <Link to="/" className="btn btn-primary" style={{ marginTop: '1rem' }}>
            Find Food Now
          </Link>
        </div>
      )}

      {!isLoading && !error && orders.length > 0 && (
        <>
          <div className="orders-list">
            {orders.map((order) => (
              <div key={order.id} className="order-card card">
                <div className="order-card-header">
                  <div>
                    <h3 style={{ margin: 0 }}>Order #{order.id}</h3>
                    <span className="text-muted" style={{ fontSize: '0.85rem' }}>
                      {new Date(order.createdAt).toLocaleString()} &bull; Restaurant #{order.restaurantId}
                    </span>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <span className={getStatusBadgeClass(order.status)}>
                      {order.status.replace(/_/g, ' ')}
                    </span>
                  </div>
                </div>

                <div className="order-card-body">
                  <div className="order-items-snippet">
                    {order.items && order.items.length > 0 ? (
                      order.items.map((item, idx) => (
                        <span key={idx} className="order-item-tag">
                          {item.name || `Item #${item.menuItemId}`} &times; {item.quantity}
                        </span>
                      ))
                    ) : (
                      <span className="text-muted">Items not detailed</span>
                    )}
                  </div>
                </div>

                <div className="order-card-footer">
                  <div className="order-total-amount">
                    Total: <strong>₹{Number(order.totalAmount).toFixed(2)}</strong>
                  </div>
                  <Link to={`/orders/${order.id}`} className="btn btn-secondary btn-sm">
                    View Tracking & Details &rarr;
                  </Link>
                </div>
              </div>
            ))}
          </div>

          {/* Pagination Controls */}
          {ordersPage && ordersPage.totalPages > 1 && (
            <div className="pagination-bar">
              <button
                className="btn btn-secondary btn-sm"
                onClick={() => setPage((p) => Math.max(0, p - 1))}
                disabled={page === 0}
              >
                &larr; Previous
              </button>
              <span className="page-indicator">
                Page {page + 1} of {ordersPage.totalPages}
              </span>
              <button
                className="btn btn-secondary btn-sm"
                onClick={() => setPage((p) => Math.min(ordersPage.totalPages - 1, p + 1))}
                disabled={page >= ordersPage.totalPages - 1}
              >
                Next &rarr;
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
};
