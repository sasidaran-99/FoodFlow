import { apiClient } from './client';
import { Payment } from '../types';

export const paymentApi = {
  getPaymentById: async (id: number): Promise<Payment> => {
    const response = await apiClient.get<Payment>(`/api/payments/${id}`);
    return response.data;
  },

  getPaymentByOrderId: async (orderId: number): Promise<Payment> => {
    const response = await apiClient.get<Payment>(`/api/payments/order/${orderId}`);
    return response.data;
  },
};
