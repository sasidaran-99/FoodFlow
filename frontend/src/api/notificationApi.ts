import { apiClient } from './client';
import { Notification } from '../types';

export const notificationApi = {
  getUserNotifications: async (userId: number): Promise<Notification[]> => {
    const response = await apiClient.get<Notification[]>(`/api/notifications/user/${userId}`);
    return response.data;
  },

  getOrderNotifications: async (orderId: number): Promise<Notification[]> => {
    const response = await apiClient.get<Notification[]>(`/api/notifications/order/${orderId}`);
    return response.data;
  },

  getNotificationById: async (id: number): Promise<Notification> => {
    const response = await apiClient.get<Notification>(`/api/notifications/${id}`);
    return response.data;
  },
};
