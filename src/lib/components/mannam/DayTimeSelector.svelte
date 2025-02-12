<!-- DayTimeSelector.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import Button from '$lib/components/Button.svelte';
  import { format } from 'date-fns';
  import { ko } from 'date-fns/locale';
  import Spinner from '$lib/components/Spinner.svelte';

  export let date: Date;
  export let selectedTimes: { [key: string]: boolean } = {};
  export let onNext: () => void;
  export let onSave: () => void;
  export let isLastDay: boolean;
  export let saving = false;
  export let preferredTimes: { start: string; end: string } | null = null;

  // 시간대 생성
  let timeSlots = Array.from({ length: 48 }, (_, i) => {
    const hour = Math.floor(i / 2);
    const minute = i % 2 === 0 ? '00' : '30';
    return `${hour.toString().padStart(2, '0')}:${minute}`;
  });

  // 선호 시간대 안에 있는지 확인
  function isInPreferredTime(time: string): boolean {
    if (!preferredTimes) return true;
    const [hour, minute] = time.split(':').map(Number);
    const [startHour, startMinute] = preferredTimes.start.split(':').map(Number);
    const [endHour, endMinute] = preferredTimes.end.split(':').map(Number);
    
    const timeValue = hour * 60 + minute;
    const startValue = startHour * 60 + startMinute;
    const endValue = endHour * 60 + endMinute;
    
    return timeValue >= startValue && timeValue <= endValue;
  }

  let isDragging = false;
  let isSelecting = false;
  let containerRef: HTMLDivElement;
  let scrollPosition = 0;

  function handleMouseDown(time: string, event: MouseEvent) {
    if (event.button !== 0) return;
    isDragging = true;
    isSelecting = !selectedTimes[`${format(date, 'yyyy-MM-dd')}-${time}`];
    toggleTimeSlot(time);
  }

  function handleMouseOver(time: string) {
    if (!isDragging) return;
    toggleTimeSlot(time);
  }

  function handleMouseUp() {
    isDragging = false;
  }

  function toggleTimeSlot(time: string) {
    const key = `${format(date, 'yyyy-MM-dd')}-${time}`;
    selectedTimes[key] = isSelecting;
    selectedTimes = selectedTimes; // Svelte 반응성 트리거
  }



  onMount(() => {
    // 아침 8시 위치로 초기 스크롤
    if (containerRef) {
      const initialScroll = (8 * 2) * 40; // 8시 * 30분단위 * 셀높이
      containerRef.scrollTo(0, initialScroll);
      scrollPosition = initialScroll;
    }
  });
</script>

<div class="day-selector">
  <div class="date-header">
    {format(date, 'M월 d일 (E)', { locale: ko })}
  </div>

  <div 
    class="time-grid" 
    bind:this={containerRef}
    on:mouseleave={handleMouseUp}
    on:mouseup={handleMouseUp}
  >
    {#each timeSlots as time}
      <div
        class="time-slot"
        class:selected={selectedTimes[`${format(date, 'yyyy-MM-dd')}-${time}`]}
        class:disabled={!isInPreferredTime(time)}
        on:mousedown={(e) => !isInPreferredTime(time) ? null : handleMouseDown(time, e)}
        on:mouseover={() => !isInPreferredTime(time) ? null : handleMouseOver(time)}
      >
        <div class="time-label">{time}</div>
      </div>
    {/each}
  </div>

  <div class="actions">
    <Button
      variant="primary"
      on:click={isLastDay ? onSave : onNext}
      flex={1}
      disabled={saving}
    >
      {#if saving}
        <Spinner size="small" />
      {:else}
        {isLastDay ? '응답 저장하기' : '다음 날짜 →'}
      {/if}
    </Button>
  </div>
</div>

<style>
  .day-selector {
    display: flex;
    flex-direction: column;
    height: 100%;
  }

  .date-header {
    font-size: 0.875rem;
    font-weight: 500;
    color: #1a202c;
    text-align: center;
    padding: 0.75rem;
    border-bottom: 1px solid #e2e8f0;
  }

  .time-grid {
    flex: 1;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
  }

  .time-slot {
    display: flex;
    align-items: center;
    height: 40px;
    padding: 0 1rem;
    border-bottom: 1px solid #e2e8f0;
    user-select: none;
    cursor: pointer;
  }

  .time-slot:last-child {
    border-bottom: none;
  }

  .time-label {
    font-size: 0.875rem;
    color: #4a5568;
  }

  .time-slot.selected {
    background-color: #064b45;
  }

  .time-slot.selected .time-label {
    color: white;
  }

  .time-slot.disabled {
    opacity: 0.5;
    cursor: not-allowed;
    background-color: #f7fafc;
  }

  .actions {
    padding: 0.75rem;
    border-top: 1px solid #e2e8f0;
  }

  /* 스크롤바 숨기기 */
  .time-grid::-webkit-scrollbar {
    display: none;
  }
</style>
