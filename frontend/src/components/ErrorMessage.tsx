import React from 'react';

interface ErrorMessageProps {
  message: string;
  onRetry?: () => void;
}

export const ErrorMessage: React.FC<ErrorMessageProps> = ({ message, onRetry }) => {
  return (
    <div className="alert alert-error">
      <div className="alert-content">
        <span className="alert-icon">⚠️</span>
        <span>{message}</span>
      </div>
      {onRetry && (
        <button onClick={onRetry} className="btn btn-secondary btn-sm" style={{ marginTop: '0.5rem' }}>
          Retry
        </button>
      )}
    </div>
  );
};
