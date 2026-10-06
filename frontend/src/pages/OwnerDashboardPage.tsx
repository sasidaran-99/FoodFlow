import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { restaurantApi } from '../api/restaurantApi';
import { Restaurant } from '../types';
import { LoadingSpinner } from '../components/LoadingSpinner';
import { ErrorMessage } from '../components/ErrorMessage';
import { getErrorMessage } from '../api/client';

export const OwnerDashboardPage: React.FC = () => {
  const { user } = useAuth();
  const [restaurants, setRestaurants] = useState<Restaurant[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Create Restaurant Form State
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [address, setAddress] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchRestaurants = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const pageData = await restaurantApi.getRestaurants(0, 100);
      const allRestaurants = pageData.content || [];
      // Filter by current ownerId if matched, or show all if ownerId is not attached
      const myRestaurants = user?.id
        ? allRestaurants.filter((r) => r.ownerId === user.id || !r.ownerId)
        : allRestaurants;
      setRestaurants(myRestaurants);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchRestaurants();
  }, [user?.id]);

  const handleCreateRestaurant = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setError(null);
    setSuccessMsg(null);

    try {
      await restaurantApi.createRestaurant({
        name: name.trim(),
        description: description.trim(),
        address: address.trim(),
      });

      setSuccessMsg(`Restaurant "${name}" registered successfully!`);
      setName('');
      setDescription('');
      setAddress('');
      setShowCreateModal(false);
      fetchRestaurants();
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggleStatus = async (restaurantId: number, currentOpen: boolean) => {
    try {
      const updated = await restaurantApi.toggleRestaurantStatus(restaurantId, !currentOpen);
      setRestaurants((prev) =>
        prev.map((r) => (r.id === restaurantId ? { ...r, open: updated.open } : r))
      );
      setSuccessMsg(`Restaurant is now ${updated.open ? 'OPEN' : 'CLOSED'}.`);
    } catch (err) {
      setError(getErrorMessage(err));
    }
  };

  return (
    <div className="container page-content">
      <div className="page-header-row">
        <div>
          <h1 className="page-title">Restaurant Owner Dashboard</h1>
          <p className="page-subtitle">Manage your dining venues, operating status, and food menus</p>
        </div>
        <div style={{ display: 'flex', gap: '0.75rem' }}>
          <button onClick={fetchRestaurants} className="btn btn-secondary btn-sm" disabled={isLoading}>
            🔄 Refresh
          </button>
          <button onClick={() => setShowCreateModal(true)} className="btn btn-primary btn-sm">
            + New Restaurant
          </button>
        </div>
      </div>

      {successMsg && <div className="alert alert-success">{successMsg}</div>}
      {error && <ErrorMessage message={error} />}

      {/* Modal / Card to Register New Restaurant */}
      {showCreateModal && (
        <div className="card" style={{ marginBottom: '2rem', border: '2px solid #ea580c' }}>
          <div className="card-header-flex">
            <h3>Register New Restaurant</h3>
            <button onClick={() => setShowCreateModal(false)} className="btn-icon">✕</button>
          </div>

          <form onSubmit={handleCreateRestaurant} style={{ marginTop: '1rem' }}>
            <div className="form-group">
              <label>Restaurant Name</label>
              <input
                type="text"
                required
                className="form-input"
                placeholder="e.g. Bella Italia Bistro"
                value={name}
                onChange={(e) => setName(e.target.value)}
                disabled={isSubmitting}
              />
            </div>

            <div className="form-group">
              <label>Description</label>
              <textarea
                required
                className="form-input"
                rows={2}
                placeholder="e.g. Authentic wood-fired pizza and handmade pasta"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                disabled={isSubmitting}
              />
            </div>

            <div className="form-group">
              <label>Street Address</label>
              <input
                type="text"
                required
                className="form-input"
                placeholder="e.g. 42 Foodie Lane, Sector 5"
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                disabled={isSubmitting}
              />
            </div>

            <div style={{ display: 'flex', gap: '0.75rem', marginTop: '1rem' }}>
              <button type="submit" className="btn btn-primary" disabled={isSubmitting}>
                {isSubmitting ? 'Registering...' : 'Register Restaurant'}
              </button>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setShowCreateModal(false)}
                disabled={isSubmitting}
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {isLoading && <LoadingSpinner message="Loading your restaurants..." />}

      {!isLoading && restaurants.length === 0 && (
        <div className="empty-state-box">
          <span className="empty-state-icon">🏪</span>
          <h3>No Restaurants Listed</h3>
          <p>You haven't created any restaurants under your owner account yet.</p>
          <button onClick={() => setShowCreateModal(true)} className="btn btn-primary" style={{ marginTop: '1rem' }}>
            + Create Your First Restaurant
          </button>
        </div>
      )}

      {/* Restaurant Management Table */}
      {!isLoading && restaurants.length > 0 && (
        <div className="card owner-restaurants-card">
          <div className="table-responsive">
            <table className="data-table owner-table">
              <thead>
                <tr>
                  <th style={{ width: '80px' }}>ID</th>
                  <th style={{ minWidth: '220px' }}>Restaurant</th>
                  <th style={{ minWidth: '240px', maxWidth: '320px' }}>Address</th>
                  <th style={{ width: '130px', textAlign: 'center' }}>Status</th>
                  <th style={{ minWidth: '220px', textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {restaurants.map((rest) => (
                  <tr key={rest.id}>
                    <td>
                      <span className="restaurant-id-badge">#{rest.id}</span>
                    </td>
                    <td>
                      <div className="restaurant-cell-info">
                        <strong className="restaurant-cell-name">{rest.name}</strong>
                        {rest.description && (
                          <p className="restaurant-cell-desc">
                            {rest.description}
                          </p>
                        )}
                      </div>
                    </td>
                    <td>
                      <div className="restaurant-cell-address">
                        {rest.address}
                      </div>
                    </td>
                    <td style={{ textAlign: 'center' }}>
                      <span className={`status-pill ${rest.open ? 'status-open' : 'status-closed'}`}>
                        {rest.open ? '● Open' : '● Closed'}
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <div className="table-actions-group">
                        <button
                          onClick={() => handleToggleStatus(rest.id, rest.open)}
                          className={`btn btn-sm ${rest.open ? 'btn-secondary' : 'btn-primary'}`}
                          title="Toggle Open/Close status"
                        >
                          {rest.open ? 'Close' : 'Open'}
                        </button>
                        <Link to={`/owner/restaurants/${rest.id}/menu`} className="btn btn-secondary btn-sm">
                          Manage Menu &rarr;
                        </Link>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};
