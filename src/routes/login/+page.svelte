<script lang="ts">
    import { supabase } from '$lib/supabaseClient';
    import { goto } from '$app/navigation';

    let loading = false;
    let email = '';
    let password = '';
    let errorMessage = '';

    async function handleLogin() {
        try {
            loading = true;
            errorMessage = '';
            const { error } = await supabase.auth.signInWithPassword({
                email,
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

<div class="login-container">
    <div class="login-box">
        <h1>로그인</h1>
        
        <form on:submit|preventDefault={handleLogin}>
            <div class="form-group">
                <label for="email">이메일</label>
                <input
                    type="email"
                    id="email"
                    bind:value={email}
                    required
                />
            </div>

            <div class="form-group">
                <label for="password">비밀번호</label>
                <input
                    type="password"
                    id="password"
                    bind:value={password}
                    required
                />
            </div>

            {#if errorMessage}
                <div class="error">{errorMessage}</div>
            {/if}

            <button type="submit" disabled={loading}>
                {loading ? '로그인 중...' : '로그인'}
            </button>
        </form>

        <div class="divider">
            <span>또는</span>
        </div>

        <div class="social-login-container">
            <button class="social-login" on:click={loginWithGoogle}>
                <img src="https://www.google.com/favicon.ico" alt="Google" />
                Google로 로그인
            </button>
            <button class="social-login" on:click={loginWithKakao}>
                <img src="https://www.kakaocorp.com/favicon.ico" alt="Kakao" />
                Kakao로 로그인
            </button>
            <button class="social-login" on:click={loginWithApple}>
                <img src="https://www.apple.com/favicon.ico" alt="Apple" />
                Apple로 로그인
            </button>
        </div>
    </div>
</div>

<style>
    .login-container {
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100vh;
        background-color: #f5f5f5;
    }

    .login-box {
        background: white;
        padding: 2rem;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        width: 100%;
        max-width: 400px;
    }

    h1 {
        margin-bottom: 1.5rem;
        text-align: center;
        color: #333;
    }

    .form-group {
        margin-bottom: 1rem;
    }

    label {
        display: block;
        margin-bottom: 0.5rem;
        color: #555;
    }

    input {
        width: 100%;
        padding: 0.5rem;
        border: 1px solid #ddd;
        border-radius: 4px;
        font-size: 1rem;
    }

    button {
        width: 100%;
        padding: 0.75rem;
        background-color: #4a90e2;
        color: white;
        border: none;
        border-radius: 4px;
        font-size: 1rem;
        cursor: pointer;
        transition: background-color 0.2s;
    }

    button:hover {
        background-color: #357abd;
    }

    button:disabled {
        background-color: #ccc;
        cursor: not-allowed;
    }

    .error {
        color: #e74c3c;
        margin-bottom: 1rem;
        font-size: 0.9rem;
    }

    .divider {
        text-align: center;
        margin: 1.5rem 0;
        position: relative;
    }

    .divider::before,
    .divider::after {
        content: '';
        position: absolute;
        top: 50%;
        width: 45%;
        height: 1px;
        background-color: #ddd;
    }

    .divider::before {
        left: 0;
    }

    .divider::after {
        right: 0;
    }

    .divider span {
        background-color: white;
        padding: 0 10px;
        color: #666;
        font-size: 0.9rem;
    }

    .social-login-container {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }

    .social-login {
        background-color: white;
        color: #333;
        border: 1px solid #ddd;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        padding: 0.5rem;
        border-radius: 4px;
    }

    .social-login img {
        width: 18px;
        height: 18px;
    }
</style>