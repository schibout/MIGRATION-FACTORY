import api from './api';

export type SettingType = 'text' | 'password' | 'number' | 'boolean' | 'url';

export interface SettingItem {
  key: string;
  label: string;
  type: SettingType;
  secret: boolean;
  value: string;
  has_value: boolean;
  requires_restart: boolean;
}

export interface SettingCategory {
  key: string;
  label: string;
  items: SettingItem[];
}

export interface TestResult {
  success: boolean;
  message?: string;
  error?: string;
  details?: string;
}

export type TestTarget = 'database' | 'sap' | 'sharepoint' | 'smtp' | 'ai';

const settingsService = {
  async getAll(): Promise<SettingCategory[]> {
    const res = await api.get('/settings');
    return res.data?.data || [];
  },

  async update(values: Record<string, string>): Promise<{ updated: string[]; ignored: string[]; message: string }> {
    const res = await api.put('/settings', { values });
    return res.data;
  },

  async test(target: TestTarget): Promise<TestResult> {
    const res = await api.post(`/settings/test/${target}`);
    return res.data;
  },
};

export default settingsService;
