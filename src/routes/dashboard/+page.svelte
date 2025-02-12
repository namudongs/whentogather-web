<script lang="ts">
    import { onMount } from 'svelte';
    import { goto } from '$app/navigation';
    import { fade, fly, slide } from 'svelte/transition';
    import Logo from '$lib/components/Logo.svelte';
    import Spinner from '$lib/components/Spinner.svelte';
    import ErrorMessage from '$lib/components/ErrorMessage.svelte';
    import BottomSheet from '$lib/components/BottomSheet.svelte';
    import Button from '$lib/components/Button.svelte';
    import { user, logout, isLoading as authLoading } from '$lib/stores/auth';
    import { moims, isLoading, error as moimError, createMoim, loadMoims } from '$lib/stores/moim';

    // 모달 상태
    let isModalOpen = false;
    let isCreating = false;
    let title = '';
    let description = '';
    
    let unsubscribe: () => void;

    onMount(() => {
        // 사용자 상태 구독
        unsubscribe = user.subscribe(async ($user) => {
            if ($user) {
                try {
                    await loadMoims();
                } catch (error) {
                    console.error('Failed to load moims:', error);
                }
            }
        });

        return () => {
            if (unsubscribe) unsubscribe();
        };
    });

    async function handleSignOut() {
        await logout();
        goto('/login');
    }
    
    function openCreateModal() {
      isModalOpen = true;
      title = '';
      description = '';
      $moimError = '';
    }

    function closeModal() {
      isModalOpen = false;
    }

    async function handleCreateMoim() {
        if (!title.trim()) {
            return;
        }

        try {
            isCreating = true;
            const newMoim = await createMoim(title, description);
            isCreating = false;
            closeModal();
            // 생성된 모임 페이지로 이동
            goto(`/moim/${newMoim.invite_code}`);
        } catch (error) {
            isCreating = false;
            // 에러는 이미 moimError 스토어에 저장됨
        }
    }
    
    // 모임 셀 클릭 시, 모임 상세 페이지로 이동하는 함수 (UUID 대신 초대 코드 사용)
    function goToMeetingDetail(meeting: any) {
      // 모임 데이터에 invite_code가 있다고 가정합니다.
      goto(`/moim/${meeting.invite_code}`);
    }
  </script>
    
  {#if $isLoading || $authLoading}
    <div class="global-spinner">
      <Spinner size="large" />
    </div>
  {:else}
    <div class="dashboard-container" in:fly={{y: 50, duration: 400, delay: 200}} out:fade={{duration: 200}}>
      <div class="dashboard-content-wrapper">
        <header class="dashboard-header">
        <div class="header-content">
          <div class="user-info">
            <h1 class="font-extrabold">안녕하세요</h1>
            <p class="user-name font-bold">
              {$user?.user_metadata?.name || $user?.email?.split('@')[0] || ''}님
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
          <Button variant="primary" on:click={openCreateModal}>
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="12" y1="5" x2="12" y2="19"></line>
              <line x1="5" y1="12" x2="19" y2="12"></line>
            </svg>
            새로운 모임 만들기
          </Button>
        </section>
      
        <section class="meetings-section">
          <h2 class="font-bold">내 모임</h2>
          {#if $moimError}
            <ErrorMessage message={$moimError} />
          {:else if $moims && $moims.length > 0}
            <ul class="meetings-list">
              {#each $moims as meeting, i}
                <li class="meeting-item" in:slide={{delay: i * 100, duration: 300}}>
                  <button type="button" class="meeting-button" on:click={() => goToMeetingDetail(meeting)}>
                    <div class="meeting-status-bar"></div>
                    <div class="meeting-content">
                      <h3 class="meeting-title">{meeting.title}</h3>
                      {#if meeting.description}
                        <p class="meeting-description">{meeting.description}</p>
                      {/if}
                      <div class="meeting-meta">
                        <span class="meta-item">
                          <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="12" cy="12" r="10"></circle>
                            <polyline points="12 6 12 12 16 14"></polyline>
                          </svg>
                          {new Date(meeting.created_at).toLocaleDateString()}
                        </span>
                        {#if meeting.participant_count}
                          <span class="meta-item">
                            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                              <circle cx="9" cy="7" r="4"></circle>
                              <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                              <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
                            </svg>
                            {meeting.participant_count}명
                          </span>
                        {/if}
                      </div>
                    </div>
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
    </div>
  {/if}

  <BottomSheet show={isModalOpen} onClose={closeModal} title="새로운 모임 만들기">
    <form on:submit|preventDefault={handleCreateMoim} class="create-form">
      {#if $moimError}
        <ErrorMessage message={$moimError} />
      {/if}
      <div class="form-group">
        <label for="title">모임 제목</label>
        <input
          id="title"
          type="text"
          bind:value={title}
          placeholder="예: 동아리 회의"
          class="form-input"
        />
      </div>
      <div class="form-group">
        <label for="description">모임 설명 (선택)</label>
        <textarea
          id="description"
          bind:value={description}
          placeholder="모임에 대한 간단한 소개 또는 설명을 작성해 주세요."
          class="form-input"
          rows="4"
        ></textarea>
      </div>
      <div class="form-actions">
        <Button
          variant="outline"
          on:click={closeModal}
          flex={1}
        >취소</Button>
        <Button
          variant="primary"
          type="submit"
          disabled={isCreating}
          loading={isCreating}
          flex={2}
        >모임 생성하기</Button>
      </div>
    </form>
  </BottomSheet>
    
  <style>
    :global(body) {
      margin: 0;
      background: white;
      font-family: 'Helvetica Neue', Arial, sans-serif;
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
    
    .dashboard-container {
      width: 100%;
      min-height: 100vh;
      background: white;
    }

    .dashboard-content-wrapper {
      max-width: 500px;
      margin: 0 auto;
      padding: 1rem;
    }
    
    .dashboard-header {
      position: sticky;
      top: 0;
      background: white;
      padding: 0.75rem 0;
      border-bottom: 1px solid #f0f0f0;
      margin-bottom: 1rem;
      z-index: 100;
    }
    
    .header-content {
      max-width: 500px;
      margin: 0 auto;
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 0 0.5rem;
    }
    
    .user-info h1 {
      margin: 0;
      font-size: 1.25rem;
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
      gap: 1.5rem;
    }
    
    .quick-actions {
      display: grid;
      gap: 1rem;
    }
    
    .meetings-section {
      margin-top: 1rem;
    }
    
    .meetings-section h2 {
      font-size: 1.25rem;
      font-weight: 600;
      margin-bottom: 1rem;
      color: #333;
    }
    
    .meetings-list {
      list-style: none;
      margin: 0;
      padding: 0;
    }
    
    .meeting-item {
      border: none;
      padding-bottom: 0.8rem;
      background: none;
    }
    
    .meeting-button {
      all: unset;
      display: block;
      width: 100%;
      box-sizing: border-box;
      cursor: pointer;
      border-radius: 14px;
      transition: all 0.2s ease;
      margin-bottom: 1rem;
      position: relative;
      overflow: hidden;
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
    }
    
    .meeting-button:hover {
      transform: translateY(-2px);
      border-color: #cbd5e1;
      background: white;
      box-shadow: 0 8px 16px rgba(0, 0, 0, 0.08);
    }

    .meeting-status-bar {
      position: absolute;
      top: 0;
      left: 0;
      width: 4px;
      height: 100%;
      background: linear-gradient(to bottom, #064B45, #0a786e);
      opacity: 0.9;
    }
    
    .meeting-status-bar::after {
      content: '';
      position: absolute;
      top: -50%;
      left: -50%;
      width: 200%;
      height: 200%;
      background: inherit;
      filter: blur(4px);
      opacity: 0.15;
    }

    .meeting-content {
      padding: 1.5rem 1.75rem;
      background: linear-gradient(to right, white 60%, transparent);
    }

    .meeting-meta {
      display: flex;
      gap: 1rem;
      margin-top: 0.75rem;
      color: #6b7280;
      font-size: 0.85rem;
    }

    .meta-item {
      display: flex;
      align-items: center;
      gap: 0.35rem;
    }
    
    .meeting-title {
      margin: 0;
      font-size: 1.25rem;
      font-weight: 600;
      color: #1a1a1a;
      display: -webkit-box;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }
    
    .meeting-description {
      margin: 0.5rem 0;
      font-size: 0.9rem;
      color: #4b5563;
      display: -webkit-box;
      -webkit-box-orient: vertical;
      overflow: hidden;
      line-height: 1.5;
    }
    
    .empty-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 3rem;
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 14px;
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

    .create-form {
      display: flex;
      flex-direction: column;
      gap: 1.25rem;
    }

    .form-group {
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
    }

    .form-group label {
      font-size: 0.9rem;
      font-weight: 500;
      color: #4b5563;
    }

    .form-input {
      padding: 0.875rem;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      font-size: 1rem;
      transition: all 0.15s ease;
      width: 100%;
      box-sizing: border-box;
    }

    .form-input:focus {
      outline: none;
      border-color: #064B45;
      box-shadow: 0 0 0 3px rgba(6, 75, 69, 0.1);
    }

    textarea.form-input {
      resize: vertical;
      min-height: 100px;
    }

    .form-actions {
      display: flex;
      gap: 1rem;
      margin-top: 0.5rem;
    }

  </style>