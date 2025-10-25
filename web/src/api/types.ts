export interface LoginResponse {
  access_token: string;
  token_type: string;
  user_id: number;
  has_pin: boolean;
}

export interface AdminUserUsageItem {
  clothing_id: number;
  name: string;
  usage_count: number;
}

export interface AdminUserSummary {
  id: number;
  name: string;
  email: string;
  phone?: string | null;
  total_clothes: number;
  total_clothes_images: number;
  total_mannequins: number;
  total_outfits: number;
  total_wear_events: number;
  wear_events_last_30_days: number;
  new_clothes_last_30_days: number;
  last_wear_at?: string | null;
  last_mannequin_at?: string | null;
  top_worn_items: AdminUserUsageItem[];
}

export interface CreateUserPayload {
  name: string;
  email: string;
  password: string;
  phone?: string;
  gender?: string;
  theme_preference?: string;
  pin_code?: string;
  language_preference?: string;
}
