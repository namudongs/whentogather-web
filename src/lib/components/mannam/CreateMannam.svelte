<!-- CreateMannam.svelte -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';

  export let moimId: string;
  
  const dispatch = createEventDispatcher();

  let title = '';
  let description = '';
  let startDate = '';
  let endDate = '';
  let duration = 1;
  let error = '';
  let loading = false;

  async function handleSubmit() {
    loading = true;
    error = '';

    try {
      const { data: mannam, error: err } = await supabase
        .from('mannams')
        .insert({
          moim_id: moimId,
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

      dispatch('created', mannam);
      
      // Reset form
      title = '';
      description = '';
      startDate = '';
      endDate = '';
      duration = 1;
    } catch (err) {
      error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
    } finally {
      loading = false;
    }
  }
</script>

<div class="bg-white rounded-lg shadow-md p-6">
  <h2 class="text-2xl font-bold mb-6">새로운 만남 만들기</h2>

  <form on:submit|preventDefault={handleSubmit} class="space-y-4">
    <div>
      <label for="title" class="block text-sm font-medium text-gray-700">제목</label>
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

    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
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

    {#if error}
      <div class="text-red-600 text-sm">{error}</div>
    {/if}

    <div class="flex justify-end">
      <button
        type="submit"
        disabled={loading}
        class="inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
      >
        {loading ? '생성 중...' : '만남 생성하기'}
      </button>
    </div>
  </form>
</div>
