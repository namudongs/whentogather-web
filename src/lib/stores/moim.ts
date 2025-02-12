import { writable, derived } from 'svelte/store';
import type { PostgrestError } from '@supabase/supabase-js';
import { supabase } from '$lib/supabaseClient';
import { user } from './auth';

// 타입 정의
export interface Moim {
  id: string;
  title: string;
  description: string | null;
  creator_id: string;
  invite_code: string;
  created_at: string;
  updated_at: string;
  participant_count?: number;
}

export interface Mannam {
  id: string;
  moim_id: string;
  creator_id: string;
  title: string;
  description: string | null;
  start_date: string | null;
  end_date: string | null;
  duration: number;
  status: 'pending' | 'confirmed' | 'cancelled';
  created_at: string;
  updated_at: string;
}

export interface MannamResponse {
  id: string;
  mannam_id: string;
  user_id: string;
  status: 'available' | 'unavailable' | 'maybe';
  comment: string | null;
  created_at: string;
  updated_at: string;
}

// 기본 스토어
export const moims = writable<Moim[]>([]);
export const currentMoim = writable<Moim | null>(null);
export const currentMannam = writable<Mannam | null>(null);
export const mannamResponses = writable<MannamResponse[]>([]);
export const isLoading = writable(false);
export const error = writable<string | null>(null);

// 파생 스토어
export const myMoims = derived([moims, user], ([$moims, $user]) => {
  if (!$user) return [];
  return $moims;
});

export const participantCount = derived(mannamResponses, ($responses) => {
  const counts = {
    available: 0,
    unavailable: 0,
    maybe: 0
  };
  $responses.forEach(response => {
    counts[response.status]++;
  });
  return counts;
});

// 모임 관련 함수들

// 만남 관련 함수들
export const createMannam = async (moimId: string, title: string, description: string = '', startDate: string, endDate: string, duration: number) => {
  isLoading.set(true);
  error.set(null);

  let currentUser: any;
  user.subscribe(value => { currentUser = value; })();

  if (!currentUser) {
    const err = new Error('로그인이 필요합니다.');
    error.set(err.message);
    throw err;
  }

  try {
    const { data: mannam, error: err } = await supabase
      .from('mannams')
      .insert({
        moim_id: moimId,
        creator_id: currentUser.id,
        title,
        description,
        start_date: startDate,
        end_date: endDate,
        duration,
        status: 'pending'
      })
      .select()
      .single();

    if (err) throw err;
    return mannam;
  } catch (err: any) {
    error.set(err.message);
    throw err;
  } finally {
    isLoading.set(false);
  }
};

export const updateMannamStatus = async (mannamId: string, status: 'confirmed' | 'cancelled') => {
  isLoading.set(true);
  error.set(null);

  try {
    const { data: mannam, error: err } = await supabase
      .from('mannams')
      .update({ status })
      .eq('id', mannamId)
      .select()
      .single();

    if (err) throw err;
    return mannam;
  } catch (err: any) {
    error.set(err.message);
    throw err;
  } finally {
    isLoading.set(false);
  }
};

export const submitMannamResponse = async (mannamId: string, status: 'available' | 'unavailable' | 'maybe', comment: string = '') => {
  isLoading.set(true);
  error.set(null);

  let currentUser: any;
  user.subscribe(value => { currentUser = value; })();

  if (!currentUser) {
    const err = new Error('로그인이 필요합니다.');
    error.set(err.message);
    throw err;
  }

  try {
    const { data: response, error: err } = await supabase
      .from('mannam_responses')
      .upsert({
        mannam_id: mannamId,
        user_id: currentUser.id,
        status,
        comment
      })
      .select()
      .single();

    if (err) throw err;
    return response;
  } catch (err: any) {
    error.set(err.message);
    throw err;
  } finally {
    isLoading.set(false);
  }
};

// 모임 관련 함수들
export const joinMoimByInviteCode = async (inviteCode: string) => {
  isLoading.set(true);
  error.set(null);

  let currentUser: any;
  user.subscribe(value => { currentUser = value; })();

  if (!currentUser) {
    const err = new Error('로그인이 필요합니다.');
    error.set(err.message);
    throw err;
  }

  try {
    // 1. 모임 정보 가져오기
    const { data: moim, error: moimError } = await supabase
      .from('moims')
      .select('*')
      .eq('invite_code', inviteCode)
      .single();

    if (moimError) throw moimError;
    if (!moim) throw new Error('존재하지 않는 모임입니다.');

    // 2. 이미 참여중인지 확인
    const { data: existingParticipant, error: participantError } = await supabase
      .from('moim_participants')
      .select('*')
      .eq('moim_id', moim.id)
      .eq('user_id', currentUser.id)
      .maybeSingle();

    if (participantError) throw participantError;
    if (existingParticipant) return moim; // 이미 참여중이면 모임 정보만 반환

    // 3. 모임에 참여
    const { error: joinError } = await supabase
      .from('moim_participants')
      .insert({
        moim_id: moim.id,
        user_id: currentUser.id,
        role: 'participant'
      });

    if (joinError) throw joinError;
    return moim;

  } catch (err: any) {
    error.set(err.message);
    throw err;
  } finally {
    isLoading.set(false);
  }
};

export const loadMoims = async () => {
  try {
    isLoading.set(true);
    error.set(null);
    moims.set([]);

    let currentUser: any;
    const unsubscribe = user.subscribe(value => { currentUser = value; });
    unsubscribe();

    if (!currentUser) {
      error.set('로그인이 필요합니다.');
      isLoading.set(false);
      return;
    }

    // 내가 생성한 모임 가져오기
    const { data: createdMoims, error: err1 } = await supabase
      .from('moims')
      .select('*')
      .eq('creator_id', currentUser.id)
      .order('created_at', { ascending: false });

    if (err1) throw err1;

    // 내가 참여한 모임의 ID 목록 가져오기
    const { data: participations, error: err2 } = await supabase
      .from('moim_participants')
      .select('moim_id')
      .eq('user_id', currentUser.id);

    if (err2) throw err2;

    // 참여한 모임 정보 가져오기
    const participatedMoimIds = participations?.map(p => p.moim_id) || [];
    
    const { data: participatedMoims, error: err3 } = participatedMoimIds.length > 0 
      ? await supabase
          .from('moims')
          .select('*')
          .in('id', participatedMoimIds)
          .order('created_at', { ascending: false })
      : { data: [], error: null };

    if (err3) throw err3;

    // 결과 합치기
    const combinedMoims = [
      ...(createdMoims || []),
      ...(participatedMoims || [])
    ];

    // 모임별 참가자 수 가져오기
    const participantCounts = new Map();
    
    for (const moim of combinedMoims) {
      const { count } = await supabase
        .from('moim_participants')
        .select('*', { count: 'exact', head: true })
        .eq('moim_id', moim.id);
      
      participantCounts.set(moim.id, count || 0);
    }

    // 모임 정보 변환
    const transformedData = combinedMoims.map(moim => ({
      ...moim,
      participant_count: participantCounts.get(moim.id) || 0
    }));
    
    // 중복 제거
    const uniqueMoims = Array.from(new Map(transformedData.map(m => [m.id, m])).values());
    
    moims.set(uniqueMoims);
  } catch (err) {
    error.set(err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.');
    throw err;
  } finally {
    isLoading.set(false);
  }
};

export const loadMoimByInviteCode = async (inviteCode: string) => {
  isLoading.set(true);
  error.set(null);

  try {
    const { data, error: err } = await supabase
      .from('moims')
      .select('*, moim_participants(*)')
      .eq('invite_code', inviteCode)
      .single();

    if (err) throw err;
    currentMoim.set(data);
    return data;
  } catch (err) {
    error.set(err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.');
    currentMoim.set(null);
    throw err;
  } finally {
    isLoading.set(false);
  }
};

export const createMoim = async (title: string, description: string = ''): Promise<{ id: string, invite_code: string }> => {
  isLoading.set(true);
  error.set(null);

  let currentUser: any;
  user.subscribe(value => { currentUser = value; })();

  if (!currentUser) {
    const err = new Error('로그인이 필요합니다.');
    error.set(err.message);
    throw err;
  }

  try {
    // 8자리 랜덤 초대 코드 생성 및 중복 확인
    let inviteCode = Math.random().toString(36).substring(2, 10);
    let isUnique = false;
    
    while (!isUnique) {
      inviteCode = Math.random().toString(36).substring(2, 10);
      const { data: existingMoim } = await supabase
        .from('moims')
        .select('id')
        .eq('invite_code', inviteCode)
        .single();
      
      if (!existingMoim) {
        isUnique = true;
      }
    }

    const { data, error: err } = await supabase
      .from('moims')
      .insert({
        title,
        description,
        invite_code: inviteCode,
        creator_id: currentUser.id
      })
      .select()
      .single();

    if (err) throw err;
    
    // 모임 생성자를 참여자로 자동 추가
    const { error: participantErr } = await supabase
      .from('moim_participants')
      .insert({
        moim_id: data.id,
        user_id: currentUser.id,
        role: 'creator'
      });

    if (participantErr) throw participantErr;
    
    // 새로운 모임을 스토어에 추가
    moims.update(m => [data, ...m]);
    return data;
  } catch (err) {
    error.set(err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.');
    throw err;
  } finally {
    isLoading.set(false);
  }
};

export const joinMoim = async (inviteCode: string) => {
  isLoading.set(true);
  error.set(null);

  try {
    const moim = await loadMoimByInviteCode(inviteCode);
    
    const { error: err } = await supabase
      .from('moim_participants')
      .insert({
        moim_id: moim.id,
        role: 'participant'
      });

    if (err) throw err;
    
    return moim;
  } catch (err) {
    error.set(err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.');
    throw err;
  } finally {
    isLoading.set(false);
  }
};
