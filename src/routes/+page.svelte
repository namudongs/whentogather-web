<script lang="ts">
    import { supabase } from '$lib/supabaseClient';
    import { goto } from '$app/navigation';
    import { onMount } from 'svelte';
    import { loadMoims } from '$lib/stores/moim';
    import Spinner from '$lib/components/Spinner.svelte';

    let isLoading = true;

    onMount(async () => {
        try {
            const { data } = await supabase.auth.getSession();
            if (data.session) {
                // 대시보드로 이동하기 전에 데이터를 미리 로드
                await loadMoims();
                goto('/dashboard');
            } else {
                goto('/login');
            }
        } finally {
            isLoading = false;
        }
    });
</script>

<svelte:head>
    <title>언제모여 - 모임 시간 정하기</title>
    <meta name="description" content="모임 시간을 쉽게 정하세요" />
</svelte:head>

<div class="loading">
    {#if isLoading}
        <Spinner size="large" />
    {/if}
</div>

<style>
    .loading {
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100vh;
        background-color: white;
    }
</style>