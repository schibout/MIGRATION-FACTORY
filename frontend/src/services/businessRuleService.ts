import api from './api';

export interface BusinessRule {
  id: number;
  business_object: string;
  rule_name: string;
  source_table?: string | null;
  source_field?: string | null;
  transformation?: string | null;
  target_table?: string | null;
  target_field?: string | null;
  description?: string | null;
  is_active: boolean;
  created_at?: string | null;
  updated_at?: string | null;
  created_by?: string | null;
  updated_by?: string | null;
}

export interface BusinessRulesResponse {
  rules: BusinessRule[];
  total: number;
}

export interface BusinessRuleFilters {
  business_object?: string;
  status?: string; // 'active' | 'inactive' | 'all'
  search?: string;
}

export interface ImportResult {
  message: string;
  created: number;
  updated: number;
  failed: number;
  errors: string[];
}

const businessRuleService = {
  getRules: async (filters: BusinessRuleFilters = {}): Promise<BusinessRulesResponse> => {
    const response = await api.get('/config/business-rules', {
      params: {
        business_object: filters.business_object || '',
        status: filters.status || 'all',
        search: filters.search || '',
      },
    });
    return response.data;
  },

  getObjects: async (): Promise<string[]> => {
    const response = await api.get('/config/business-rules/objects');
    return response.data.objects || [];
  },

  createRule: async (rule: Partial<BusinessRule>): Promise<BusinessRule> => {
    const response = await api.post('/config/business-rules', rule);
    return response.data;
  },

  updateRule: async (id: number, rule: Partial<BusinessRule>): Promise<BusinessRule> => {
    const response = await api.put(`/config/business-rules/${id}`, rule);
    return response.data;
  },

  deleteRule: async (id: number): Promise<void> => {
    await api.delete(`/config/business-rules/${id}`);
  },

  importFile: async (file: File): Promise<ImportResult> => {
    const formData = new FormData();
    formData.append('file', file);
    const response = await api.post('/config/business-rules/import', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return response.data;
  },

  downloadTemplate: async (): Promise<void> => {
    const response = await api.get('/config/business-rules/template', {
      responseType: 'blob',
    });
    const url = window.URL.createObjectURL(new Blob([response.data]));
    const a = document.createElement('a');
    a.href = url;
    a.download = 'modele_regles_gestion.xlsx';
    document.body.appendChild(a);
    a.click();
    window.URL.revokeObjectURL(url);
    document.body.removeChild(a);
  },
};

export default businessRuleService;
