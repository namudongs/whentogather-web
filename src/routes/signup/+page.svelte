<script lang="ts">
    import { supabase } from '$lib/supabaseClient';
    import { goto } from '$app/navigation';
    import { fade, fly } from 'svelte/transition';
    import { quintOut } from 'svelte/easing';

    // 닉네임 유효성 검사
    function validateUsername(value: string) {
        const regex = /^[a-zA-Z0-9가-힣]{1,10}$/;
        return regex.test(value);
    }

    // 이메일 유효성 검사
    function validateEmail(value: string) {
        const regex = /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/;
        return regex.test(value);
    }

    // 비밀번호 유효성 검사
    function validatePassword(value: string) {
        return value.length >= 6;
    }

    let loading = false;
    let email = '';
    let password = '';
    let confirmPassword = '';
    let username = '';
    let errorMessage = '';
    
    let isUsernameFocused = false;
    let isEmailFocused = false;
    let isPasswordFocused = false;
    let isConfirmPasswordFocused = false;

    let isUsernameValid = true;
    let isEmailValid = true;
    let isPasswordValid = true;
    let isConfirmPasswordValid = true;

    $: {
        const usernameRegex = /^[a-zA-Z0-9가-힣]{1,10}$/;
        isUsernameValid = !username || usernameRegex.test(username);

        const emailRegex = /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/;
        isEmailValid = !email || emailRegex.test(email);

        isPasswordValid = !password || password.length >= 6;
        
        isConfirmPasswordValid = !confirmPassword || confirmPassword === password;
    }

    async function handleSignup() {
        try {
            // 유효성 검사
            if (!validateUsername(username)) {
                errorMessage = '닉네임은 영문, 한글, 숫자로 1~10자까지 가능합니다.';
                return;
            }

            if (!validateEmail(email)) {
                errorMessage = '유효한 이메일 주소를 입력해주세요.';
                return;
            }

            if (!validatePassword(password)) {
                errorMessage = '비밀번호는 최소 6자 이상이어야 합니다.';
                return;
            }

            if (password !== confirmPassword) {
                errorMessage = '비밀번호가 일치하지 않습니다.';
                return;
            }

            loading = true;
            errorMessage = '';

            // 회원가입 시도
            const { data, error } = await supabase.auth.signUp({
                email: email.toLowerCase().trim(),
                password,
                options: {
                    data: {
                        name: username
                    },
                    emailRedirectTo: `${window.location.origin}/auth/callback`
                }
            });

            // 회원가입 성공 후 자동 로그인
            if (data?.user) {
                const { error: loginError } = await supabase.auth.signInWithPassword({
                    email: email.toLowerCase().trim(),
                    password
                });

                if (loginError) {
                    errorMessage = '자동 로그인 중 오류가 발생했습니다. 로그인 페이지로 이동합니다.';
                    loading = false;
                    goto('/login');
                    return;
                }

                goto('/dashboard');
                return;
            }

            if (error) {
                if (error.message.includes('User already registered')) {
                    errorMessage = '이미 등록된 이메일입니다. 다른 이메일을 사용하거나 로그인을 시도해주세요.';
                } else {
                    errorMessage = error.message;
                }
                loading = false;
                return;
            }

            // 닉네임 중복 확인
            const { data: existingUsername } = await supabase
                .from('profiles')
                .select('name')
                .eq('name', username)
                .single();

            if (existingUsername) {
                errorMessage = '이미 사용 중인 닉네임입니다.';
                loading = false;
                return;
            }

            if (data?.user) {
                // 자동 로그인 시도
                const { error: signInError } = await supabase.auth.signInWithPassword({
                    email: email.toLowerCase().trim(),
                    password
                });

                if (!signInError) {
                    goto('/dashboard');
                    return;
                }
            }

            errorMessage = '회원가입이 완료되었습니다.';
        } catch (error: any) {
            errorMessage = error.message;
        } finally {
            loading = false;
        }
    }
</script>

<main>
    <div class="signup-container">
        <h1 class="font-extrabold">회원가입</h1>
        <form on:submit|preventDefault={handleSignup}>
            <input 
                type="text" 
                bind:value={username} 
                placeholder="닉네임 (영문, 한글, 숫자 1~10자)" 
                required 
                maxlength="10"
                name="username"
                autocomplete="username"
            />
            <input 
                type="email" 
                bind:value={email} 
                placeholder="이메일" 
                required 
                name="email"
                autocomplete="email"
            />
            <input 
                type="password" 
                bind:value={password} 
                placeholder="비밀번호 (6자 이상)" 
                required 
                minlength="6"
                name="new-password"
                autocomplete="new-password"
            />
            <input 
                type="password" 
                bind:value={confirmPassword} 
                placeholder="비밀번호 확인" 
                required 
                minlength="6"
                name="new-password"
                autocomplete="new-password"
            />
            {#if errorMessage}
                <div class="message font-regular" class:error={!errorMessage.includes('완료')}>
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="12" cy="12" r="10"></circle>
                        <line x1="12" y1="8" x2="12" y2="12"></line>
                        <line x1="12" y1="16" x2="12.01" y2="16"></line>
                    </svg>
                    {errorMessage}
                </div>
            {/if}
            <button type="submit" class="font-bold submit-btn" disabled={loading}>
                {#if loading}
                    <div class="spinner"></div>
                    <span>가입 중</span>
                {:else}
                    <span>가입하기</span>
                {/if}
            </button>
            <div class="login-link">
                이미 계정이 있으신가요? <a href="/login">로그인하기</a>
            </div>
        </form>
    </div>
</main>

<style>
    main {
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100vh;
        padding: 1rem;
        box-sizing: border-box;
        overflow: auto;
    }

    .signup-container {
        width: 100%;
        max-width: 320px;
    }

    h1 {
        color: #064B45;
        text-align: center;
        margin-bottom: 2rem;
        font-size: 1.5rem;
    }

    form {
        display: flex;
        flex-direction: column;
        gap: 1rem;
    }

    input {
        padding: 0.75rem;
        border: 1px solid #e2e8f0;
        border-radius: 0.375rem;
        font-size: 0.875rem;
        transition: border-color 0.15s ease;
    }

    input:focus {
        outline: none;
        border-color: #064B45;
    }

    .submit-btn {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        background-color: #064B45;
        color: white;
        padding: 0.75rem;
        border: none;
        border-radius: 0.375rem;
        font-size: 0.875rem;
        cursor: pointer;
        transition: background-color 0.15s ease;
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

    .message {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.75rem;
        border-radius: 0.375rem;
        font-size: 0.875rem;
        background-color: #f7fee7;
        color: #3f6212;
    }

    .message.error {
        background-color: #fef2f2;
        color: #991b1b;
    }

    .login-link {
        text-align: center;
        font-size: 0.875rem;
        color: #4b5563;
    }

    .login-link a {
        color: #064B45;
        text-decoration: none;
        font-weight: 500;
    }

    .login-link a:hover {
        text-decoration: underline;
    }
</style>
