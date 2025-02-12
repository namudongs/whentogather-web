<!-- MannamResponse.svelte -->
<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';
  import { type PostgrestError } from '@supabase/supabase-js';

  export let mannamId: string;
  
  let response = '';
  let comment = '';
  let loading = false;
  let error = '';
  let currentResponse: any = null;

  async function loadCurrentResponse() {
    if (!$user) return;

    const { data, error: err } = await supabase
      .from('mannam_responses')
      .select('*')
      .eq('mannam_id', mannamId)
      .eq('user_id', $user.id)
      .single();

    if (data) {
      currentResponse = data;
      response = data.status;
      comment = data.comment || '';
    }
  }

  async function handleSubmit() {
    if (!$user) return;
    
    loading = true;
    error = '';

    try {
      const responseData = {
        mannam_id: mannamId,
        user_id: $user.id,
        status: response,
        comment
      };

      let query;
      if (currentResponse) {
        query = supabase
          .from('mannam_responses')
          .update(responseData)
          .eq('id', currentResponse.id);
      } else {
        query = supabase
          .from('mannam_responses')
          .insert(responseData);
      }

      const { error: err } = await query;
      if (err) throw err as PostgrestError;

      // Reload current response
      await loadCurrentResponse();
    } catch (err: unknown) {
      error = err instanceof Error ? err.message : 'An unknown error occurred';
    } finally {
      loading = false;
    }
  }

  $: if ($user) {
    loadCurrentResponse();
  }
</script>

<div class="bg-white rounded-lg shadow-md p-6">
  <h3 class="text-xl font-semibold mb-4">나의 참여 가능 여부</h3>

  <form on:submit|preventDefault={handleSubmit} class="space-y-4">
    <div class="space-y-2">
      <div class="flex items-center">
        <input
          type="radio"
          id="available"
          bind:group={response}
          value="available"
          class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300"
        />
        <label for="available" class="ml-2 text-gray-700">참여 가능</label>
      </div>

      <div class="flex items-center">
        <input
          type="radio"
          id="unavailable"
          bind:group={response}
          value="unavailable"
          class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300"
        />
        <label for="unavailable" class="ml-2 text-gray-700">참여 불가능</label>
      </div>

      <div class="flex items-center">
        <input
          type="radio"
          id="maybe"
          bind:group={response}
          value="maybe"
          class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300"
        />
        <label for="maybe" class="ml-2 text-gray-700">미정</label>
      </div>
    </div>

    <div>
      <label for="comment" class="block text-sm font-medium text-gray-700">코멘트 (선택사항)</label>
      <textarea
        id="comment"
        bind:value={comment}
        rows="3"
        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        placeholder="추가로 전달하고 싶은 내용이 있다면 적어주세요"
      ></textarea>
    </div>

    {#if error}
      <div class="text-red-600 text-sm">{error}</div>
    {/if}

    <div class="flex justify-end">
      <button
        type="submit"
        disabled={loading || !response}
        class="inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
      >
        {loading ? '저장 중...' : '응답 저장하기'}
      </button>
    </div>
  </form>
</div>
