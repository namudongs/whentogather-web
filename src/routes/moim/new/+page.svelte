<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { goto } from '$app/navigation';

  // 입력 필드: 모임 제목과 설명
  let title = '';
  let description = '';
  let errorMessage = '';
  let loading = false;

  async function createMoim() {
    errorMessage = '';
    if (!title) {
      errorMessage = '모임 제목은 필수입니다.';
      return;
    }
    loading = true;

    // 1) 현재 로그인 사용자 정보 가져오기
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      errorMessage = '로그인 정보가 없습니다. 다시 로그인해 주세요.';
      loading = false;
      return;
    }

    // 2) 모임 생성 (moims 테이블)
    const { data: newMoim, error: moimError } = await supabase
      .from('moims')
      .insert({
        title,
        description,
        creator_id: user.id
      })
      .select()
      .single();

    if (moimError || !newMoim) {
      errorMessage = moimError?.message || '모임 생성 중 오류가 발생했습니다.';
      loading = false;
      return;
    }

    // 3) 모임에 자신을 creator로 추가 (moim_participants 테이블)
    //    RLS 정책에 의해, creator는 관리 정책을 통해 삽입되므로 role은 'creator'로 지정
    const { data: participant, error: participantError } = await supabase
      .from('moim_participants')
      .insert({
        moim_id: newMoim.id,
        user_id: user.id,
        role: 'creator'
      })
      .select()
      .single();

    if (participantError) {
      errorMessage = participantError.message;
      loading = false;
      return;
    }

    // 4) 모임 상세 페이지로 이동 (예: /moim/[id])
    goto(`/moim/${newMoim.id}`);
  }
</script>

<div class="dashboard-container">
  <header class="dashboard-header">
    <div class="header-content">
      <h1 class="font-extrabold">새로운 모임 만들기</h1>
    </div>
  </header>

  <main class="dashboard-content">
    <form on:submit|preventDefault={createMoim} class="create-meeting-form">
      {#if errorMessage}
        <p class="error-message">{errorMessage}</p>
      {/if}

      <div class="form-group">
        <label for="title">모임 제목</label>
        <input id="title" type="text" bind:value={title} placeholder="예: 동아리 회의" />
      </div>

      <div class="form-group">
        <label for="description">모임 설명 (선택)</label>
        <textarea
          id="description"
          bind:value={description}
          placeholder="모임에 대한 간단한 소개 또는 설명을 작성해 주세요."
        ></textarea>
      </div>

      <button type="submit" class="submit-button" disabled={loading}>
        {loading ? '생성 중...' : '모임 생성하기'}
      </button>
    </form>
  </main>
</div>

<style>
  :global(body) {
    margin: 0;
    background: white;
    color: #333;
  }

  .dashboard-container {
    max-width: 800px;
    margin: 0 auto;
    padding: 0 1.5rem;
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

  .header-content h1 {
    margin: 0;
    font-size: 1.5rem;
    font-weight: 600;
    color: #333;
  }

  .dashboard-content {
    display: flex;
    flex-direction: column;
    gap: 2rem;
  }

  .create-meeting-form {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .form-group label {
    font-size: 0.9rem;
    font-weight: 500;
    color: #666;
  }

  .form-group input,
  .form-group textarea {
    padding: 0.75rem;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    font-size: 0.9rem;
    transition: all 0.15s ease;
  }

  .form-group input:focus,
  .form-group textarea:focus {
    outline: none;
    border-color: #064B45;
    box-shadow: 0 0 0 1px #064B45;
  }

  .form-group textarea {
    min-height: 100px;
    resize: vertical;
  }

  .error-message {
    color: #e53e3e;
    font-size: 0.9rem;
    margin-bottom: 1rem;
  }

  .submit-button {
    background-color: #064B45;
    color: white;
    padding: 0.75rem;
    border: none;
    border-radius: 6px;
    font-weight: 600;
    font-size: 0.9rem;
    cursor: pointer;
    transition: background-color 0.15s ease;
  }

  .submit-button:hover {
    background-color: #053c37;
  }

  .submit-button:disabled {
    background-color: #9CA3AF;
    cursor: not-allowed;
  }
</style>