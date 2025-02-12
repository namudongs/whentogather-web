<!-- TimeSelector.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import Button from '$lib/components/Button.svelte';
  import { format } from 'date-fns';
  import { ko } from 'date-fns/locale';

  export let startDate: string;
  export let endDate: string;
  export let duration: number;
  export let onSubmit: (selectedTimes: any[]) => void;
  export let onClose: () => void;

  let selectedTimes: { [key: string]: boolean } = {};
  let isDragging = false;
  let isSelecting = false;
  let dates: Date[] = [];
  let timeSlots = Array.from({ length: 48 }, (_, i) => {
    const hour = Math.floor(i / 2);
    const minute = i % 2 === 0 ? '00' : '30';
    return `${hour.toString().padStart(2, '0')}:${minute}`;
  });

  onMount(() => {
    const start = new Date(startDate);
    const end = new Date(endDate);
    const dateArray = [];
    let currentDate = start;

    while (currentDate <= end) {
      dateArray.push(new Date(currentDate));
      currentDate.setDate(currentDate.getDate() + 1);
    }
    dates = dateArray;
  });

  function handleMouseDown(date: string, time: string, event: MouseEvent) {
    if (event.button !== 0) return; // 왼쪽 클릭만 처리
    isDragging = true;
    isSelecting = !selectedTimes[`${date}-${time}`];
    toggleTimeSlot(date, time);
  }

  function handleMouseOver(date: string, time: string) {
    if (!isDragging) return;
    toggleTimeSlot(date, time);
  }

  function handleMouseUp() {
    isDragging = false;
  }

  function toggleTimeSlot(date: string, time: string) {
    const key = `${date}-${time}`;
    selectedTimes[key] = isSelecting;
    selectedTimes = selectedTimes; // Svelte 반응성을 위한 재할당
  }

  function formatDate(date: Date) {
    return format(date, 'M월 d일 (E)', { locale: ko });
  }

  function handleSubmit() {
    const selectedTimeArray = Object.entries(selectedTimes)
      .filter(([_, isSelected]) => isSelected)
      .map(([timeString]) => {
        const [date, time] = timeString.split('-');
        return { date, time };
      });
    
    onSubmit(selectedTimeArray);
  }
</script>

<div class="time-selector"
  on:mouseup={handleMouseUp}
  on:mouseleave={handleMouseUp}
>
  <div class="grid-container">
    <!-- 시간 레이블 -->
    <div class="time-labels">
      <div class="corner-cell"></div>
      {#each timeSlots as time}
        <div class="time-label">{time}</div>
      {/each}
    </div>

    <!-- 날짜별 그리드 -->
    {#each dates as date}
      <div class="date-row">
        <div class="date-label">{formatDate(date)}</div>
        {#each timeSlots as time}
          <div
            class="time-cell"
            class:selected={selectedTimes[`${format(date, 'yyyy-MM-dd')}-${time}`]}
            on:mousedown={(e) => handleMouseDown(format(date, 'yyyy-MM-dd'), time, e)}
            on:mouseover={() => handleMouseOver(format(date, 'yyyy-MM-dd'), time)}
          ></div>
        {/each}
      </div>
    {/each}
  </div>

  <div class="form-actions">
    <Button
      variant="outline"
      on:click={onClose}
      flex={1}
    >취소</Button>
    <Button
      variant="primary"
      on:click={handleSubmit}
      flex={2}
    >시간 저장하기</Button>
  </div>
</div>

<style>
  .time-selector {
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    user-select: none;
  }

  .grid-container {
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
  }

  .time-labels {
    display: flex;
    position: sticky;
    top: 0;
    background: white;
    z-index: 1;
    border-bottom: 1px solid #e2e8f0;
  }

  .corner-cell {
    width: 100px;
    flex-shrink: 0;
    border-right: 1px solid #e2e8f0;
  }

  .time-label {
    width: 60px;
    height: 30px;
    flex-shrink: 0;
    font-size: 0.75rem;
    color: #4a5568;
    display: flex;
    align-items: center;
    justify-content: center;
    border-right: 1px solid #e2e8f0;
  }

  .date-row {
    display: flex;
    border-bottom: 1px solid #e2e8f0;
  }

  .date-label {
    width: 100px;
    height: 40px;
    flex-shrink: 0;
    font-size: 0.875rem;
    color: #4a5568;
    display: flex;
    align-items: center;
    padding: 0 0.5rem;
    border-right: 1px solid #e2e8f0;
    background: white;
    position: sticky;
    left: 0;
  }

  .time-cell {
    width: 60px;
    height: 40px;
    flex-shrink: 0;
    border-right: 1px solid #e2e8f0;
    background: #f7fafc;
    cursor: pointer;
    transition: background-color 0.1s ease;
  }

  .time-cell:hover {
    background: #e2e8f0;
  }

  .time-cell.selected {
    background: #064b45;
  }

  .form-actions {
    display: flex;
    gap: 1rem;
    margin-top: 0.5rem;
  }
</style>
