<!-- +page.svelte -->
<script lang="ts">
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';
  import MannamCard from '$lib/components/mannam/MannamCard.svelte';
  import CreateMannam from '$lib/components/mannam/CreateMannam.svelte';
  import { onMount } from 'svelte';

  let moim: any = null;
  let mannams: any[] = [];
  let loading = true;
  let error = '';
  let showCreateForm = false;

  async function loadMoim() {
    const { data, error: err } = await supabase
      .from('moims')
      .select('*, moim_participants(*)')
      .eq('invite_code', $page.params.invite_code)
      .single();

    if (err) {
      error = err.message;
      return;
    }

    moim = data;
  }

  async function loadMannams() {
    if (!moim) return;

    const { data, error: err } = await supabase
      .from('mannams')
      .select('*')
      .eq('moim_id', moim.id)
      .order('created_at', { ascending: false });

    if (err) {
      error = err.message;
      return;
    }

    mannams = data;
  }

  async function handleMannamCreated(event: CustomEvent) {
    showCreateForm = false;
    await loadMannams();
  }

  onMount(async () => {
    await loadMoim();
    await loadMannams();
    loading = false;
  });

  $: isCreator = moim?.creator_id === $user?.id;
</script>

<div class="max-w-4xl mx-auto px-4 py-8">
  {#if loading}
    <div class="text-center py-8">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto"></div>
    </div>
  {:else if error}
    <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
      {error}
    </div>
  {:else}
    <div class="mb-8">
      <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold text-gray-900">{moim.title} - 만남 일정</h1>
        {#if isCreator}
          <button
            on:click={() => showCreateForm = !showCreateForm}
            class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 transition-colors"
          >
            {showCreateForm ? '만남 생성 취소' : '새로운 만남 만들기'}
          </button>
        {/if}
      </div>
      {#if moim.description}
        <p class="mt-2 text-gray-600">{moim.description}</p>
      {/if}
    </div>

    {#if showCreateForm}
      <div class="mb-8">
        <CreateMannam
          moimId={moim.id}
          on:created={handleMannamCreated}
        />
      </div>
    {/if}

    {#if mannams.length > 0}
      <div class="space-y-6">
        {#each mannams as mannam (mannam.id)}
          <MannamCard {mannam} />
        {/each}
      </div>
    {:else}
      <div class="text-center py-8 text-gray-500">
        아직 만남이 없습니다.
        {#if isCreator}
          <br />
          위 버튼을 눌러 첫 만남을 만들어보세요!
        {/if}
      </div>
    {/if}
  {/if}
</div>
