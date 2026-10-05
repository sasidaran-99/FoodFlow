import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { restaurantApi } from '../api/restaurantApi';
import { Restaurant } from '../types';
import { LoadingSpinner } from '../components/LoadingSpinner';
import { ErrorMessage } from '../components/ErrorMessage';
import { getErrorMessage } from '../api/client';
import { useAuth } from '../context/AuthContext';

export const RestaurantsPage: React.FC = () => {
  const { isAuthenticated } = useAuth();
  const [restaurants, setRestaurants] = useState<Restaurant[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterOpenOnly, setFilterOpenOnly] = useState(false);

  const fetchRestaurants = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const pageData = await restaurantApi.getRestaurants(0, 50);
      setRestaurants(pageData.content || []);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (isAuthenticated) {
      fetchRestaurants();
    } else {
      setIsLoading(false);
      setRestaurants([]);
    }
  }, [isAuthenticated]);

  const filteredRestaurants = restaurants.filter((r) => {
    const matchesSearch =
      r.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      r.description?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      r.address.toLowerCase().includes(searchTerm.toLowerCase());
    
    if (filterOpenOnly) {
      return matchesSearch && r.open;
    }
    return matchesSearch;
  });

  return (
    <div className="container page-content">
      {/* Header & Filter Controls */}
      <div className="page-header-row">
        <div>
          <h1 className="page-title">Explore Restaurants</h1>
          <p className="page-subtitle">Find and order food from local kitchens and restaurants</p>
        </div>
        <button onClick={fetchRestaurants} className="btn btn-secondary btn-sm" disabled={isLoading}>
          🔄 Refresh
        </button>
      </div>

      <div className="filters-bar">
        <input
          type="text"
          placeholder="Search by restaurant name, cuisine, or street..."
          className="form-input search-input"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
        />
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={filterOpenOnly}
            onChange={(e) => setFilterOpenOnly(e.target.checked)}
          />
          Show Open Restaurants Only
        </label>
      </div>

      {/* States */}
      {isLoading && <LoadingSpinner message="Loading restaurants from FoodFlow..." />}
      {error && <ErrorMessage message={error} onRetry={fetchRestaurants} />}

      {/* Unauthenticated Welcome Callout */}
      {!isAuthenticated && (
        <div className="card" style={{ marginBottom: '1.5rem', borderLeft: '4px solid #ea580c' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
            <div>
              <h3 style={{ fontSize: '1.1rem', marginBottom: '0.25rem' }}>Welcome to FoodFlow Distributed Ordering</h3>
              <p style={{ color: '#475569', fontSize: '0.9rem', margin: 0 }}>
                Please sign in or register to browse menus and place live distributed orders via Kafka and PostgreSQL.
              </p>
            </div>
            <div style={{ display: 'flex', gap: '0.75rem' }}>
              <Link to="/login" className="btn btn-secondary btn-sm">
                Sign In
              </Link>
              <Link to="/register" className="btn btn-primary btn-sm">
                Create Demo Account
              </Link>
            </div>
          </div>
        </div>
      )}

      {!isLoading && !error && isAuthenticated && filteredRestaurants.length === 0 && (
        <div className="empty-state-box">
          <span className="empty-state-icon">🍽️</span>
          <h3>No Restaurants Found</h3>
          <p>
            {searchTerm || filterOpenOnly
              ? 'No restaurants matched your search criteria. Try adjusting your filters.'
              : 'No restaurants are currently registered in the system.'}
          </p>
        </div>
      )}

      {/* Grid of Restaurants */}
      {!isLoading && !error && filteredRestaurants.length > 0 && (
        <div className="restaurant-grid">
          {filteredRestaurants.map((restaurant) => (
            <div key={restaurant.id} className="restaurant-card">
              <div className="restaurant-card-header">
                <h3 className="restaurant-name">{restaurant.name}</h3>
                <span className={`status-pill ${restaurant.open ? 'status-open' : 'status-closed'}`}>
                  {restaurant.open ? '● Open Now' : 'Closed'}
                </span>
              </div>
              <p className="restaurant-description">{restaurant.description || 'Delicious food & fast delivery.'}</p>
              <div className="restaurant-footer">
                <span className="restaurant-address" title={restaurant.address}>
                  📍 {restaurant.address}
                </span>
                <Link to={`/restaurants/${restaurant.id}`} className="btn btn-primary btn-sm">
                  View Menu →
                </Link>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
