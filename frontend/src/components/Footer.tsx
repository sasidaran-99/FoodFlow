import React from 'react';

export const Footer: React.FC = () => {
  return (
    <footer className="footer-wrapper">
      <div className="container footer-content">
        <div className="footer-brand">
          <strong>FoodFlow</strong> &mdash; Distributed Food Delivery Platform
        </div>
        <div className="footer-details">
          <span>Spring Boot Microservices &bull; PostgreSQL &bull; Kafka &bull; Redis &bull; API Gateway (:8080)</span>
        </div>
      </div>
    </footer>
  );
};
