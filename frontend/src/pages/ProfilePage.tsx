import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { userApi } from '../api/userApi';
import { Address } from '../types';
import { LoadingSpinner } from '../components/LoadingSpinner';
import { ErrorMessage } from '../components/ErrorMessage';
import { getErrorMessage } from '../api/client';

export const ProfilePage: React.FC = () => {
  const { user } = useAuth();

  const [addresses, setAddresses] = useState<Address[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // New Address Form State
  const [showAddForm, setShowAddForm] = useState(false);
  const [newStreet, setNewStreet] = useState('');
  const [newCity, setNewCity] = useState('');
  const [newState, setNewState] = useState('');
  const [newZipCode, setNewZipCode] = useState('');
  const [newCountry, setNewCountry] = useState('India');
  const [isSubmittingAddress, setIsSubmittingAddress] = useState(false);

  const fetchAddresses = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await userApi.getAddresses();
      setAddresses(data);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchAddresses();
  }, []);

  const handleAddAddress = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmittingAddress(true);
    setError(null);
    setSuccessMsg(null);

    try {
      await userApi.addAddress({
        street: newStreet.trim(),
        city: newCity.trim(),
        state: newState.trim(),
        zipCode: newZipCode.trim(),
        country: newCountry.trim(),
      });

      setSuccessMsg('Address added successfully!');
      setNewStreet('');
      setNewCity('');
      setNewState('');
      setNewZipCode('');
      setShowAddForm(false);
      fetchAddresses();
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsSubmittingAddress(false);
    }
  };

  const handleDeleteAddress = async (id: number) => {
    if (!window.confirm('Are you sure you want to remove this address?')) return;
    try {
      await userApi.deleteAddress(id);
      setAddresses((prev) => prev.filter((a) => a.id !== id));
      setSuccessMsg('Address removed.');
    } catch (err) {
      setError(getErrorMessage(err));
    }
  };

  return (
    <div className="container page-content">
      <div className="page-header-row">
        <div>
          <h1 className="page-title">User Profile</h1>
          <p className="page-subtitle">Manage your personal information and delivery addresses</p>
        </div>
      </div>

      {successMsg && (
        <div className="alert alert-success" style={{ marginBottom: '1rem' }}>
          {successMsg}
        </div>
      )}
      {error && <ErrorMessage message={error} />}

      <div className="profile-grid">
        {/* Personal Info Card */}
        <div className="card">
          <h3>Account Information</h3>
          <div className="info-list" style={{ marginTop: '1rem' }}>
            <div className="info-item">
              <span className="info-label">Full Name:</span>
              <span className="info-value"><strong>{user?.name}</strong></span>
            </div>
            <div className="info-item">
              <span className="info-label">Email Address:</span>
              <span className="info-value">{user?.email}</span>
            </div>
            <div className="info-item">
              <span className="info-label">Phone Number:</span>
              <span className="info-value">{user?.phone}</span>
            </div>
            <div className="info-item">
              <span className="info-label">Account Role:</span>
              <span className="info-value">
                <span className={`role-pill role-${user?.role?.toLowerCase()}`}>
                  {user?.role}
                </span>
              </span>
            </div>
            <div className="info-item">
              <span className="info-label">User ID:</span>
              <span className="info-value">#{user?.id}</span>
            </div>
          </div>
        </div>

        {/* Saved Addresses Card */}
        <div className="card">
          <div className="card-header-flex">
            <h3>Saved Addresses</h3>
            {!showAddForm && (
              <button onClick={() => setShowAddForm(true)} className="btn btn-secondary btn-sm">
                + Add Address
              </button>
            )}
          </div>

          {showAddForm && (
            <form onSubmit={handleAddAddress} className="add-address-form" style={{ marginTop: '1rem' }}>
              <h4 style={{ marginBottom: '0.75rem' }}>Add New Delivery Address</h4>
              
              <div className="form-group">
                <label>Street Address</label>
                <input
                  type="text"
                  required
                  className="form-input"
                  placeholder="e.g. 123 Tech Park Road, Flat 4B"
                  value={newStreet}
                  onChange={(e) => setNewStreet(e.target.value)}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div className="form-group">
                  <label>City</label>
                  <input
                    type="text"
                    required
                    className="form-input"
                    placeholder="e.g. Bangalore"
                    value={newCity}
                    onChange={(e) => setNewCity(e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label>State</label>
                  <input
                    type="text"
                    required
                    className="form-input"
                    placeholder="e.g. Karnataka"
                    value={newState}
                    onChange={(e) => setNewState(e.target.value)}
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div className="form-group">
                  <label>Postal / Zip Code</label>
                  <input
                    type="text"
                    required
                    className="form-input"
                    placeholder="e.g. 560001"
                    value={newZipCode}
                    onChange={(e) => setNewZipCode(e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label>Country</label>
                  <input
                    type="text"
                    required
                    className="form-input"
                    value={newCountry}
                    onChange={(e) => setNewCountry(e.target.value)}
                  />
                </div>
              </div>

              <div style={{ display: 'flex', gap: '0.5rem', marginTop: '1rem' }}>
                <button type="submit" className="btn btn-primary btn-sm" disabled={isSubmittingAddress}>
                  {isSubmittingAddress ? 'Saving...' : 'Save Address'}
                </button>
                <button
                  type="button"
                  className="btn btn-secondary btn-sm"
                  onClick={() => setShowAddForm(false)}
                >
                  Cancel
                </button>
              </div>
            </form>
          )}

          {isLoading ? (
            <LoadingSpinner message="Loading addresses..." />
          ) : addresses.length === 0 ? (
            <p className="text-muted" style={{ marginTop: '1rem', fontStyle: 'italic' }}>
              No addresses saved yet. Click "+ Add Address" to add your delivery location.
            </p>
          ) : (
            <div className="addresses-list" style={{ marginTop: '1rem' }}>
              {addresses.map((addr) => (
                <div key={addr.id} className="address-card">
                  <div>
                    <p style={{ margin: 0, fontWeight: 500 }}>{addr.street}</p>
                    <p style={{ margin: 0, fontSize: '0.85rem', color: '#4b5563' }}>
                      {addr.city}, {addr.state} - {addr.zipCode}, {addr.country}
                    </p>
                  </div>
                  {addr.id && (
                    <button
                      onClick={() => handleDeleteAddress(addr.id!)}
                      className="btn-icon"
                      title="Delete address"
                    >
                      🗑️
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
