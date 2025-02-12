<!-- +page.svelte -->
<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';
  import { onMount } from 'svelte';

  let moim: any = null;
  let loading = true;
  let error = '';

  // 폼 데이터
  let title = '';
  let description = '';
  let startDate = '';
  let endDate = '';
  let duration = 1;

  async function loadMoim() {
    try {
      const { data, error: err } = await supabase
        .from('moims')
        .select('*, moim_participants(*)')
        .eq('invite_code', $page.params.invite_code)
        .single();

      if (err) throw err;
      moim = data;

      // 모임 생성자가 아닌 경우 리다이렉트
      if (moim.creator_id !== $user?.id) {
        goto(`/moim/${$page.params.invite_code}/mannams`);
      }
    } catch (err) {
      error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
    } finally {
      loading = false;
    }
  }

  async function handleSubmit() {
    if (!moim || !$user) return;
    
    loading = true;
    error = '';

    try {
      const { data: mannam, error: err } = await supabase
        .from('mannams')
        .insert({
          moim_id: moim.id,
          creator_id: $user.id,
          title,
          description,
          start_date: startDate,
          end_date: endDate,
          duration,
          status: 'pending'
        })
        .select()
        .single();

      if (err) throw err;

      // 생성 성공 시 만남 상세 페이지로 이동
      goto(`/moim/${$page.params.invite_code}/mannams/${mannam.id}`);
    } catch (err) {
      error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
      loading = false;
    }
  }

  onMount(loadMoim);
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
      <div class="flex items-center justify-between">
        <h1 class="text-3xl font-bold text-gray-900">새로운 만남 만들기</h1>
        <button
          on:click={() => goto(`/moim/${$page.params.invite_code}/mannams`)}
          class="text-gray-600 hover:text-gray-900"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <p class="mt-2 text-gray-600">모임: {moim.title}</p>
    </div>

    <div class="bg-white rounded-lg shadow-md p-6">
      <form on:submit|preventDefault={handleSubmit} class="space-y-6">
        <div>
          <label for="title" class="block text-sm font-medium text-gray-700">만남 제목</label>
          <input
            type="text"
            id="title"
            bind:value={title}
            required
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            placeholder="3월 정기 모임"
          />
        </div>

        <div>
          <label for="description" class="block text-sm font-medium text-gray-700">설명</label>
          <textarea
            id="description"
            bind:value={description}
            rows="3"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            placeholder="이번 모임의 주제나 준비물 등을 적어주세요"
          ></textarea>
        </div>

        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <div>
            <label for="startDate" class="block text-sm font-medium text-gray-700">시작 날짜</label>
            <input
              type="date"
              id="startDate"
              bind:value={startDate}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            />
          </div>

          <div>
            <label for="endDate" class="block text-sm font-medium text-gray-700">종료 날짜</label>
            <input
              type="date"
              id="endDate"
              bind:value={endDate}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            />
          </div>
        </div>

        <div>
          <label for="duration" class="block text-sm font-medium text-gray-700">소요 시간 (시간)</label>
          <input
            type="number"
            id="duration"
            bind:value={duration}
            min="1"
            required
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          />
        </div>

        <div class="flex justify-end space-x-3">
          <button
            type="button"
            on:click={() => goto(`/moim/${$page.params.invite_code}/mannams`)}
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500"
          >
            취소
          </button>
          <button
            type="submit"
            disabled={loading}
            class="px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
          >
            {loading ? '생성 중...' : '만남 생성하기'}
          </button>
        </div>
      </form>
    </div>
  {/if}
</div>
