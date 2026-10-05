import React, { createContext, useContext, useState, useEffect } from 'react';
import { CartItem, MenuItem } from '../types';

interface CartContextType {
  restaurantId: number | null;
  restaurantName: string | null;
  items: CartItem[];
  totalAmount: number;
  totalItems: number;
  addItem: (restaurantId: number, restaurantName: string, item: MenuItem) => boolean;
  updateQuantity: (menuItemId: number, quantity: number) => void;
  removeItem: (menuItemId: number) => void;
  clearCart: () => void;
}

const CartContext = createContext<CartContextType | undefined>(undefined);

export const CartProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [restaurantId, setRestaurantId] = useState<number | null>(() => {
    const saved = localStorage.getItem('foodflow_cart_restaurant_id');
    return saved ? parseInt(saved, 10) : null;
  });

  const [restaurantName, setRestaurantName] = useState<string | null>(() => {
    return localStorage.getItem('foodflow_cart_restaurant_name');
  });

  const [items, setItems] = useState<CartItem[]>(() => {
    const saved = localStorage.getItem('foodflow_cart_items');
    return saved ? JSON.parse(saved) : [];
  });

  useEffect(() => {
    if (restaurantId !== null) {
      localStorage.setItem('foodflow_cart_restaurant_id', restaurantId.toString());
    } else {
      localStorage.removeItem('foodflow_cart_restaurant_id');
    }

    if (restaurantName !== null) {
      localStorage.setItem('foodflow_cart_restaurant_name', restaurantName);
    } else {
      localStorage.removeItem('foodflow_cart_restaurant_name');
    }

    localStorage.setItem('foodflow_cart_items', JSON.stringify(items));
  }, [restaurantId, restaurantName, items]);

  const addItem = (restId: number, restName: string, item: MenuItem): boolean => {
    // If cart has items from a different restaurant
    if (restaurantId !== null && restaurantId !== restId && items.length > 0) {
      const confirmClear = window.confirm(
        `Your cart contains items from "${restaurantName}". Do you want to clear your cart and start a new order from "${restName}"?`
      );
      if (!confirmClear) {
        return false;
      }
      setItems([{ menuItemId: item.id, name: item.name, price: item.price, quantity: 1 }]);
      setRestaurantId(restId);
      setRestaurantName(restName);
      return true;
    }

    setRestaurantId(restId);
    setRestaurantName(restName);

    setItems((prevItems) => {
      const existing = prevItems.find((i) => i.menuItemId === item.id);
      if (existing) {
        return prevItems.map((i) =>
          i.menuItemId === item.id ? { ...i, quantity: i.quantity + 1 } : i
        );
      }
      return [...prevItems, { menuItemId: item.id, name: item.name, price: item.price, quantity: 1 }];
    });

    return true;
  };

  const updateQuantity = (menuItemId: number, quantity: number) => {
    if (quantity <= 0) {
      removeItem(menuItemId);
      return;
    }

    setItems((prevItems) =>
      prevItems.map((i) => (i.menuItemId === menuItemId ? { ...i, quantity } : i))
    );
  };

  const removeItem = (menuItemId: number) => {
    setItems((prevItems) => {
      const remaining = prevItems.filter((i) => i.menuItemId !== menuItemId);
      if (remaining.length === 0) {
        setRestaurantId(null);
        setRestaurantName(null);
      }
      return remaining;
    });
  };

  const clearCart = () => {
    setItems([]);
    setRestaurantId(null);
    setRestaurantName(null);
    localStorage.removeItem('foodflow_cart_restaurant_id');
    localStorage.removeItem('foodflow_cart_restaurant_name');
    localStorage.removeItem('foodflow_cart_items');
  };

  const totalAmount = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const totalItems = items.reduce((sum, item) => sum + item.quantity, 0);

  return (
    <CartContext.Provider
      value={{
        restaurantId,
        restaurantName,
        items,
        totalAmount,
        totalItems,
        addItem,
        updateQuantity,
        removeItem,
        clearCart,
      }}
    >
      {children}
    </CartContext.Provider>
  );
};

export const useCart = (): CartContextType => {
  const context = useContext(CartContext);
  if (!context) {
    throw new Error('useCart must be used within a CartProvider');
  }
  return context;
};
