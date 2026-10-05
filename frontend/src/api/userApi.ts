import { apiClient } from './client';
import { User, Address } from '../types';

export const userApi = {
  getProfile: async (): Promise<User> => {
    const response = await apiClient.get<User>('/api/users/me');
    return response.data;
  },

  updateProfile: async (payload: Partial<User>): Promise<User> => {
    const response = await apiClient.put<User>('/api/users/me', payload);
    return response.data;
  },

  getAddresses: async (): Promise<Address[]> => {
    const response = await apiClient.get<Address[]>('/api/users/addresses');
    return response.data;
  },

  addAddress: async (payload: Address): Promise<Address> => {
    const response = await apiClient.post<Address>('/api/users/addresses', payload);
    return response.data;
  },

  updateAddress: async (id: number, payload: Address): Promise<Address> => {
    const response = await apiClient.put<Address>(`/api/users/addresses/${id}`, payload);
    return response.data;
  },

  deleteAddress: async (id: number): Promise<void> => {
    await apiClient.delete(`/api/users/addresses/${id}`);
  },
};
