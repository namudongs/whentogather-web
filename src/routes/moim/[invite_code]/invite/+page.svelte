<script lang="ts">
    import { onMount } from 'svelte';
    import { supabase } from '$lib/supabaseClient';
    import { page } from '$app/stores';
    import { goto } from '$app/navigation';
    import type { Provider } from '@supabase/supabase-js';
  
    // URL 파라미터에서 초대 코드를 추출 (파일 이름은 [invite_code].svelte 내에 invite 폴더)
    let inviteCode = '';
    $: inviteCode = $page.params.invite_code;
  
    let loading = true;
    let errorMessage = '';
  
    // 페이지 로드시 로그인 여부 확인: 로그인 상태라면 바로 모임 상세 페이지로 리다이렉트
    onMount(async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (session) {
          goto(`/moim/${inviteCode}`);
        }
      } catch (err: any) {
        errorMessage = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
      } finally {
        loading = false;
      }
    });
  
    // 소셜 로그인 함수들 (Google, Kakao, Apple)
    async function loginWithProvider(provider: Provider) {
      try {
        // 로그인 요청: redirectTo 옵션은 서비스에 맞게 설정
        const { error } = await supabase.auth.signInWithOAuth({
          provider,
          options: { redirectTo: `/moim/${inviteCode}` }
        });
        if (error) {
          errorMessage = error.message;
        }
      } catch (err: any) {
        errorMessage = err instanceof Error ? err.message : '로그인 중 오류가 발생했습니다.';
      }
    }
  
    // onAuthStateChange를 구독하여 로그인 후 자동 리다이렉트
    supabase.auth.onAuthStateChange((event, session) => {
      if (session) {
        goto(`/moim/${inviteCode}`);
      }
    });
  </script>
  
  {#if loading}
    <div class="global-spinner">
      <div class="spinner"></div>
    </div>
  {:else}
    <main>
      <div class="login-container">
        <h1 class="font-extrabold">초대 받으셨습니다!</h1>
        <p class="invite-message">
          당신은 <span class="code">{inviteCode}</span> 초대 코드를 통해 모임에 초대되었습니다.
          서비스를 이용하려면 소셜 로그인을 통해 가입해 주세요.
        </p>
        {#if errorMessage}
          <div class="error">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10"></circle>
              <line x1="12" y1="8" x2="12" y2="12"></line>
              <line x1="12" y1="16" x2="12.01" y2="16"></line>
            </svg>
            {errorMessage}
          </div>
        {/if}
        <div class="social-login-buttons">
          <button type="button" class="social-btn google-btn" on:click={() => loginWithProvider('google')}>
            <img src="/images/google.svg" alt="Google logo" />
            <span>Google로 계속하기</span>
          </button>
          <button type="button" class="social-btn kakao-btn" on:click={() => loginWithProvider('kakao')}>
            <img src="/images/kakao.svg" alt="Kakao logo" />
            <span>카카오로 계속하기</span>
          </button>
          <button type="button" class="social-btn apple-btn" on:click={() => loginWithProvider('apple')}>
            <img src="/images/apple.svg" alt="Apple logo" />
            <span>Apple로 계속하기</span>
          </button>
        </div>
      </div>
    </main>
  {/if}
  
  <style>
    main {
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 2rem;
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
  
    main {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 1rem;
      box-sizing: border-box;
    }
  
    .login-container {
      width: 100%;
      max-width: 320px;
      background: #fff;
      padding: 2rem;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0, 0, 0, 0.05);
      text-align: center;
    }
  
    h1 {
      font-size: 1.75rem;
      font-weight: 600;
      margin-bottom: 1.5rem;
      color: #064B45;
    }
  
    .invite-message {
      font-size: 1rem;
      color: #4a5568;
      margin-bottom: 2rem;
    }
  
    .invite-message .code {
      font-weight: 600;
      color: #064B45;
    }
  
    .error {
      color: #e53e3e;
      font-size: 0.9rem;
      margin-bottom: 1rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
  
    .social-login-buttons {
      display: flex;
      flex-direction: column;
      gap: 1rem;
    }
  
    .social-btn {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 0.5rem;
      padding: 0.75rem;
      border: none;
      border-radius: 4px;
      font-size: 1rem;
      font-weight: 500;
      width: 100%;
      transition: filter 0.15s ease;
      cursor: pointer;
      color: white;
    }
  
    .social-btn:hover {
      filter: brightness(95%);
    }
  
    .social-btn img {
      width: 18px;
      height: 18px;
    }
  
    /* Google 버튼 스타일 */
    .google-btn {
      background-color: #db4437;
    }
  
    /* Kakao 버튼 스타일 */
    .kakao-btn {
      background-color: #FEE500;
      color: #000;
    }
  
    /* Apple 버튼 스타일 */
    .apple-btn {
      background-color: #000;
    }
  
    .apple-btn img {
      filter: invert(1);
    }
  </style>