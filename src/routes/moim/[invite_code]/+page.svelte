<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import type { Moim, User, Participant, Mannam } from '$lib/types';
  import Spinner from '$lib/components/Spinner.svelte';
  import ErrorMessage from '$lib/components/ErrorMessage.svelte';
  import BottomSheet from '$lib/components/BottomSheet.svelte';
  import Button from '$lib/components/Button.svelte';

  let moim: any = null;
  let participants: any[] = [];
  let mannams: any[] = [];
  let errorMessage = '';
  let loading = true;
  // 현재 로그인 사용자 정보를 저장할 변수
  let currentUser: any = null;

  // URL 파라미터에서 초대 코드를 추출 (파일 이름은 [invite_code].svelte)
  let inviteCode = '';
  $: inviteCode = $page.params.invite_code;

  // 팝업 모달 표시 여부 (참여하지 않은 경우 true)
  let showJoinModal = false;

  // 구독 채널 참조 변수 (전역 변수로 선언)
  let subscription: any;

  // 페이지 초기화 함수
  onMount(() => {
    const initializePage = async () => {
      try {
        loading = true;
        // 1) 로그인 상태 확인: 세션이 없으면 /moim/[invite_code]/invite 페이지로 리다이렉트
        const { data: sessionData } = await supabase.auth.getSession();
        if (!sessionData?.session) {
          await goto(`/moim/${inviteCode}/invite`);
          return;
        }
        currentUser = sessionData.session.user;

        // 2) 모임 정보 조회 (invite_code로 조회) - maybeSingle() 사용
        const { data: moimData, error: moimError } = await supabase
          .from('moims')
          .select('*')
          .eq('invite_code', inviteCode)
          .maybeSingle();
        if (moimError) {
          errorMessage = moimError.message || '모임 정보를 불러오지 못했습니다.';
          return;
        }
        if (!moimData) {
          errorMessage = '해당 초대 코드에 관한 모임이 없습니다. 초대 코드: ' + inviteCode;
          return;
        }
        moim = moimData;

        // 3) 참여자 목록 조회
        const { data: partsData, error: partsError } = await supabase
          .from('moim_participants')
          .select('user_id, role')
          .eq('moim_id', moim.id);
        if (partsError) {
          errorMessage = '참여자 목록을 불러오는 중에 에러가 발생했습니다.' + partsError.message;
          return;
        }
        // 만약 데이터가 없다면 빈 배열로 처리
        let updatedPartsData = partsData || [];
        const participantUserIds = updatedPartsData.map((p: any) => p.user_id);
        // 만약 현재 사용자가 참여자 목록에 없다면, 팝업을 띄워 참여 여부를 묻습니다.
        if (!participantUserIds.includes(currentUser.id)) {
          showJoinModal = true;
        }

        // 참여자들의 프로필 정보 조회
        if (updatedPartsData.length > 0) {
          const userIds = updatedPartsData.map((p: any) => p.user_id);
          const { data: profilesData, error: profilesError } = await supabase
            .from('profiles')
            .select('id, name')
            .in('id', userIds);
          if (profilesError) {
            errorMessage = `참여자의 프로필 정보를 불러오는 중에 에러가 발생했습니다: ${
              profilesError?.message || '알 수 없는 오류'
            }`;
            return;
          }
          participants = updatedPartsData.map((participant: any) => ({
            ...participant,
            profile: profilesData?.find((profile: any) => profile.id === participant.user_id)
          }));
        } else {
          participants = [];
        }

        // 4) 만남 목록 조회
        const { data: mannamsData, error: mannamsError } = await supabase
          .from('mannams')
          .select('*')
          .eq('moim_id', moim.id)
          .order('created_at', { ascending: false });
        if (mannamsError) {
          errorMessage = `만남 목록을 불러오는 중에 에러가 발생했습니다: ${
            mannamsError?.message || '알 수 없는 오류'
          }`;
          return;
        }
        mannams = mannamsData ?? [];

        // 5) Realtime 구독 설정 (실시간 참여자 목록 업데이트)
        subscription = supabase
          .channel('moim_participants_changes')
          .on(
            'postgres_changes',
            {
              event: '*',
              schema: 'public',
              table: 'moim_participants',
              filter: `moim_id=eq.${moim.id}`
            },
            async () => {
              // 참여자 목록 새로 조회
              const { data: updatedPartsData } = await supabase
                .from('moim_participants')
                .select('user_id, role')
                .eq('moim_id', moim.id);
              if (updatedPartsData) {
                participants = updatedPartsData;
              }
            }
          )
          .subscribe();
      } catch (err) {
        errorMessage = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
      } finally {
        loading = false;
      }
    };
    initializePage();
  });

  // 컴포넌트 언마운트 시 구독 해제
  onDestroy(() => {
    if (subscription) {
      supabase.removeChannel(subscription);
    }
  });

  // "뒤로가기" 버튼 핸들러
  function goBack() {
    goto('/dashboard');
  }

  // "만남 추가" 버튼 핸들러
  function createMannam() {
    goto(`/moim/${inviteCode}/mannam/new`);
  }

  // 모임 참여 (팝업 "네" 버튼 클릭 시)
  async function joinMoim() {
    try {
      // 참여자 추가 처리
      const { data: insertedParticipants, error: insertError } = await supabase
        .from('moim_participants')
        .insert({ moim_id: moim.id, user_id: currentUser.id, role: 'participant' })
        .select();
      if (insertError) {
        errorMessage = `참여자를 추가하는 중에 에러가 발생했습니다: ${insertError?.message || '알 수 없는 오류'}`;
        return;
      }
      // 참여 성공 시 팝업을 닫고 페이지 새로고침 (또는 데이터 재조회)
      showJoinModal = false;
      window.location.reload();
    } catch (err) {
      errorMessage = err instanceof Error ? err.message : '참여 처리 중 알 수 없는 오류가 발생했습니다.';
    }
  }
</script>

{#if loading}
  <div class="global-spinner">
    <Spinner size="large" />
  </div>
{:else}
  <div class="moim-container">
    <div class="moim-content-wrapper">
      <header class="moim-header">
      <button class="back-btn" on:click={goBack} aria-label="Go back">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
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
        <section class="mannams-box info-box">
          <div class="mannams-header">
            <h2 class="section-title">만남 목록</h2>
            <button class="add-mannam-btn" on:click={createMannam} aria-label="만남 추가">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <line x1="12" y1="5" x2="12" y2="19"></line>
                <line x1="5" y1="12" x2="19" y2="12"></line>
              </svg>
              만남 추가하기
            </button>
          </div>
          {#if mannams.length > 0}
            <div class="mannams-list">
              {#each mannams as mannam}
                <div class="mannam-cell">
                  <h3 class="mannam-title">{mannam.title}</h3>
                  {#if mannam.description}
                    <p class="mannam-description">{mannam.description}</p>
                  {/if}
                  <p class="meta">생성일: {new Date(mannam.created_at).toLocaleDateString()}</p>
                </div>
              {/each}
            </div>
          {:else}
            <div class="empty-mannams">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="48"
                height="48"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
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
  </div>
{/if}

<BottomSheet show={showJoinModal} onClose={() => goto('/dashboard')} title="모임 참여" blurBackground={true}>
  <div class="join-sheet-content">
    <p class="join-description">이 모임에 참여하시겠습니까?</p>
    <div class="join-description-sub">모임에 참여하면 일정 조율에 참여할 수 있습니다.</div>
    <div class="form-actions">
      <Button
        variant="outline"
        on:click={() => goto('/dashboard')}
        flex={1}
      >돌아가기</Button>
      <Button
        variant="primary"
        on:click={joinMoim}
        flex={2}
      >참여하기</Button>
    </div>
  </div>
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

  .moim-container {
    width: 100%;
    min-height: 100vh;
    background: white;
  }

  .moim-content-wrapper {
    max-width: 500px;
    margin: 0 auto;
    padding: 1rem;
  }

  .moim-header {
    display: flex;
    gap: 0.5rem;
    padding: 0.75rem 0;
    border-bottom: 1px solid #f0f0f0;
    margin-bottom: 1rem;
    z-index: 100;
  }

  .back-btn {
    background: none;
    border: none;
    cursor: pointer;
    color: #064b45;
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
    padding: 1rem;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  }

  .moim-description,
  .no-description {
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
    background-color: #064b45;
    color: white;
    padding: 0.2rem 0.4rem;
    border-radius: 4px;
    font-size: 0.8rem;
    font-weight: 500;
  }

  /* 만남 섹션 */
  .mannams-box {
    margin-top: 1.5rem;
  }

  .mannams-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .mannams-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .mannam-cell {
    background: #fafafa;
    padding: 1rem;
    border-radius: 6px;
    transition: transform 0.2s, box-shadow 0.2s;
  }

  .mannam-cell:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  }

  .mannam-title {
    margin: 0 0 8px 0;
    font-size: 1.1rem;
    color: #2d3748;
  }

  .mannam-description {
    font-size: 0.9rem;
    color: #4a5568;
    margin: 0;
  }

  .empty-mannams {
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

  .add-mannam-btn {
    display: flex;
    gap: 0.2rem;
    background-color: #064b45;
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

  .add-mannam-btn:hover {
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

  .join-description {
    font-size: 1.125rem;
    font-weight: 600;
    color: #1F2937;
  }

  .join-description-sub {
    font-size: 0.875rem;
    color: #6B7280;
    margin-bottom: 2rem;
  }

  .form-actions {
    display: flex;
    gap: 0.75rem;
    margin-top: 1.5rem;
  }
  
</style>
