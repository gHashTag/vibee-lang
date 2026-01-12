import { create } from 'zustand';

interface Message {
  role: 'user' | 'agent' | 'system';
  content: string;
  timestamp: Date;
}

interface ChatStore {
  messages: Message[];
  isLoading: boolean;
  addMessage: (message: Message) => void;
  clearMessages: () => void;
  setLoading: (loading: boolean) => void;
}

export const useChatStore = create<ChatStore>((set) => ({
  messages: [],
  isLoading: false,
  
  addMessage: (message) => {
    set((state) => ({
      messages: [...state.messages, message],
      isLoading: message.role === 'user',
    }));
    
    // Auto-set loading to false after agent responds
    if (message.role === 'agent') {
      set({ isLoading: false });
    }
  },
  
  clearMessages: () => set({ messages: [], isLoading: false }),
  
  setLoading: (loading) => set({ isLoading: loading }),
}));
