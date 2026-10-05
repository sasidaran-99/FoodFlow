import { apiClient } from './client';
import { Order, CreateOrderRequest, SpringPage, OrderStatus } from '../types';

export const orderApi = {
  createOrder: async (payload: CreateOrderRequest): Promise<Order> => {
    const response = await apiClient.post<Order>('/api/orders', payload);
    return response.data;
  },

  getOrderById: async (id: number): Promise<Order> => {
    const response = await apiClient.get<Order>(`/api/orders/${id}`);
    return response.data;
  },

  getMyOrders: async (page = 0, size = 10): Promise<SpringPage<Order>> => {
    const response = await apiClient.get<SpringPage<Order>>('/api/orders', {
      params: { page, size },
    });
    return response.data;
  },

  updateOrderStatus: async (id: number, status: OrderStatus): Promise<Order> => {
    const response = await apiClient.patch<Order>(`/api/orders/${id}/status`, null, {
      params: { status },
    });
    return response.data;
  },
};
