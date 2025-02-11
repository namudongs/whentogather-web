<script lang="ts">
    import { supabase } from '$lib/supabaseClient';
    import { goto } from '$app/navigation';
    import { onMount } from 'svelte';

    onMount(async () => {
        const { data } = await supabase.auth.getSession();
        if (data?.session) {
            goto('/dashboard');
        } else {
            goto('/login');
        }
    });
</script>

<div class="loading">
    <p>...</p>
</div>

<style>
    .loading {
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100vh;
    }
</style>