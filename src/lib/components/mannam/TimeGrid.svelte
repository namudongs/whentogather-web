<!-- TimeGrid.svelte -->
<script lang="ts">
  import { format, eachDayOfInterval, parseISO, addMinutes } from 'date-fns';
  import { ko } from 'date-fns/locale';
  import { createEventDispatcher } from 'svelte';

  export let startDate: string;
  export let endDate: string;
  export let timeRange: { start: string; end: string };
  export let timeSlotMinutes: number;
  export let selectedSlots: { date: string; slot: number }[] = [];
  export let readOnly = false;
  export let heatmapData: { [key: string]: number } = {}; // slot key -> 참여자 수

  const dispatch = createEventDispatcher();

  // 날짜 범위 계산
  $: dates = eachDayOfInterval({
    start: parseISO(startDate),
    end: parseISO(endDate)
  });

  // 시간 슬롯 계산
  $: timeSlots = (() => {
    const slots = [];
    const startMinutes = parseInt(timeRange.start.split(':')[0]) * 60 + parseInt(timeRange.start.split(':')[1]);
    const endMinutes = parseInt(timeRange.end.split(':')[0]) * 60 + parseInt(timeRange.end.split(':')[1]);
    
    for (let minutes = startMinutes; minutes < endMinutes; minutes += timeSlotMinutes) {
      const time = addMinutes(new Date().setHours(0, 0, 0, 0), minutes);
      slots.push({
        minutes,
        label: format(time, 'HH:mm')
      });
    }
    return slots;
  })();

  // 슬롯 키 생성 함수
  function getSlotKey(date: string, slotIndex: number): string {
    return `${date}-${slotIndex}`;
  }

  // 슬롯 선택 여부 확인
  function isSlotSelected(date: string, slotIndex: number): boolean {
    return selectedSlots.some(slot => slot.date === date && slot.slot === slotIndex);
  }

  // 히트맵 색상 계산
  function getHeatmapColor(count: number, max: number): string {
    if (count === 0) return 'transparent';
    // 키컬러: #064B45 (진한 청록색)
    const intensity = Math.min((count / max), 1);
    // RGB 값: 6, 75, 69
    return `rgba(6, 75, 69, ${intensity * 0.35})`; // 0.35를 곱해서 50% 더 연하게 설정
  }

  // 마우스 드래그 관련 상태
  let isDragging = false;
  let isSelecting = false; // true면 선택, false면 해제

  function handleMouseDown(date: string, slotIndex: number) {
    if (readOnly) return;
    
    isDragging = true;
    isSelecting = !isSlotSelected(date, slotIndex);
    toggleSlot(date, slotIndex);
  }

  function handleMouseEnter(date: string, slotIndex: number) {
    if (!isDragging || readOnly) return;
    toggleSlot(date, slotIndex);
  }

  function handleMouseUp() {
    isDragging = false;
  }

  function toggleSlot(date: string, slotIndex: number) {
    const isSelected = isSlotSelected(date, slotIndex);
    
    if (isSelecting === isSelected) return;

    let newSelectedSlots = [...selectedSlots];
    
    if (isSelecting) {
      newSelectedSlots.push({ date, slot: slotIndex });
    } else {
      newSelectedSlots = newSelectedSlots.filter(
        slot => !(slot.date === date && slot.slot === slotIndex)
      );
    }

    dispatch('change', { slots: newSelectedSlots });
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="time-grid-container" on:mouseup={handleMouseUp} on:mouseleave={handleMouseUp}>
  <!-- 날짜 헤더 -->
  <div class="time-grid-header">
    <div class="time-label-column"></div>
    {#each dates as date}
      <div class="date-header">
        <div class="date-label">
          {format(date, 'M.d', { locale: ko })}
          <span class="day-label">{format(date, 'E', { locale: ko })}</span>
        </div>
      </div>
    {/each}
  </div>

  <!-- 시간 그리드 -->
  <div class="time-grid">
    <!-- 시간 레이블 -->
    <div class="time-label-column">
      {#each timeSlots as slot}
        <div class="time-label">{slot.label}</div>
      {/each}
    </div>

    <!-- 시간 슬롯 -->
    {#each dates as date}
      <div class="date-column">
        {#each timeSlots as slot, slotIndex}
          {@const dateStr = format(date, 'yyyy-MM-dd')}
          {@const slotKey = getSlotKey(dateStr, slotIndex)}
          <div
            class="time-slot {isSlotSelected(dateStr, slotIndex) ? 'selected' : ''}"
            style="{readOnly ? `background-color: ${getHeatmapColor(heatmapData[slotKey] || 0, Math.max(...Object.values(heatmapData), 1))}` : ''}"
            on:mousedown={() => handleMouseDown(dateStr, slotIndex)}
            on:mouseenter={() => handleMouseEnter(dateStr, slotIndex)}
          ></div>
        {/each}
      </div>
    {/each}
  </div>
</div>

<style>
  .time-grid-container {
    width: 100%;
    max-width: 500px;
    margin: 0 auto;
    overflow-x: hidden;
    user-select: none;
    background: white;
    border-radius: 12px;
    box-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);
  }

  .time-grid-header {
    display: flex;
    border-bottom: 1px solid #e5e7eb;
    position: sticky;
    top: 0;
    background-color: white;
    z-index: 10;
  }

  .time-label-column {
    width: 3rem;
    flex-shrink: 0;
    position: sticky;
    left: 0;
    background-color: white;
    z-index: 20;
  }

  .date-header {
    flex: 1;
    padding: 0.5rem 0.25rem;
    text-align: center;
    border-left: 1px solid #e5e7eb;
  }

  .date-label {
    font-weight: 500;
  }

  .day-label {
    font-size: 0.875rem;
    color: #6b7280;
    margin-left: 0.25rem;
  }

  .time-grid {
    display: flex;
    position: relative;
    width: 100%;
  }

  .time-label {
    height: 2rem;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    padding-right: 0.5rem;
    font-size: 0.875rem;
    color: #6b7280;
  }

  .date-column {
    flex: 1;
    border-left: 1px solid #e5e7eb;
  }

  .time-slot {
    height: 2rem;
    border-bottom: 1px solid #f3f4f6;
    cursor: pointer;
    transition: background-color 0.1s;
  }

  .time-slot:hover {
    background-color: #dbeafe;
  }

  .time-slot.selected {
    background-color: #064B45;
    opacity: 0.9;
  }

  .time-slot:hover:not(.selected) {
    background-color: rgba(6, 75, 69, 0.1);
  }


</style>
