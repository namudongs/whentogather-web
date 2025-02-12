<!-- +page.svelte -->
<script lang="ts">
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';
  import { onMount } from 'svelte';
  import { format } from 'date-fns';
  import { ko } from 'date-fns/locale/ko';
  import MannamResponse from '$lib/components/mannam/MannamResponse.svelte';

  let moim: any = null;
  let mannam: any = null;
  let responses: any[] = [];
  let loading = true;
  let error = '';

  async function loadData() {
    try {
      // Load moim data
      const { data: moimData, error: moimError } = await supabase
        .from('moims')
        .select('*, moim_participants(*)')
        .eq('invite_code', $page.params.invite_code)
        .single();

      if (moimError) throw moimError;
      moim = moimData;

      // Load mannam data
      const { data: mannamData, error: mannamError } = await supabase
        .from('mannams')
        .select('*')
        .eq('id', $page.params.mannam_id)
        .single();

      if (mannamError) throw mannamError;
      mannam = mannamData;

      // Load responses with user information
      const { data: responseData, error: responseError } = await supabase
        .from('mannam_responses')
        .select(`
          *,
          profiles:user_id (
            full_name,
            avatar_url
          )
        `)
        .eq('mannam_id', mannam.id);

      if (responseError) throw responseError;
      responses = responseData;
    } catch (err) {
      error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
    } finally {
      loading = false;
    }
  }

  async function handleStatusUpdate(newStatus: string) {
    try {
      const { error: err } = await supabase
        .from('mannams')
        .update({ status: newStatus })
        .eq('id', mannam.id);

      if (err) throw err;

      mannam.status = newStatus;
    } catch (err) {
      error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
    }
  }

  onMount(loadData);

  $: isCreator = moim?.creator_id === $user?.id;
  $: formattedStartDate = mannam?.start_date ? format(new Date(mannam.start_date), 'PPP', { locale: ko }) : '';
  $: formattedEndDate = mannam?.end_date ? format(new Date(mannam.end_date), 'PPP', { locale: ko }) : '';

  $: availableCount = responses.filter(r => r.status === 'available').length;
  $: unavailableCount = responses.filter(r => r.status === 'unavailable').length;
  $: maybeCount = responses.filter(r => r.status === 'maybe').length;
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
    <div class="bg-white rounded-lg shadow-md p-6 mb-8">
      <div class="flex justify-between items-start mb-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">{mannam.title}</h1>
          {#if mannam.description}
            <p class="mt-2 text-gray-600">{mannam.description}</p>
          {/if}
        </div>
        {#if isCreator && mannam.status === 'pending'}
          <div class="flex space-x-2">
            <button
              on:click={() => handleStatusUpdate('confirmed')}
              class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600 transition-colors"
            >
              확정하기
            </button>
            <button
              on:click={() => handleStatusUpdate('cancelled')}
              class="bg-red-500 text-white px-4 py-2 rounded hover:bg-red-600 transition-colors"
            >
              취소하기
            </button>
          </div>
        {/if}
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="space-y-4">
          <div class="flex items-center text-gray-600">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
            <span>{formattedStartDate} ~ {formattedEndDate}</span>
          </div>
          <div class="flex items-center text-gray-600">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span>소요 시간: {mannam.duration}시간</span>
          </div>
        </div>

        <div class="bg-gray-50 p-4 rounded-lg">
          <h3 class="font-semibold text-gray-700 mb-2">응답 현황</h3>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-green-600">참여 가능</span>
              <span class="font-medium">{availableCount}명</span>
            </div>
            <div class="flex justify-between">
              <span class="text-red-600">참여 불가능</span>
              <span class="font-medium">{unavailableCount}명</span>
            </div>
            <div class="flex justify-between">
              <span class="text-yellow-600">미정</span>
              <span class="font-medium">{maybeCount}명</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
      <div>
        <h2 class="text-2xl font-bold mb-4">나의 응답</h2>
        <MannamResponse mannamId={mannam.id} />
      </div>

      <div>
        <h2 class="text-2xl font-bold mb-4">모든 응답</h2>
        <div class="bg-white rounded-lg shadow-md p-6">
          {#if responses.length > 0}
            <div class="space-y-4">
              {#each responses as response}
                <div class="flex items-start space-x-4 py-3 border-b last:border-b-0">
                  <div class="flex-1">
                    <div class="flex items-center">
                      <span class="font-medium">{response.profiles.full_name}</span>
                      <span class="ml-2 px-2 py-1 text-sm rounded-full
                        {response.status === 'available' ? 'bg-green-100 text-green-800' :
                        response.status === 'unavailable' ? 'bg-red-100 text-red-800' :
                        'bg-yellow-100 text-yellow-800'}">
                        {response.status === 'available' ? '참여 가능' :
                         response.status === 'unavailable' ? '참여 불가능' : '미정'}
                      </span>
                    </div>
                    {#if response.comment}
                      <p class="mt-1 text-gray-600 text-sm">{response.comment}</p>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          {:else}
            <p class="text-gray-500 text-center">아직 응답이 없습니다.</p>
          {/if}
        </div>
      </div>
    </div>
  {/if}
</div>
