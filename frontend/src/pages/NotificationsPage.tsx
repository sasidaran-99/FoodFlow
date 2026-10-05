import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { notificationApi } from '../api/notificationApi';
import { Notification } from '../types';
import { LoadingSpinner } from '../components/LoadingSpinner';
import { ErrorMessage } from '../components/ErrorMessage';
import { getErrorMessage } from '../api/client';

export const NotificationsPage: React.FC = () => {
  const { user } = useAuth();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchNotifications = async () => {
    if (!user?.id) return;
    setIsLoading(true);
    setError(null);
    try {
      const data = await notificationApi.getUserNotifications(user.id);
      setNotifications(Array.isArray(data) ? data : []);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchNotifications();
  }, [user?.id]);

  return (
    <div className="container page-content">
      <div className="page-header-row">
        <div>
          <h1 className="page-title">Notifications</h1>
          <p className="page-subtitle">Platform and order event updates broadcast via Kafka</p>
        </div>
        <button onClick={fetchNotifications} className="btn btn-secondary btn-sm" disabled={isLoading}>
          🔄 Refresh
        </button>
      </div>

      {isLoading && <LoadingSpinner message="Fetching your notifications..." />}
      {error && <ErrorMessage message={error} onRetry={fetchNotifications} />}

      {!isLoading && !error && notifications.length === 0 && (
        <div className="empty-state-box">
          <span className="empty-state-icon">🔔</span>
          <h3>No Notifications Yet</h3>
          <p>You have no new notifications. Activity on your orders will appear here automatically.</p>
        </div>
      )}

      {!isLoading && !error && notifications.length > 0 && (
        <div className="card">
          <div className="notifications-feed">
            {notifications.map((item) => (
              <div key={item.id} className="notification-row">
                <div className="notif-icon-col">
                  {item.type.includes('CONFIRMED') || item.type.includes('SUCCESS') ? '✅' : 'ℹ️'}
                </div>
                <div className="notif-content-col">
                  <div className="notif-header">
                    <span className="notif-type-tag">{item.type}</span>
                    <span className="text-muted notif-time">
                      {new Date(item.createdAt).toLocaleString()}
                    </span>
                  </div>
                  <p className="notif-message-text">{item.message}</p>
                  {item.orderId && (
                    <div style={{ marginTop: '0.25rem' }}>
                      <Link to={`/orders/${item.orderId}`} className="text-link" style={{ fontSize: '0.85rem' }}>
                        View Order #{item.orderId} &rarr;
                      </Link>
                    </div>
                  )}
                </div>
                <div className="notif-status-col">
                  <span className="badge badge-gray">{item.status}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
