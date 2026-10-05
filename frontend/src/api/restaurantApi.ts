import { apiClient } from './client';
import { Restaurant, MenuItem, SpringPage } from '../types';

export interface CreateRestaurantPayload {
  name: string;
  description: string;
  address: string;
}

export interface UpdateRestaurantPayload {
  name: string;
  description: string;
  address: string;
  isOpen?: boolean;
}

export interface MenuItemPayload {
  name: string;
  description?: string;
  price: number;
  available?: boolean;
}

export const restaurantApi = {
  getRestaurants: async (page = 0, size = 20): Promise<SpringPage<Restaurant>> => {
    const response = await apiClient.get<SpringPage<Restaurant>>('/api/restaurants', {
      params: { page, size },
    });
    return response.data;
  },

  getRestaurantById: async (id: number): Promise<Restaurant> => {
    const response = await apiClient.get<Restaurant>(`/api/restaurants/${id}`);
    return response.data;
  },

  createRestaurant: async (payload: CreateRestaurantPayload): Promise<Restaurant> => {
    const response = await apiClient.post<Restaurant>('/api/restaurants', payload);
    return response.data;
  },

  updateRestaurant: async (id: number, payload: UpdateRestaurantPayload): Promise<Restaurant> => {
    const response = await apiClient.put<Restaurant>(`/api/restaurants/${id}`, payload);
    return response.data;
  },

  toggleRestaurantStatus: async (id: number, isOpen: boolean): Promise<Restaurant> => {
    const response = await apiClient.patch<Restaurant>(`/api/restaurants/${id}/status`, null, {
      params: { isOpen },
    });
    return response.data;
  },

  getMenu: async (restaurantId: number): Promise<MenuItem[]> => {
    const response = await apiClient.get<MenuItem[]>(`/api/restaurants/${restaurantId}/menu`);
    return response.data;
  },

  addMenuItem: async (restaurantId: number, payload: MenuItemPayload): Promise<MenuItem> => {
    const response = await apiClient.post<MenuItem>(`/api/restaurants/${restaurantId}/menu`, payload);
    return response.data;
  },

  updateMenuItem: async (
    restaurantId: number,
    itemId: number,
    payload: MenuItemPayload
  ): Promise<MenuItem> => {
    const response = await apiClient.put<MenuItem>(
      `/api/restaurants/${restaurantId}/menu/${itemId}`,
      payload
    );
    return response.data;
  },

  deleteMenuItem: async (restaurantId: number, itemId: number): Promise<void> => {
    await apiClient.delete(`/api/restaurants/${restaurantId}/menu/${itemId}`);
  },

  toggleMenuItemAvailability: async (
    restaurantId: number,
    itemId: number,
    isAvailable: boolean
  ): Promise<MenuItem> => {
    const response = await apiClient.patch<MenuItem>(
      `/api/restaurants/${restaurantId}/menu/${itemId}/status`,
      null,
      { params: { isAvailable } }
    );
    return response.data;
  },
};
