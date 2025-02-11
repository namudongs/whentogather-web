<script lang="ts">
    import { onMount } from 'svelte';
    import { supabase } from '$lib/supabaseClient';
    import { goto } from '$app/navigation';

    let userEmail: string | null | undefined = null;
    let userName: string | null | undefined = null;

    onMount(async () => {
        const { data } = await supabase.auth.getSession();
        if (!data?.session) {
            goto('/login');
            return;
        }
        userEmail = data.session.user.email;
        userName = data.session.user.user_metadata?.full_name;
    });

    async function handleSignOut() {
        const { error } = await supabase.auth.signOut();
        if (!error) {
            goto('/login');
        }
    }
</script>

<div class="dashboard-container">
    <header class="dashboard-header">
        <div class="user-info">
            <h1>대시보드</h1>
            <p>안녕하세요, {userName || userEmail || '사용자'}님!</p>
        </div>
        <button class="sign-out-btn" on:click={handleSignOut}>
            로그아웃
        </button>
    </header>

    <main class="dashboard-content">
        <div class="welcome-message">
            <h2>환영합니다!</h2>
            <p>이곳에서 모임을 관리하고 일정을 조율할 수 있습니다.</p>
        </div>

        <!-- 추후 모임 목록이나 다른 기능들이 이곳에 추가될 수 있습니다 -->
    </main>
</div>

<style>
    .dashboard-container {
        padding: 2rem;
        max-width: 1200px;
        margin: 0 auto;
    }

    .dashboard-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 2rem;
        padding-bottom: 1rem;
        border-bottom: 1px solid #eee;
    }

    .user-info h1 {
        margin: 0;
        color: #333;
        font-size: 1.8rem;
    }

    .user-info p {
        margin: 0.5rem 0 0;
        color: #666;
    }

    .sign-out-btn {
        padding: 0.5rem 1rem;
        background-color: #f5f5f5;
        color: #333;
        border: 1px solid #ddd;
        border-radius: 4px;
        cursor: pointer;
        transition: all 0.2s;
    }

    .sign-out-btn:hover {
        background-color: #e5e5e5;
    }

    .dashboard-content {
        background: white;
        padding: 2rem;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    }

    .welcome-message {
        text-align: center;
        padding: 2rem;
    }

    .welcome-message h2 {
        color: #333;
        margin-bottom: 1rem;
    }

    .welcome-message p {
        color: #666;
        font-size: 1.1rem;
    }
</style>