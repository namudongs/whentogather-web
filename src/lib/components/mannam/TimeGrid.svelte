<!-- TimeGrid.svelte -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { format, addDays } from 'date-fns';
  import { ko } from 'date-fns/locale/ko';
  import { onMount } from 'svelte';

  export let startDate: string;
  export let endDate: string;
  export let timeRange: { start: string; end: string } = { start: '09:00', end: '21:00' };
  export let timeSlotMinutes: number = 30;
  export let heatmapData: { [key: string]: number } = {};
  export let readOnly: boolean = true;
  export let confirmedSlots: { date: string; slot: string }[] = [];
  export let selectedSlots: { date: string; slot: string }[] = [];

  const dispatch = createEventDispatcher();

  let dates: Date[] = [];
  let timeSlots: string[] = [];
  let isDragging = false;
  let dragStartValue = false;
  let isMouseDown = false;
  let gridElement: HTMLElement;

  $: {
    // 날짜 배열 생성
    const start = new Date(startDate);
    const end = new Date(endDate);
    dates = [];
    let current = start;
    while (current <= end) {
      dates.push(new Date(current));
      current = addDays(current, 1);
    }

    // 시간 슬롯 배열 생성
    const [startHour, startMinute] = timeRange.start.split(':').map(Number);
    const [endHour, endMinute] = timeRange.end.split(':').map(Number);
    const startMinutes = startHour * 60 + startMinute;
    const endMinutes = endHour * 60 + endMinute;
    timeSlots = [];

    for (let minutes = startMinutes; minutes < endMinutes; minutes += timeSlotMinutes) {
      const hour = Math.floor(minutes / 60);
      const minute = minutes % 60;
      timeSlots.push(
        `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`
      );
    }
  }

  function handleSlotClick(e: Event, date: Date, slot: string) {
    e.preventDefault();
    e.stopPropagation();
    if (readOnly || isDragging) return;

    const formattedDate = format(date, 'yyyy-MM-dd');
    const slotData = { date: formattedDate, slot };
    const index = selectedSlots.findIndex(
      (s) => s.date === formattedDate && s.slot === slot
    );

    if (index === -1) {
      selectedSlots = [...selectedSlots, slotData];
    } else {
      selectedSlots = selectedSlots.filter((_, i) => i !== index);
    }

    dispatch('change', { slots: selectedSlots });
  }

  function handleDragStart(e: Event, date: Date, slot: string) {
    e.preventDefault();
    e.stopPropagation();
    if (readOnly) return;
    
    isDragging = true;
    isMouseDown = true;
    const formattedDate = format(date, 'yyyy-MM-dd');
    dragStartValue = !selectedSlots.some(
      (s) => s.date === formattedDate && s.slot === slot
    );
  }

  function handleDragMove(date: Date, slot: string) {
    if (!isMouseDown || !isDragging || readOnly) return;

    const formattedDate = format(date, 'yyyy-MM-dd');
    const slotData = { date: formattedDate, slot };
    const isSelected = selectedSlots.some(
      (s) => s.date === formattedDate && s.slot === slot
    );

    if (dragStartValue && !isSelected) {
      selectedSlots = [...selectedSlots, slotData];
      dispatch('change', { slots: selectedSlots });
    } else if (!dragStartValue && isSelected) {
      selectedSlots = selectedSlots.filter(
        (s) => !(s.date === formattedDate && s.slot === slot)
      );
      dispatch('change', { slots: selectedSlots });
    }
  }

  function handleDragEnd(e: Event) {
    e.preventDefault();
    e.stopPropagation();
    isDragging = false;
    isMouseDown = false;
  }

  function handleGlobalMouseUp(e: MouseEvent) {
    if (isMouseDown) {
      handleDragEnd(e);
    }
  }

  function handleGlobalTouchEnd(e: TouchEvent) {
    if (isMouseDown) {
      handleDragEnd(e);
    }
  }

  function findSlotFromPoint(x: number, y: number) {
    if (!gridElement) return null;
    const element = document.elementFromPoint(x, y) as HTMLElement;
    if (!element?.classList.contains('time-slot')) return null;

    const dateIndex = dates.findIndex(d => format(d, 'yyyy-MM-dd') === element.dataset.date);
    const slotIndex = timeSlots.findIndex(s => s === element.dataset.slot);
    
    if (dateIndex !== -1 && slotIndex !== -1) {
      return { date: dates[dateIndex], slot: timeSlots[slotIndex] };
    }
    return null;
  }

  function handleTouchMove(e: TouchEvent) {
    e.preventDefault();
    e.stopPropagation();
    
    if (!isDragging || !isMouseDown) return;
    
    const touch = e.touches[0];
    const slot = findSlotFromPoint(touch.clientX, touch.clientY);
    if (slot) {
      handleDragMove(slot.date, slot.slot);
    }
  }

  // 전역 이벤트 리스너 설정
  $: {
    if (typeof window !== 'undefined' && !readOnly) {
      window.addEventListener('mouseup', handleGlobalMouseUp);
      window.addEventListener('touchend', handleGlobalTouchEnd);
    }
  }

  // cleanup
  onMount(() => {
    return () => {
      if (typeof window !== 'undefined') {
        window.removeEventListener('mouseup', handleGlobalMouseUp);
        window.removeEventListener('touchend', handleGlobalTouchEnd);
      }
    };
  });

  function isSlotSelected(date: Date, slot: string): boolean {
    const formattedDate = format(date, 'yyyy-MM-dd');
    return selectedSlots.some((s) => s.date === formattedDate && s.slot === slot);
  }

  function isSlotConfirmed(date: Date, slot: string): boolean {
    const formattedDate = format(date, 'yyyy-MM-dd');
    return confirmedSlots.some((s) => s.date === formattedDate && s.slot === slot);
  }

  function getHeatmapColor(count: number): string {
    if (count === 0) return 'bg-gray-50';
    const maxCount = Math.max(...Object.values(heatmapData));
    const intensity = Math.min(Math.floor((count / maxCount) * 5), 4);
    return `bg-primary-${(intensity + 1) * 100}`;
  }
</script>

<div class="time-grid" bind:this={gridElement}>
  <div class="grid-header">
    <div class="time-column-header"></div>
    {#each dates as date}
      <div class="date-column-header">
        <div class="date-label">{format(date, 'E', { locale: ko })}</div>
        <div class="date-number">{format(date, 'd')}</div>
      </div>
    {/each}
  </div>
  <div class="grid-body">
    {#each timeSlots as slot}
      <div class="time-row">
        <div class="time-label">{slot}</div>
        {#each dates as date}
          {@const formattedDate = format(date, 'yyyy-MM-dd')}
          {@const count = heatmapData[`${formattedDate}-${slot}`] || 0}
          {@const isSelected = isSlotSelected(date, slot)}
          {@const isConfirmed = isSlotConfirmed(date, slot)}
          <button
            class="time-slot"
            class:selected={isSelected}
            class:confirmed={isConfirmed}
            class:readonly={readOnly}
            class:clickable={!readOnly}
            class:has-responses={count > 0}
            class:most-responses={count === Math.max(...Object.values(heatmapData)) && count > 1}
            style="--response-count: {count};"
            on:click={(e) => handleSlotClick(e, date, slot)}
            on:mousedown={(e) => handleDragStart(e, date, slot)}
            on:mousemove={(e) => {
              if (isMouseDown) {
                handleDragMove(date, slot);
              }
            }}
            on:touchstart={(e) => handleDragStart(e, date, slot)}
            on:touchmove={handleTouchMove}
            data-date={formattedDate}
            data-slot={slot}
          >
            <div class="response-indicator" class:visible={count > 0}>
              {count}
            </div>
          </button>
        {/each}
      </div>
    {/each}
  </div>
</div>

<style>
  .time-grid {
    width: 100%;
    overflow-x: auto;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
  }

  .grid-header {
    display: grid;
    grid-template-columns: 4rem repeat(auto-fit, minmax(3rem, 1fr));
    border-bottom: 1px solid #e5e7eb;
    position: sticky;
    top: 0;
    background: white;
    z-index: 10;
  }

  .time-column-header {
    padding: 0.5rem;
    text-align: center;
    font-size: 0.75rem;
    color: #6b7280;
    border-right: 1px solid #e5e7eb;
  }

  .date-column-header {
    padding: 0.5rem;
    text-align: center;
    font-size: 0.75rem;
    color: #6b7280;
    border-right: 1px solid #e5e7eb;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .date-label {
    font-weight: 500;
  }

  .date-number {
    font-size: 0.875rem;
    color: #374151;
  }

  .grid-body {
    display: flex;
    flex-direction: column;
  }

  .time-row {
    display: grid;
    grid-template-columns: 4rem repeat(auto-fit, minmax(3rem, 1fr));
    border-bottom: 1px solid #e5e7eb;
  }

  .time-row:last-child {
    border-bottom: none;
  }

  .time-label {
    padding: 0.5rem;
    text-align: center;
    font-size: 0.75rem;
    color: #6b7280;
    border-right: 1px solid #e5e7eb;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .time-slot {
    position: relative;
    padding: 0.5rem;
    border: none;
    border-right: 1px solid #e5e7eb;
    background: none;
    cursor: pointer;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 2.5rem;
    user-select: none;
  }

  .time-slot:last-child {
    border-right: none;
  }

  .time-slot.clickable:hover {
    background-color: #f3f4f6;
  }

  .time-slot.selected {
    background-color: #064b45 !important;
  }

  .time-slot.selected .response-indicator {
    color: white !important;
  }

  .time-slot.confirmed {
    background-color: #064b45 !important;
    border: 2px solid #053c37;
  }

  .time-slot.has-responses {
    background-color: rgb(243 244 246);
  }

  .time-slot.most-responses {
    background-color: rgb(229 231 235);
  }

  .time-slot.readonly {
    cursor: default;
  }

  .time-slot:not(.readonly):active {
    background-color: #053c37 !important;
  }

  .response-indicator {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    font-size: 0.75rem;
    color: #6b7280;
    opacity: 0;
    transition: opacity 0.2s ease;
  }

  .response-indicator.visible {
    opacity: 1;
  }

  .time-slot.selected .response-indicator,
  .time-slot.confirmed .response-indicator {
    color: white;
  }

  :global(.bg-primary-100) {
    background-color: rgb(243 244 246);
  }

  :global(.bg-primary-200) {
    background-color: rgb(229 231 235);
  }

  :global(.bg-primary-300) {
    background-color: rgb(209 213 219);
  }

  :global(.bg-primary-400) {
    background-color: rgb(156 163 175);
  }

  :global(.bg-primary-500) {
    background-color: rgb(107 114 128);
  }
</style>

