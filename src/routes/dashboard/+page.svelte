<script lang="ts">
    import { onMount } from 'svelte';
    import { supabase } from '$lib/supabaseClient';
    import { goto } from '$app/navigation';
  
    let userEmail: string | null | undefined = null;
    let userName: string | null | undefined = null;
    let meetings: any[] = [];
    let errorMessage = '';
    let loading = true; // 전역 로딩 상태
  
    onMount(async () => {
      try {
        loading = true;
        // 1) 현재 로그인 세션 확인
        const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
        if (sessionError || !sessionData?.session) {
          loading = false;
          goto('/login');
          return;
        }
        const user = sessionData.session.user;
        userEmail = user.email;
  
        // 2) 프로필 정보 가져오기
        const { data: profileData } = await supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .single();
        if (profileData) {
          userName = profileData.name;
        }
    
        // 3) 모임(참여한 모임) 목록 조회 (RLS 정책에 따라 참여 중인 모임만 반환)
        const { data, error } = await supabase
          .from('moims')
          .select('*')
          .order('created_at', { ascending: false });
        if (error) {
          errorMessage = error.message;
        } else {
          meetings = data;
        }
      } catch (err: any) {
        errorMessage = err instanceof Error ? err.message : 'An unknown error occurred';
      } finally {
        loading = false;
      }
    });
  
    async function handleSignOut() {
      const { error } = await supabase.auth.signOut();
      if (!error) {
        goto('/login');
      }
    }
  
    function createMeeting() {
      goto('/moim/new');
    }
  
    // 모임 셀 클릭 시 모임 상세 페이지로 이동하는 함수
    function goToMeetingDetail(meetingId: string) {
      goto(`/moim/${meetingId}`);
    }
  </script>
  
  {#if loading}
    <!-- 전역 스피너 영역 -->
    <div class="global-spinner">
      <div class="spinner"></div>
    </div>
  {:else}
    <div class="dashboard-container">
      <header class="dashboard-header">
        <div class="header-content">
          <div class="user-info">
            <h1 class="font-extrabold">안녕하세요</h1>
            <p class="user-name font-bold">
              {userName || userEmail?.split('@')[0] || '사용자'}님
            </p>
          </div>
          <button class="sign-out-btn font-regular" on:click={handleSignOut}>
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
              <polyline points="16 17 21 12 16 7"></polyline>
              <line x1="21" y1="12" x2="9" y2="12"></line>
            </svg>
            로그아웃
          </button>
        </div>
      </header>
    
      <main class="dashboard-content">
        <section class="quick-actions">
          <button class="action-btn create-meeting font-bold" on:click={createMeeting}>
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="12" y1="5" x2="12" y2="19"></line>
              <line x1="5" y1="12" x2="19" y2="12"></line>
            </svg>
            새로운 모임 만들기
          </button>
        </section>
    
        <section class="meetings-section">
          <h2 class="font-bold">내 모임</h2>
          {#if errorMessage}
            <p class="error">{errorMessage}</p>
          {:else if meetings && meetings.length > 0}
            <ul class="meetings-list">
              {#each meetings as meeting}
                <li class="meeting-item">
                  <button type="button" class="meeting-button" on:click={() => goToMeetingDetail(meeting.id)}>
                    <h3 class="meeting-title">{meeting.title}</h3>
                    {#if meeting.description}
                      <p class="meeting-description">{meeting.description}</p>
                    {/if}
                    <small>생성일: {new Date(meeting.created_at).toLocaleDateString()}</small>
                  </button>
                </li>
              {/each}
            </ul>
          {:else}
            <div class="empty-state">
              <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="9" cy="7" r="4"></circle>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
              </svg>
              <p class="font-regular">아직 모임이 없습니다</p>
              <p class="subtitle font-light">새로운 모임을 만들어보세요</p>
            </div>
          {/if}
        </section>
      </main>
    </div>
  {/if}
    
  <style>
    :global(body) {
    margin: 0;
    background: white;
    color: #333;
  }
    
    /* 전역 스피너 */
    .global-spinner {
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background: #ffffff;
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
    }
    
    .spinner {
      width: 60px;
      height: 60px;
      border: 6px solid rgba(0, 0, 0, 0.1);
      border-top-color: #064B45;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }
    
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    
    /* 모임 컨테이너 (대시보드 스타일) */
    .dashboard-container {
      max-width: 800px;
      margin: 2rem auto;
      padding: 2rem;
      background: #fff;
      border-radius: 8px;
    }
    
    .dashboard-header {
      position: sticky;
      top: 0;
      background: white;
      padding: 1rem 0;
      border-bottom: 1px solid #f0f0f0;
      margin-bottom: 2rem;
      z-index: 100;
    }
    
    .header-content {
      max-width: 800px;
      margin: 0 auto;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    
    .user-info h1 {
      margin: 0;
      font-size: 1.5rem;
      font-weight: 600;
      color: #333;
    }
    
    .user-info .user-name {
      margin: 0.25rem 0 0;
      color: #666;
      font-size: 0.9rem;
    }
    
    .sign-out-btn {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.5rem 1rem;
      color: #666;
      background: none;
      border: none;
      font-size: 0.9rem;
      cursor: pointer;
      transition: color 0.15s ease;
    }
    
    .sign-out-btn:hover {
      color: #e53e3e;
    }
    
    .dashboard-content {
      display: flex;
      flex-direction: column;
      gap: 2rem;
    }
    
    .quick-actions {
      display: flex;
      gap: 1rem;
    }
    
    .action-btn {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.75rem 1.25rem;
      border: none;
      border-radius: 6px;
      font-size: 0.9rem;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.15s ease;
    }
    
    .create-meeting {
      background-color: #064B45;
      color: white;
    }
    
    .create-meeting:hover {
      background-color: #053c37;
    }
    
    .meetings-section {
      margin-top: 1rem;
    }
    
    .meetings-section h2 {
      font-size: 1.1rem;
      font-weight: 600;
      margin-bottom: 1rem;
      color: #333;
    }
    
    .meetings-list {
      list-style: none;
      padding: 0;
      margin: 0;
    }
    
    /* meeting-item 내부의 버튼로 교체하여 접근성 문제 해결 */
    .meeting-item {
      border: none;
      padding: 0;
      background: none;
    }
    
    .meeting-button {
      all: unset;
      display: block;
      width: 100%;
      cursor: pointer;
      padding: 1rem;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      transition: background-color 0.15s ease;
    }
    
    .meeting-button:hover {
      background-color: #f7fafc;
    }
    
    .meeting-title {
      margin: 0;
      font-size: 1.25rem;
      font-weight: 600;
    }
    
    .meeting-description {
      margin: 0.5rem 0;
      font-size: 0.9rem;
      color: #555;
    }
    
    .empty-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 3rem;
      background: #fafafa;
      border-radius: 8px;
      color: #666;
    }
    
    .empty-state svg {
      color: #ccc;
      margin-bottom: 1rem;
    }
    
    .empty-state p {
      margin: 0;
      font-size: 0.95rem;
    }
    
    .empty-state .subtitle {
      font-size: 0.85rem;
      color: #999;
      margin-top: 0.25rem;
    }
    
    @media (max-width: 640px) {
      .dashboard-container {
        padding: 0 1rem;
      }
      .header-content {
        padding: 0 1rem;
      }
      .user-info h1 {
        font-size: 1.25rem;
      }
      .empty-state {
        padding: 2rem;
      }
    }
  </style>