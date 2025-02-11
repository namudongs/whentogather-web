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
        <div class="header-content">
            <div class="user-info">
                <h1>안녕하세요</h1>
                <p class="user-name">{userName || userEmail?.split('@')[0] || '사용자'}님</p>
            </div>
            <button class="sign-out-btn" on:click={handleSignOut}>
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
            <button class="action-btn create-meeting">
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="12" y1="5" x2="12" y2="19"></line>
                    <line x1="5" y1="12" x2="19" y2="12"></line>
                </svg>
                새로운 모임 만들기
            </button>
        </section>

        <section class="meetings-section">
            <h2>내 모임</h2>
            <div class="empty-state">
                <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                    <circle cx="9" cy="7" r="4"></circle>
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                    <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
                </svg>
                <p>아직 모임이 없습니다</p>
                <p class="subtitle">새로운 모임을 만들어보세요</p>
            </div>
        </section>
    </main>
</div>

<style>
    :global(body) {
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
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

    .user-info h1 {
        margin: 0;
        font-size: 1.5rem;
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
        gap: 2rem;
    }

    .quick-actions {
        display: flex;
        gap: 1rem;
    }

    .action-btn {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.75rem 1.25rem;
        border: none;
        border-radius: 6px;
        font-size: 0.9rem;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.15s ease;
    }

    .create-meeting {
        background-color: #064B45;
        color: white;
    }

    .create-meeting:hover {
        background-color: #053c37;
    }

    .meetings-section {
        margin-top: 1rem;
    }

    .meetings-section h2 {
        font-size: 1.1rem;
        font-weight: 600;
        margin-bottom: 1rem;
        color: #333;
    }

    .empty-state {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 3rem;
        background: #fafafa;
        border-radius: 8px;
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

    @media (max-width: 640px) {
        .dashboard-container {
            padding: 0 1rem;
        }

        .header-content {
            padding: 0 1rem;
        }

        .user-info h1 {
            font-size: 1.25rem;
        }

        .empty-state {
            padding: 2rem;
        }
    }
</style>