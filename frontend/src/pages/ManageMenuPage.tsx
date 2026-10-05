import React, { useState, useEffect, useCallback } from 'react';
import { useParams, Link } from 'react-router-dom';
import { restaurantApi } from '../api/restaurantApi';
import { Restaurant, MenuItem } from '../types';
import { LoadingSpinner } from '../components/LoadingSpinner';
import { ErrorMessage } from '../components/ErrorMessage';
import { getErrorMessage } from '../api/client';

export const ManageMenuPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const restaurantId = parseInt(id || '0', 10);

  const [restaurant, setRestaurant] = useState<Restaurant | null>(null);
  const [menu, setMenu] = useState<MenuItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Add Item State
  const [showAddForm, setShowAddForm] = useState(false);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [price, setPrice] = useState('');
  const [available, setAvailable] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchRestaurantAndMenu = useCallback(async () => {
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
  }, [restaurantId]);

  useEffect(() => {
    fetchRestaurantAndMenu();
  }, [fetchRestaurantAndMenu]);

  const handleAddDish = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setError(null);
    setSuccessMsg(null);

    try {
      const numPrice = parseFloat(price);
      if (isNaN(numPrice) || numPrice <= 0) {
        throw new Error('Price must be greater than zero.');
      }

      await restaurantApi.addMenuItem(restaurantId, {
        name: name.trim(),
        description: description.trim(),
        price: numPrice,
        available,
      });

      setSuccessMsg(`"${name}" added to menu successfully!`);
      setName('');
      setDescription('');
      setPrice('');
      setAvailable(true);
      setShowAddForm(false);
      fetchRestaurantAndMenu();
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggleAvailability = async (item: MenuItem) => {
    try {
      const updated = await restaurantApi.toggleMenuItemAvailability(restaurantId, item.id, !item.available);
      setMenu((prev) =>
        prev.map((m) => (m.id === item.id ? { ...m, available: updated.available } : m))
      );
      setSuccessMsg(`"${item.name}" is now ${updated.available ? 'AVAILABLE' : 'OUT OF STOCK'}.`);
    } catch (err) {
      setError(getErrorMessage(err));
    }
  };

  const handleDeleteItem = async (item: MenuItem) => {
    if (!window.confirm(`Are you sure you want to remove "${item.name}" from the menu?`)) return;
    try {
      await restaurantApi.deleteMenuItem(restaurantId, item.id);
      setMenu((prev) => prev.filter((m) => m.id !== item.id));
      setSuccessMsg(`"${item.name}" removed from menu.`);
    } catch (err) {
      setError(getErrorMessage(err));
    }
  };

  return (
    <div className="container page-content">
      <Link to="/owner/restaurants" className="back-link">
        &larr; Back to Owner Dashboard
      </Link>

      <div className="page-header-row">
        <div>
          <h1 className="page-title">
            Menu Management &bull; {restaurant?.name || `Restaurant #${restaurantId}`}
          </h1>
          <p className="page-subtitle">Add dishes, update prices, and control real-time dish availability</p>
        </div>
        <div style={{ display: 'flex', gap: '0.75rem' }}>
          <button onClick={fetchRestaurantAndMenu} className="btn btn-secondary btn-sm" disabled={isLoading}>
            🔄 Refresh
          </button>
          {!showAddForm && (
            <button onClick={() => setShowAddForm(true)} className="btn btn-primary btn-sm">
              + Add Menu Item
            </button>
          )}
        </div>
      </div>

      {successMsg && <div className="alert alert-success">{successMsg}</div>}
      {error && <ErrorMessage message={error} />}

      {/* Add Dish Form Card */}
      {showAddForm && (
        <div className="card" style={{ marginBottom: '2rem', border: '2px solid #ea580c' }}>
          <div className="card-header-flex">
            <h3>Add New Dish to Menu</h3>
            <button onClick={() => setShowAddForm(false)} className="btn-icon">✕</button>
          </div>

          <form onSubmit={handleAddDish} style={{ marginTop: '1rem' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1rem' }}>
              <div className="form-group">
                <label>Dish Name</label>
                <input
                  type="text"
                  required
                  className="form-input"
                  placeholder="e.g. Margherita Pizza"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  disabled={isSubmitting}
                />
              </div>

              <div className="form-group">
                <label>Price (₹)</label>
                <input
                  type="number"
                  step="0.01"
                  min="0.01"
                  required
                  className="form-input"
                  placeholder="e.g. 299.00"
                  value={price}
                  onChange={(e) => setPrice(e.target.value)}
                  disabled={isSubmitting}
                />
              </div>
            </div>

            <div className="form-group">
              <label>Description</label>
              <textarea
                className="form-input"
                rows={2}
                placeholder="e.g. Classic tomato sauce, fresh mozzarella, and aromatic basil leaves"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                disabled={isSubmitting}
              />
            </div>

            <div className="form-group">
              <label className="checkbox-label">
                <input
                  type="checkbox"
                  checked={available}
                  onChange={(e) => setAvailable(e.target.checked)}
                />
                Mark as In Stock & Available for Order
              </label>
            </div>

            <div style={{ display: 'flex', gap: '0.75rem', marginTop: '1rem' }}>
              <button type="submit" className="btn btn-primary" disabled={isSubmitting}>
                {isSubmitting ? 'Saving...' : 'Add Dish to Menu'}
              </button>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setShowAddForm(false)}
                disabled={isSubmitting}
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {isLoading && <LoadingSpinner message="Loading menu items..." />}

      {!isLoading && menu.length === 0 && (
        <div className="empty-state-box">
          <span className="empty-state-icon">📋</span>
          <h3>Menu is Empty</h3>
          <p>No dishes have been added to this restaurant yet.</p>
          <button onClick={() => setShowAddForm(true)} className="btn btn-primary" style={{ marginTop: '1rem' }}>
            + Add Your First Dish
          </button>
        </div>
      )}

      {/* Menu Table */}
      {!isLoading && menu.length > 0 && (
        <div className="card">
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Dish Name</th>
                  <th>Description</th>
                  <th>Price</th>
                  <th>Availability</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {menu.map((dish) => (
                  <tr key={dish.id}>
                    <td>#{dish.id}</td>
                    <td><strong>{dish.name}</strong></td>
                    <td className="text-muted" style={{ fontSize: '0.85rem' }}>
                      {dish.description || '-'}
                    </td>
                    <td><strong>₹{Number(dish.price).toFixed(2)}</strong></td>
                    <td>
                      <span className={`badge ${dish.available ? 'badge-green' : 'badge-gray'}`}>
                        {dish.available ? 'In Stock' : 'Out of Stock'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                        <button
                          onClick={() => handleToggleAvailability(dish)}
                          className={`btn btn-sm ${dish.available ? 'btn-secondary' : 'btn-primary'}`}
                          title="Toggle availability"
                        >
                          {dish.available ? 'Set Unavailable' : 'Set Available'}
                        </button>
                        <button
                          onClick={() => handleDeleteItem(dish)}
                          className="btn-icon"
                          title="Delete dish"
                        >
                          🗑️
                        </button>
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
