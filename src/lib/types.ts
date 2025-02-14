// 사용자 타입
export interface User {
  id: string;
  email: string;
  name?: string;
}

// 모임 타입
export interface Moim {
  id: string;
  title: string;
  description: string;
  creator_id: string;
  moim_url: string;
  created_at: string;
}

// 참여자 타입
export interface Participant {
  user_id: string;
  moim_id: string;
  role: 'creator' | 'participant';
  profile?: {
    id: string;
    name: string;
  };
}

// 만남 타입
export interface Mannam {
  id: string;
  moim_id: string;
  title: string;
  description?: string;
  created_at: string;
}

// 소셜 로그인 상태 타입
export interface SocialLoadingState {
  google: boolean;
  kakao: boolean;
  apple: boolean;
}
