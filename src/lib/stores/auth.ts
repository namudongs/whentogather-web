import { writable, derived } from 'svelte/store';
import type { User, AuthError } from '@supabase/supabase-js';
import { supabase } from '$lib/supabaseClient';

// 기본 스토어
export const user = writable<User | null>(null);
export const isLoading = writable(false);
export const authError = writable<string | null>(null);

// 파생 스토어
export const isAuthenticated = derived(user, $user => $user !== null);

// 인증 관련 함수들
export const loginWithPassword = async (email: string, password: string) => {
  isLoading.set(true);
  authError.set(null);
  
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });
    if (error) throw error;
    user.set(data.user);
  } catch (err) {
    authError.set(err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.');
    throw err;
  } finally {
    isLoading.set(false);
  }
};

export const loginWithSocial = async (provider: 'google' | 'kakao' | 'apple') => {
  isLoading.set(true);
  authError.set(null);
  
  try {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider,
    });
    if (error) throw error;
  } catch (err) {
    authError.set(err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.');
    throw err;
  } finally {
    isLoading.set(false);
  }
};

export const signup = async (email: string, password: string) => {
  isLoading.set(true);
  authError.set(null);
  
  try {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
    });
    if (error) throw error;
    user.set(data.user);
  } catch (err) {
    authError.set(err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.');
    throw err;
  } finally {
    isLoading.set(false);
  }
};

export const logout = async () => {
  isLoading.set(true);
  authError.set(null);
  
  try {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
    user.set(null);
  } catch (err) {
    authError.set(err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.');
    throw err;
  } finally {
    isLoading.set(false);
  }
};

// 초기 사용자 세션 설정
supabase.auth.getSession().then(({ data: { session } }) => {
  user.set(session?.user ?? null);
});

// 인증 상태 변경 구독
supabase.auth.onAuthStateChange((_event, session) => {
  user.set(session?.user ?? null);
});
