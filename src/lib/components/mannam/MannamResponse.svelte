<!-- MannamResponse.svelte -->
<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';
  import { type PostgrestError } from '@supabase/supabase-js';
  import Button from '$lib/components/Button.svelte';
  import TimeGrid from './TimeGrid.svelte';
  import Spinner from '$lib/components/Spinner.svelte';

  export let mannamId: string;
  export let onClose: () => void;
  
  let loading = false;
  let error = '';
  let currentResponse: any = null;
  let mannam: any = null;
  let selectedSlots: { date: string; slot: number }[] = [];
  let saving = false;

  async function loadData() {
    if (!$user) return;

    try {
      // 만남 정보 로드
      const { data: mannamData, error: mannamError } = await supabase
        .from('mannams')
        .select('*')
        .eq('id', mannamId)
        .single();

      if (mannamError) throw mannamError;
      mannam = mannamData;

      // 현재 응답 로드
      const { data: responseData, error: responseError } = await supabase
        .from('mannam_responses')
        .select('*')
        .eq('mannam_id', mannamId)
        .eq('user_id', $user.id)
        .single();

      if (responseData) {
        currentResponse = responseData;
        selectedSlots = responseData.available_slots || [];
      }
    } catch (err) {
      console.error('데이터 로드 중 에러:', err);
      error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
    }
  }

  async function handleSubmit() {
    if (!$user) return;
    
    saving = true;
    error = '';

    try {
      const responseData = {
        mannam_id: mannamId,
        user_id: $user.id,
        available_slots: selectedSlots
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

      onClose();
    } catch (err: unknown) {
      error = err instanceof Error ? err.message : 'An unknown error occurred';
    } finally {
      saving = false;
    }
  }

  function handleSlotsChange(event: CustomEvent) {
    selectedSlots = event.detail.slots;
  }

  $: if ($user) {
    loadData();
  }
</script>

<div class="fullscreen-cover">
  <div class="container">
    <div class="header">
      <button class="close-button" on:click={onClose}>
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <line x1="18" y1="6" x2="6" y2="18"></line>
          <line x1="6" y1="6" x2="18" y2="18"></line>
        </svg>
      </button>
      <h1 class="title">시간 조율하기</h1>
    </div>

    <div class="content">
      {#if error}
        <div class="error-message">{error}</div>
      {/if}

      {#if mannam?.status === 'pending'}
        <div class="grid-container">
          <TimeGrid
            startDate={mannam.start_date}
            endDate={mannam.end_date}
            timeRange={mannam.time_range}
            timeSlotMinutes={mannam.time_slot_minutes}
            selectedSlots={selectedSlots}
            on:change={handleSlotsChange}
          />

          <div class="actions">
            <Button on:click={handleSubmit} loading={saving}>
              응답 제출
            </Button>
          </div>
        </div>
      {:else}
        <div class="info-message">
          이미 확정된 만남은 시간을 조율할 수 없습니다.
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  .fullscreen-cover {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.4);
    z-index: 1000;
    display: flex;
    align-items: flex-start;
    justify-content: center;
  }

  .container {
    width: 100%;
    max-width: 800px;
    height: 100%;
    background: white;
    display: flex;
    flex-direction: column;
  }

  .header {
    display: flex;
    align-items: center;
    padding: 1rem;
    border-bottom: 1px solid #e2e8f0;
  }

  .close-button {
    background: none;
    border: none;
    padding: 0.5rem;
    cursor: pointer;
    color: #4a5568;
  }

  .title {
    margin: 0 0 0 1rem;
    font-size: 1.25rem;
    font-weight: 600;
  }

  .content {
    flex: 1;
    overflow-y: auto;
    padding: 1rem;
  }

  .grid-container {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .actions {
    display: flex;
    justify-content: flex-end;
    padding: 1rem;
    border-top: 1px solid #e2e8f0;
  }

  .error-message {
    color: #e53e3e;
    padding: 1rem;
    background: #fff5f5;
    border-radius: 0.375rem;
    margin-bottom: 1rem;
  }

  .info-message {
    color: #4a5568;
    padding: 1rem;
    background: #f7fafc;
    border-radius: 0.375rem;
    text-align: center;
  }
  
</style>