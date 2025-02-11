<script lang="ts">
    import { supabase } from '$lib/supabaseClient';
    import { goto } from '$app/navigation';

    let loading = false;
    let username = '';
    let password = '';
    let errorMessage = '';

    async function handleLogin() {
        try {
            loading = true;
            errorMessage = '';
            const { error } = await supabase.auth.signInWithPassword({
                email: username,
                password
            });

            if (error) throw error;
            goto('/dashboard');
        } catch (error: any) {
            errorMessage = error.message;
        } finally {
            loading = false;
        }
    }

    async function loginWithGoogle() {
        const { error } = await supabase.auth.signInWithOAuth({
            provider: 'google',
            options: {
                redirectTo: '/auth/callback'
            }
        });
        if (error) {
            errorMessage = error.message;
        }
    }

    async function loginWithKakao() {
        const { error } = await supabase.auth.signInWithOAuth({
            provider: 'kakao',
            options: { redirectTo: '/auth/callback' }
        });
        if (error) {
            errorMessage = error.message;
        }
    }

    async function loginWithApple() {
        const { error } = await supabase.auth.signInWithOAuth({
            provider: 'apple',
            options: { redirectTo: '/auth/callback' }
        });
        if (error) {
            errorMessage = error.message;
        }
    }
</script>

<main>
    <div class="login-container">
        <h1>로그인</h1>
        <form on:submit|preventDefault={handleLogin}>
            <input 
                type="text" 
                bind:value={username} 
                placeholder="아이디 또는 이메일" 
                required 
                autocomplete="username"
            />
            <input 
                type="password" 
                bind:value={password} 
                placeholder="비밀번호" 
                required 
                autocomplete="current-password"
            />
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
            <button type="submit" disabled={loading}>
                {#if loading}
                    <span>로그인 중...</span>
                {:else}
                    <span>로그인</span>
                {/if}
            </button>
            <div class="divider">
                <span>또는 아래로 계속하기</span>
            </div>
            <button type="button" class="social-btn google-btn" on:click={loginWithGoogle}>
                <img src="/images/google.svg" alt="Google logo" />
                Google로 계속하기
            </button>
            <button type="button" class="social-btn kakao-btn" on:click={loginWithKakao}>
                <img src="/images/kakao.svg" alt="Kakao logo" />
                카카오로 계속하기
            </button>
            <button type="button" class="social-btn apple-btn" on:click={loginWithApple}>
                <img src="/images/apple.svg" alt="Apple logo" />
                Apple로 계속하기
            </button>
        </form>
    </div>
</main>

<style>
    :global(body) {
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        background: white;
    }

    main {
        display: flex;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
        padding: 1rem;
    }

    .login-container {
        width: 100%;
        max-width: 320px;
    }

    h1 {
        font-size: 1.5rem;
        font-weight: 600;
        text-align: center;
        margin-bottom: 2rem;
        color: #333;
    }

    form {
        display: flex;
        flex-direction: column;
        gap: 1rem;
    }

    input {
        padding: 0.75rem;
        border: 1px solid #e0e0e0;
        border-radius: 4px;
        font-size: 0.9rem;
        transition: border-color 0.15s ease;
    }

    input:focus {
        outline: none;
        border-color: #064B45;
    }

    button {
        padding: 0.75rem;
        border: none;
        border-radius: 4px;
        font-size: 0.9rem;
        font-weight: 500;
        cursor: pointer;
        transition: background-color 0.15s ease;
    }

    button[type="submit"] {
        background-color: #064B45;
        color: white;
    }

    button[type="submit"]:hover {
        background-color: #053c37;
    }

    .divider {
        display: flex;
        align-items: center;
        margin: 1.5rem 0;
        color: #666;
        font-size: 0.85rem;
    }

    .divider::before,
    .divider::after {
        content: '';
        flex: 1;
        border-bottom: 1px solid #eee;
    }

    .divider span {
        margin: 0 0.75rem;
    }

    .social-btn {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        padding: 0.75rem;
        border: none;
        border-radius: 4px;
        font-size: 0.9rem;
        font-weight: 500;
        width: 100%;
        transition: filter 0.15s ease;
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
        background: white;
        color: #3c4043;
        border: 1px solid #dadce0;
    }

    .google-btn:hover {
        background: #f8f9fa;
        border-color: #dadce0;
        filter: none;
    }

    /* Kakao 버튼 스타일 */
    .kakao-btn {
        background: #FEE500;
        color: #000000;
    }

    /* Apple 버튼 스타일 */
    .apple-btn {
        background: #000000;
        color: white;
    }

    .apple-btn img {
        filter: invert(1) brightness(100%);
    }

    .error {
        color: #e53e3e;
        font-size: 0.85rem;
        margin-bottom: 0.5rem;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }

    @media (max-width: 480px) {
        main {
            padding: 1.5rem;
        }
    }
</style>