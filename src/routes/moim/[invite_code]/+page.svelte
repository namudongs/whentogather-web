<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';

  let moim: any = null;
  let participants: any[] = [];
  let meetups: any[] = [];
  let errorMessage = '';
  let loading = true;

  // URL 파라미터에서 초대 코드를 추출 (파일 이름은 [invite_code].svelte)
  let inviteCode = '';
  $: inviteCode = $page.params.invite_code;

  onMount(async () => {
    try {
      loading = true;
      // 1) 모임 정보 조회 (invite_code로 조회)
      const { data: moimData, error: moimError } = await supabase
        .from('moims')
        .select('*')
        .eq('invite_code', inviteCode)
        .single();
      if (moimError || !moimData) {
        errorMessage = moimError?.message || '모임 정보를 불러오지 못했습니다.';
        return;
      }
      moim = moimData;

      // 2) 참여자 목록 조회 (DB에서는 moim_id를 사용하여 조회)
      const { data: partsData, error: partsError } = await supabase
        .from('moim_participants')
        .select('user_id, role')
        .eq('moim_id', moim.id);
      if (partsError) {
        errorMessage = partsError.message;
        return;
      }
      if (partsData && partsData.length > 0) {
        const userIds = partsData.map(p => p.user_id);
        const { data: profilesData, error: profilesError } = await supabase
          .from('profiles')
          .select('id, name')
          .in('id', userIds);
        if (profilesError) {
          errorMessage = profilesError.message;
          return;
        }
        participants = partsData.map(participant => ({
          ...participant,
          profile: profilesData?.find(profile => profile.id === participant.user_id)
        }));
      } else {
        participants = [];
      }

      // 3) 만남 목록 조회
      const { data: meetupsData, error: meetupsError } = await supabase
        .from('meetups')
        .select('*')
        .eq('moim_id', moim.id)
        .order('created_at', { ascending: false });
      if (meetupsError) {
        errorMessage = meetupsError.message;
        return;
      }
      meetups = meetupsData;
    } catch (err: any) {
      errorMessage = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
    } finally {
      loading = false;
    }
  });

  function goBack() {
    goto('/dashboard');
  }

  function createMeetup() {
    // 초대 코드 기반 URL을 그대로 사용하여 만남 추가 페이지로 이동합니다.
    goto(`/moim/${inviteCode}/meetup/new`);
  }
</script>

{#if loading}
  <!-- 전역 스피너 -->
  <div class="global-spinner">
    <div class="spinner"></div>
  </div>
{:else}
  <div class="moim-container">
    <header class="moim-header">
      <button class="back-btn" on:click={goBack} aria-label="Go back">
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M19 12H5" />
          <path d="M12 19l-7-7 7-7" />
        </svg>
      </button>
      <h1 class="moim-title font-extrabold">{moim ? moim.title : '모임 상세'}</h1>
    </header>

    <main class="moim-content">
      {#if errorMessage}
        <p class="error">{errorMessage}</p>
      {:else if moim}
        <!-- 모임 정보 섹션 -->
        <section class="moim-info info-box">
          {#if moim.description}
            <p class="moim-description">{moim.description}</p>
          {:else}
            <p class="no-description">설명 없음</p>
          {/if}
          <p class="meta"><strong>생성일:</strong> {new Date(moim.created_at).toLocaleString()}</p>
          <p class="meta"><strong>마지막 업데이트:</strong> {new Date(moim.updated_at).toLocaleString()}</p>
        </section>

        <!-- 참여자 목록 섹션 -->
        <section class="participants-box info-box">
          <h2 class="section-title">참여자 목록</h2>
          {#if participants.length > 0}
            <ul class="participants-list">
              {#each participants as participant}
                <li class="participant-item">
                  <span class="participant-name">{participant.profile?.name || '이름 없음'}</span>
                  {#if participant.role === 'creator'}
                    <span class="creator-tag">모임장</span>
                  {/if}
                </li>
              {/each}
            </ul>
          {:else}
            <p class="no-participants">아직 참여자가 없습니다.</p>
          {/if}
        </section>

        <!-- 만남 목록 섹션 -->
        <section class="meetups-box info-box">
          <div class="meetups-header">
            <h2 class="section-title">만남 목록</h2>
            <button class="add-meetup-btn" on:click={createMeetup} aria-label="만남 추가">
              <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <line x1="12" y1="5" x2="12" y2="19"></line>
                <line x1="5" y1="12" x2="19" y2="12"></line>
              </svg>
              만남 추가하기
            </button>
          </div>
          {#if meetups.length > 0}
            <div class="meetups-list">
              {#each meetups as meetup}
                <div class="meetup-cell">
                  <h3 class="meetup-title">{meetup.title}</h3>
                  {#if meetup.description}
                    <p class="meetup-description">{meetup.description}</p>
                  {/if}
                  <p class="meta">생성일: {new Date(meetup.created_at).toLocaleDateString()}</p>
                </div>
              {/each}
            </div>
          {:else}
            <div class="empty-meetups">
              <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="9" cy="7" r="4"></circle>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
              </svg>
              <p class="empty-text">아직 만남이 없어요.</p>
            </div>
          {/if}
        </section>
      {:else}
        <p class="not-found">해당 모임 정보를 찾을 수 없습니다.</p>
      {/if}
    </main>
  </div>
{/if}
  
<style>
  :global(body) {
    margin: 0;
    background: #f5f5f5;
    color: #333;
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
  
  .moim-container {
    max-width: 800px;
    margin: 2rem auto;
    padding: 2rem;
    background: #fff;
    border-radius: 8px;
  }
  
  .moim-header {
    display: flex;
    gap: 1rem;
    padding: 1rem 0;
    border-bottom: 1px solid #f0f0f0;
    margin-bottom: 2rem;
    z-index: 100;
  }
  
  .back-btn {
    background: none;
    border: none;
    cursor: pointer;
    color: #064B45;
    transition: color 0.2s;
  }
  
  .back-btn:hover {
    color: #043835;
  }
  
  .moim-title {
    font-size: 1.5rem;
    margin: 0;
    text-align: left;
    color: #333;
    flex: 1;
  }
  
  .moim-content {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }
  
  /* 정보 박스 스타일 */
  .info-box {
    background: #fafafa;
    padding: 1.5rem;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  }
  
  .moim-description, .no-description {
    margin: 0;
    font-size: 1rem;
    color: #4a5568;
  }
  
  .no-description {
    font-style: italic;
    color: #a0aec0;
  }
  
  .meta {
    font-size: 0.9rem;
    color: #718096;
    margin-top: 0.5rem;
  }
  
  /* 참여자 섹션 */
  .participants-box {
    margin-top: 1.5rem;
  }
  
  .section-title {
    font-size: 1.25rem;
    font-weight: 600;
    margin-bottom: 0.75rem;
    color: #333;
  }
  
  .participants-list {
    list-style: none;
    padding: 0;
    margin: 0;
  }
  
  .participant-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0.5rem 0;
    border-bottom: 1px solid #e2e8f0;
  }
  
  .participant-item:last-child {
    border-bottom: none;
  }
  
  .participant-name {
    font-size: 1rem;
    color: #4a5568;
  }
  
  .creator-tag {
    background-color: #064B45;
    color: white;
    padding: 0.2rem 0.4rem;
    border-radius: 4px;
    font-size: 0.8rem;
    font-weight: 500;
  }
  
  /* 만남 섹션 */
  .meetups-box {
    margin-top: 1.5rem;
  }
  
  .meetups-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }
  
  .meetups-list {
    display: grid;
    gap: 16px;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  }
  
  .meetup-cell {
    background: #fafafa;
    padding: 1rem;
    border-radius: 6px;
    transition: transform 0.2s, box-shadow 0.2s;
  }
  
  .meetup-cell:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
  }
  
  .meetup-title {
    margin: 0 0 8px 0;
    font-size: 1.1rem;
    color: #2d3748;
  }
  
  .meetup-description {
    font-size: 0.9rem;
    color: #4a5568;
    margin: 0;
  }
  
  .empty-meetups {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 3rem;
    background: #fafafa;
    border-radius: 8px;
    color: #666;
  }
  
  .empty-text {
    margin: 0 0 16px;
    font-size: 1rem;
    color: #718096;
  }
  
  .add-meetup-btn {
    display: flex;
    gap: 0.2rem;
    background-color: #064B45;
    color: white;
    border: none;
    padding: 0.4rem 0.8rem;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 0.2s;
    align-items: center;
    font-size: 0.8rem;
    margin-top: -0.5rem;
  }
  
  .add-meetup-btn:hover {
    background-color: #043835;
  }
  
  .error {
    color: #e53e3e;
    text-align: center;
    padding: 1rem;
    background: #fff5f5;
    border-radius: 6px;
  }
  
  .not-found {
    text-align: center;
    color: #e53e3e;
    padding: 1rem;
  }
</style>