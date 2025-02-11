<script lang="ts">
    import { supabase } from '$lib/supabaseClient';
    import { goto } from '$app/navigation';
    import { fade, fly } from 'svelte/transition';
    import { quintOut } from 'svelte/easing';

    let loading = false;
    let email = '';
    let password = '';
    let errorMessage = '';
    let isEmailFocused = false;
    let isPasswordFocused = false;
    let isEmailValid = true;
    let isPasswordValid = true;

    $: {
        const emailRegex = /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/;
        isEmailValid = !email || emailRegex.test(email);
        isPasswordValid = !password || password.length >= 6;
    }
    let socialLoading = {
        google: false,
        kakao: false,
        apple: false
    };

    async function handleLogin() {
        try {
            loading = true;
            errorMessage = '';

            // 이메일 형식 검사
            const emailRegex = /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/;
            if (!emailRegex.test(email)) {
                errorMessage = '유효한 이메일 주소를 입력해주세요.';
                loading = false;
                return;
            }

            // 로그인 시도
            const { data, error } = await supabase.auth.signInWithPassword({
                email: email.toLowerCase().trim(), // 이메일 정규화
                password
            });

            if (error) {
                if (error.message === 'Invalid login credentials') {
                    errorMessage = '이메일 또는 비밀번호가 일치하지 않습니다.';
                } else {
                    errorMessage = error.message;
                }
                return;
            }

            if (data?.user) {
                goto('/dashboard');
            }
        } catch (error: any) {
            errorMessage = '로그인 중 오류가 발생했습니다.';
            console.error('Login error:', error);
        } finally {
            loading = false;
        }
    }

    async function loginWithGoogle() {
        try {
            socialLoading.google = true;
            const { error } = await supabase.auth.signInWithOAuth({
                provider: 'google',
                options: {
                    redirectTo: '/auth/callback'
                }
            });
            if (error) {
                errorMessage = error.message;
                socialLoading.google = false;
            }
        } catch (error: any) {
            errorMessage = error.message;
            socialLoading.google = false;
        }
    }

    async function loginWithKakao() {
        try {
            socialLoading.kakao = true;
            const { error } = await supabase.auth.signInWithOAuth({
                provider: 'kakao',
                options: { redirectTo: '/auth/callback' }
            });
            if (error) {
                errorMessage = error.message;
                socialLoading.kakao = false;
            }
        } catch (error: any) {
            errorMessage = error.message;
            socialLoading.kakao = false;
        }
    }

    async function loginWithApple() {
        try {
            socialLoading.apple = true;
            const { error } = await supabase.auth.signInWithOAuth({
                provider: 'apple',
                options: { redirectTo: '/auth/callback' }
            });
            if (error) {
                errorMessage = error.message;
                socialLoading.apple = false;
            }
        } catch (error: any) {
            errorMessage = error.message;
            socialLoading.apple = false;
        }
    }
</script>

<main>
    <div class="login-container">
        <h1>로그인</h1>
        <form on:submit|preventDefault={handleLogin} id="login-form">
            <input 
                type="email" 
                bind:value={email} 
                placeholder="이메일" 
                required 
                name="email"
                autocomplete="email"
                form="login-form"
            />
            <input 
                type="password" 
                bind:value={password} 
                placeholder="비밀번호" 
                required 
                name="current-password"
                autocomplete="current-password"
                minlength="6"
                form="login-form"
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
            <button type="submit" disabled={loading} class="submit-btn">
                {#if loading}
                    <div class="spinner"></div>
                    <span>로그인 중</span>
                {:else}
                    <span>로그인</span>
                {/if}
            </button>
            <div class="signup-link">
                계정이 없으신가요? <a href="/signup">회원가입하기</a>
            </div>
            <div class="divider">
                <span>또는 아래로 계속하기</span>
            </div>
            <button type="button" class="social-btn google-btn" on:click={loginWithGoogle} disabled={socialLoading.google}>
                {#if socialLoading.google}
                    <div class="spinner social-spinner"></div>
                    <span>연결 중</span>
                {:else}
                    <img src="/images/google.svg" alt="Google logo" />
                    <span>Google로 계속하기</span>
                {/if}
            </button>
            <button type="button" class="social-btn kakao-btn" on:click={loginWithKakao} disabled={socialLoading.kakao}>
                {#if socialLoading.kakao}
                    <div class="spinner social-spinner"></div>
                    <span>연결 중</span>
                {:else}
                    <img src="/images/kakao.svg" alt="Kakao logo" />
                    <span>카카오로 계속하기</span>
                {/if}
            </button>
            <button type="button" class="social-btn apple-btn" on:click={loginWithApple} disabled={socialLoading.apple}>
                {#if socialLoading.apple}
                    <div class="spinner social-spinner"></div>
                    <span>연결 중</span>
                {:else}
                    <img src="/images/apple.svg" alt="Apple logo" />
                    <span>Apple로 계속하기</span>
                {/if}
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
        height: 100vh;
        padding: 1rem;
        box-sizing: border-box;
        overflow: auto;
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

    .submit-btn {
        background-color: #064B45;
        color: white;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        min-height: 2.75rem;
    }

    .submit-btn:hover {
        background-color: #053c37;
    }

    .submit-btn:disabled {
        opacity: 0.7;
        cursor: not-allowed;
    }

    .spinner {
        width: 1rem;
        height: 1rem;
        border: 2px solid rgba(255, 255, 255, 0.3);
        border-radius: 50%;
        border-top-color: white;
        animation: spin 0.6s linear infinite;
    }

    @keyframes spin {
        to {
            transform: rotate(360deg);
        }
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

    .signup-link {
        text-align: center;
        font-size: 0.875rem;
        color: #4b5563;
        margin-bottom: 0rem;
    }

    .signup-link a {
        color: #064B45;
        text-decoration: none;
        font-weight: 500;
    }

    .signup-link a:hover {
        text-decoration: underline;
    }

    .social-spinner {
        border-color: rgba(0, 0, 0, 0.2);
        border-top-color: currentColor;
    }

    .apple-btn .social-spinner {
        border-color: rgba(255, 255, 255, 0.2);
        border-top-color: white;
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