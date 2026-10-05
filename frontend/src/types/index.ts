// Core Domain Types matching backend DTOs

export type Role = 'CUSTOMER' | 'RESTAURANT_OWNER' | 'DELIVERY_PARTNER' | 'ADMIN';

export interface User {
  id: number;
  name: string;
  email: string;
  phone: string;
  role: Role;
}

export interface AuthResponse {
  token: string;
  user: User;
}

export interface Address {
  id?: number;
  street: string;
  city: string;
  state: string;
  zipCode: string;
  country: string;
}

export interface Restaurant {
  id: number;
  ownerId?: number;
  name: string;
  description: string;
  address: string;
  open: boolean;
}

export interface MenuItem {
  id: number;
  restaurantId: number;
  name: string;
  description?: string;
  price: number;
  available: boolean;
}

export interface OrderItem {
  id?: number;
  menuItemId: number;
  name?: string;
  price?: number;
  quantity: number;
}

export type OrderStatus =
  | 'CREATED'
  | 'PAYMENT_PENDING'
  | 'CONFIRMED'
  | 'RESTAURANT_ACCEPTED'
  | 'PREPARING'
  | 'READY_FOR_PICKUP'
  | 'OUT_FOR_DELIVERY'
  | 'DELIVERED'
  | 'PAYMENT_FAILED'
  | 'REJECTED'
  | 'CANCELLED';

export interface Order {
  id: number;
  userId: number;
  restaurantId: number;
  status: OrderStatus;
  totalAmount: number;
  items: OrderItem[];
  createdAt: string;
  updatedAt?: string;
}

export interface CreateOrderRequest {
  restaurantId: number;
  items: {
    menuItemId: number;
    quantity: number;
  }[];
}

export type PaymentStatus = 'PENDING' | 'SUCCESS' | 'FAILED';

export interface Payment {
  id: number;
  orderId: number;
  userId: number;
  amount: number;
  status: PaymentStatus;
  referenceNumber: string;
  idempotencyKey?: string;
  createdAt: string;
}

export type NotificationType = 'ORDER_CONFIRMED' | 'PAYMENT_FAILED' | string;
export type NotificationStatus = 'SENT' | 'PENDING' | 'FAILED' | string;

export interface Notification {
  id: number;
  userId?: number;
  orderId?: number;
  type: NotificationType;
  message: string;
  status: NotificationStatus;
  createdAt: string;
  eventId?: string;
}

export type DeliveryStatus =
  | 'ASSIGNMENT_PENDING'
  | 'ASSIGNED'
  | 'PICKED_UP'
  | 'OUT_FOR_DELIVERY'
  | 'DELIVERED'
  | 'CANCELLED';

export interface Delivery {
  id: number;
  orderId: number;
  restaurantId: number;
  deliveryPartnerId?: number | null;
  status: DeliveryStatus;
}

export interface DeliveryPartner {
  id: number;
  name: string;
  status: 'AVAILABLE' | 'BUSY' | 'OFFLINE';
}

export interface SpringPage<T> {
  content: T[];
  totalElements: number;
  totalPages: number;
  size: number;
  number: number;
}

export interface CartItem {
  menuItemId: number;
  name: string;
  price: number;
  quantity: number;
}

export interface CartState {
  restaurantId: number | null;
  restaurantName: string | null;
  items: CartItem[];
}
