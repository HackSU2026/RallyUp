export interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  photoURL?: string;
  rating: number;
}

export interface CreateEventParams {
  title?: string;
  event_type: "practice" | "match";
  variant: "singles" | "doubles";
  location: string;
  start_at: string; // ISO 8601
  end_at: string; // ISO 8601
}

export interface ToolResult {
  success: boolean;
  event_id?: string;
  summary?: string;
  error?: string;
}

export interface ChatRequest {
  message: string;
  history?: Array<{
    role: string;
    parts: Array<{ text: string }>;
  }>;
}

export interface ChatResponse {
  reply: string;
  created_event_id?: string | null;
}
