import { apiClient } from './client';
import { Delivery, DeliveryStatus, DeliveryPartner } from '../types';

export const deliveryApi = {
  getDeliveryById: async (id: number): Promise<Delivery> => {
    const response = await apiClient.get<Delivery>(`/api/deliveries/${id}`);
    return response.data;
  },

  getDeliveryByOrderId: async (orderId: number): Promise<Delivery> => {
    const response = await apiClient.get<Delivery>(`/api/deliveries/order/${orderId}`);
    return response.data;
  },

  assignPartner: async (deliveryId: number): Promise<Delivery> => {
    const response = await apiClient.post<Delivery>(`/api/deliveries/${deliveryId}/assign`);
    return response.data;
  },

  updateDeliveryStatus: async (deliveryId: number, status: DeliveryStatus): Promise<Delivery> => {
    const response = await apiClient.patch<Delivery>(
      `/api/deliveries/${deliveryId}/status`,
      null,
      { params: { status } }
    );
    return response.data;
  },

  createPartner: async (name: string): Promise<DeliveryPartner> => {
    const response = await apiClient.post<DeliveryPartner>('/api/deliveries/partners', null, {
      params: { name },
    });
    return response.data;
  },
};
