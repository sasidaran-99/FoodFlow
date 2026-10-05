import React, { useState } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { getErrorMessage } from '../api/client';
import { ErrorMessage } from '../components/ErrorMessage';

export const LoginPage: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const queryParams = new URLSearchParams(location.search);
  const sessionExpired = queryParams.get('expired') === 'true';

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsSubmitting(true);

    try {
      await login({ email: email.trim(), password });
      
      // Determine destination based on user role or redirect location
      const savedUserStr = localStorage.getItem('foodflow_user');
      const savedUser = savedUserStr ? JSON.parse(savedUserStr) : null;
      
      const from = (location.state as { from?: { pathname: string } })?.from?.pathname;
      if (from && from !== '/login') {
        navigate(from, { replace: true });
      } else if (savedUser?.role === 'RESTAURANT_OWNER') {
        navigate('/owner/restaurants', { replace: true });
      } else if (savedUser?.role === 'DELIVERY_PARTNER') {
        navigate('/delivery', { replace: true });
      } else if (savedUser?.role === 'ADMIN') {
        navigate('/admin', { replace: true });
      } else {
        navigate('/', { replace: true });
      }
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="container page-content">
      <div className="auth-card">
        <div className="auth-header">
          <h2>Sign In to FoodFlow</h2>
          <p>Enter your credentials to access your account</p>
        </div>

        {sessionExpired && (
          <div className="alert alert-info" style={{ marginBottom: '1rem' }}>
            Your session has expired. Please sign in again.
          </div>
        )}

        {error && <ErrorMessage message={error} />}

        <form onSubmit={handleSubmit} className="auth-form">
          <div className="form-group">
            <label htmlFor="email">Email Address</label>
            <input
              id="email"
              type="email"
              required
              className="form-input"
              placeholder="e.g. user@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              disabled={isSubmitting}
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              required
              className="form-input"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={isSubmitting}
            />
          </div>

          <button
            type="submit"
            className="btn btn-primary btn-block"
            disabled={isSubmitting}
            style={{ marginTop: '0.5rem' }}
          >
            {isSubmitting ? 'Signing in...' : 'Sign In'}
          </button>
        </form>

        <div className="auth-footer">
          <p>
            Don't have an account? <Link to="/register">Create an account</Link>
          </p>
        </div>

        <div className="demo-credentials-box">
          <strong>Demo Tip:</strong>
          <p>You can create a new account with any role on the <Link to="/register">Register page</Link> (Customer, Restaurant Owner, Delivery Partner, or Admin).</p>
        </div>
      </div>
    </div>
  );
};
