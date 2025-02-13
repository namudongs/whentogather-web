<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { fade } from 'svelte/transition';
	import { clickOutside } from '$lib/utils/clickOutside';

	export let startDate: string = '';
	export let endDate: string = '';
	export let maxRange: number = 7;
	export let placeholder = '날짜를 선택하세요';

	const dispatch = createEventDispatcher();

	let isOpen = false;
	let calendarContainer: HTMLDivElement;
	let hoveredDate: Date | null = null;
	let currentMonth = new Date();

	$: selectedStartDate = startDate ? new Date(startDate) : null;
	$: selectedEndDate = endDate ? new Date(endDate) : null;

	function getDaysInMonth(date: Date) {
		const year = date.getFullYear();
		const month = date.getMonth();
		const daysInMonth = new Date(year, month + 1, 0).getDate();
		const firstDayOfMonth = new Date(year, month, 1).getDay();
		
		const days = [];
		// 이전 달의 날짜들
		for (let i = 0; i < firstDayOfMonth; i++) {
			const prevDate = new Date(year, month, -firstDayOfMonth + i + 1);
			days.push({ date: prevDate, isCurrentMonth: false });
		}
		
		// 현재 달의 날짜들
		for (let i = 1; i <= daysInMonth; i++) {
			const currentDate = new Date(year, month, i);
			days.push({ date: currentDate, isCurrentMonth: true });
		}
		
		// 다음 달의 날짜들
		const remainingDays = 42 - days.length; // 6주 x 7일 = 42
		for (let i = 1; i <= remainingDays; i++) {
			const nextDate = new Date(year, month + 1, i);
			days.push({ date: nextDate, isCurrentMonth: false });
		}
		
		return days;
	}

	function formatDate(date: Date) {
		const year = date.getFullYear();
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const day = String(date.getDate()).padStart(2, '0');
		return `${year}-${month}-${day}`;
	}

	function isDateInRange(date: Date) {
		if (!selectedStartDate) return false;
		if (!selectedEndDate && !hoveredDate) return false;
		const endDateToUse = selectedEndDate || hoveredDate;
		if (!endDateToUse) return false;
		
		const isStartOrEndDate = date.toDateString() === selectedStartDate.toDateString() || 
			date.toDateString() === endDateToUse.toDateString();
		if (isStartOrEndDate) return false;
		
		return date > selectedStartDate && date < endDateToUse;
	}

	function isDateDisabled(date: Date): boolean {
		if (!selectedStartDate || selectedEndDate) return false;
		
		const diffDays = Math.floor(Math.abs(date.getTime() - selectedStartDate.getTime()) / (1000 * 60 * 60 * 24));
		return diffDays > maxRange;
	}

	function handleDateClick(date: Date) {
		if (!selectedStartDate || (selectedStartDate && selectedEndDate)) {
			// 새로운 범위 시작
			startDate = formatDate(date);
			endDate = '';
			selectedStartDate = date;
			selectedEndDate = null;
		} else {
			// 범위 완성
			if (date < selectedStartDate) {
				// 선택한 날짜가 시작일보다 이전인 경우
				startDate = formatDate(date);
				endDate = formatDate(selectedStartDate);
				selectedEndDate = selectedStartDate;
				selectedStartDate = date;
			} else {
				const diffDays = Math.floor((date.getTime() - selectedStartDate.getTime()) / (1000 * 60 * 60 * 24));
				
				if (diffDays > maxRange) {
					// maxRange를 초과하는 경우
					const maxEndDate = new Date(selectedStartDate);
					maxEndDate.setDate(maxEndDate.getDate() + maxRange);
					endDate = formatDate(maxEndDate);
					selectedEndDate = maxEndDate;
				} else {
					endDate = formatDate(date);
					selectedEndDate = date;
				}
			}
			isOpen = false;
		}
	}

	function handleMouseEnter(date: Date) {
		if (selectedStartDate && !selectedEndDate) {
			hoveredDate = date;
		}
	}

	function handleMouseLeave() {
		hoveredDate = null;
	}

	function nextMonth() {
		currentMonth = new Date(currentMonth.setMonth(currentMonth.getMonth() + 1));
	}

	function prevMonth() {
		currentMonth = new Date(currentMonth.setMonth(currentMonth.getMonth() - 1));
	}

	function handleClickOutside() {
		isOpen = false;
	}

	const WEEKDAYS = ['일', '월', '화', '수', '목', '금', '토'];
	const MONTHS = [
		'1월', '2월', '3월', '4월', '5월', '6월',
		'7월', '8월', '9월', '10월', '11월', '12월'
	];
</script>

<div class="date-range-picker">
	<button
		type="button"
		class="date-picker-input"
		on:click={() => (isOpen = !isOpen)}
		aria-label="날짜 선택"
	>
		{#if startDate && endDate}
			{new Date(startDate).toLocaleDateString()} - {new Date(endDate).toLocaleDateString()}
		{:else}
			{placeholder}
		{/if}
		<svg
			class="calendar-icon"
			xmlns="http://www.w3.org/2000/svg"
			width="24"
			height="24"
			viewBox="0 0 24 24"
			fill="none"
			stroke="currentColor"
			stroke-width="2"
			stroke-linecap="round"
			stroke-linejoin="round"
		>
			<rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
			<line x1="16" y1="2" x2="16" y2="6" />
			<line x1="8" y1="2" x2="8" y2="6" />
			<line x1="3" y1="10" x2="21" y2="10" />
		</svg>
	</button>

	{#if isOpen}
		<div
			class="calendar-container"
			bind:this={calendarContainer}
			transition:fade={{ duration: 100 }}
		>
			<div class="calendar-header">
				<!-- svelte-ignore a11y_consider_explicit_label -->
				<button type="button" class="month-nav-btn" on:click={prevMonth}>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						width="20"
						height="20"
						viewBox="0 0 24 24"
						fill="none"
						stroke="currentColor"
						stroke-width="2"
						stroke-linecap="round"
						stroke-linejoin="round"
					>
						<path d="M15 18l-6-6 6-6" />
					</svg>
				</button>
				<span class="current-month">
					{MONTHS[currentMonth.getMonth()]} {currentMonth.getFullYear()}
				</span>
				<!-- svelte-ignore a11y_consider_explicit_label -->
				<button type="button" class="month-nav-btn" on:click={nextMonth}>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						width="20"
						height="20"
						viewBox="0 0 24 24"
						fill="none"
						stroke="currentColor"
						stroke-width="2"
						stroke-linecap="round"
						stroke-linejoin="round"
					>
						<path d="M9 18l6-6-6-6" />
					</svg>
				</button>
			</div>

			<div class="calendar-grid">
				{#each WEEKDAYS as day}
					<div class="weekday">{day}</div>
				{/each}

				{#each getDaysInMonth(currentMonth) as { date, isCurrentMonth }}
					<button
						type="button"
						class="day"
						class:today={date.toDateString() === new Date().toDateString()}
						class:selected={date.toDateString() === selectedStartDate?.toDateString() ||
							date.toDateString() === selectedEndDate?.toDateString()}
						class:in-range={isDateInRange(date)}
						class:other-month={!isCurrentMonth}
						class:disabled={!isCurrentMonth || isDateDisabled(date)}
						on:click={() => handleDateClick(date)}
						on:mouseenter={() => handleMouseEnter(date)}
						on:mouseleave={handleMouseLeave}
						disabled={!isCurrentMonth || isDateDisabled(date)}
					>
						{date.getDate()}
					</button>
				{/each}
			</div>
		</div>
	{/if}
</div>

<style>
	.date-range-picker {
		position: relative;
		width: 100%;
	}

	.date-picker-input {
		width: 100%;
		padding: 0.625rem;
		border: 1px solid #d1d5db;
		border-radius: 0.5rem;
		background: white;
		font-size: 0.875rem;
		color: #374151;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: space-between;
		transition: all 0.2s;
	}

	.date-picker-input:hover {
		border-color: #9ca3af;
	}

	.date-picker-input:focus {
		outline: none;
		border-color: #064b45;
		box-shadow: 0 0 0 2px rgba(6, 75, 69, 0.1);
	}

	.calendar-icon {
		color: #6b7280;
	}

	.calendar-container {
		position: absolute;
		top: calc(100% + 0.5rem);
		left: 0;
		z-index: 50;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
		padding: 1rem;
		width: 300px;
	}

	.calendar-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1rem;
	}

	.month-nav-btn {
		background: none;
		border: none;
		padding: 0.25rem;
		cursor: pointer;
		color: #6b7280;
		border-radius: 0.375rem;
	}

	.month-nav-btn:hover {
		background-color: #f3f4f6;
		color: #111827;
	}

	.current-month {
		font-weight: 500;
		color: #111827;
	}

	.calendar-grid {
		display: grid;
		grid-template-columns: repeat(7, 1fr);
		gap: 0.25rem;
	}

	.weekday {
		text-align: center;
		font-size: 0.75rem;
		font-weight: 500;
		color: #6b7280;
		padding: 0.5rem 0;
	}

	.day {
		aspect-ratio: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.875rem;
		border: none;
		background: none;
		cursor: pointer;
		color: #064b45;
		border-radius: 0.375rem;
		position: relative;
	}

	.day:hover:not(:disabled):not(.selected) {
		background-color: rgba(6, 75, 69, 0.15);
		color: #064b45;
	}

	.day.today {
		font-weight: 600;
	}

	.day.selected {
		background-color: #064b45;
		color: white;
		font-weight: 500;
	}

	.day.in-range {
		background-color: rgba(6, 75, 69, 0.082);
	}

	.day.other-month {
		color: #9ca3af;
	}

	.day.disabled {
		opacity: 0.5;
		cursor: not-allowed;
		text-decoration: line-through;
		color: #9ca3af;
	}

	.day.disabled:hover {
		background: none;
	}
</style>
