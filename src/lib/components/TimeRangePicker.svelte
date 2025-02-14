<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { clickOutside } from '$lib/utils/clickOutside';
	import BottomSheet from './BottomSheet.svelte';

	export let startTime = '00:00';
	export let endTime = '23:00';

	let showBottomSheet = false;
	let tempStartTime = startTime;
	let tempEndTime = endTime;

	// 1시간 간격으로 시간 옵션 생성 (00:00 ~ 23:00)
	const timeOptions = Array.from({ length: 24 }, (_, i) => {
		const hour = i.toString().padStart(2, '0');
		return `${hour}:00`;
	});

	function formatTime(time: string): string {
		return time;
	}

	function handleTimeSelect(time: string, isStart: boolean) {
		if (isStart) {
			tempStartTime = time;
			// 시작 시간이 종료 시간보다 늦으면 종료 시간도 자동으로 조정
			if (time >= tempEndTime) {
				const startIndex = timeOptions.indexOf(time);
				if (startIndex < timeOptions.length - 1) {
					tempEndTime = timeOptions[startIndex + 1];
				}
			}
		} else {
			if (time > tempStartTime) {
				tempEndTime = time;
			}
		}
	}

	function handleConfirm() {
		startTime = tempStartTime;
		endTime = tempEndTime;
		showBottomSheet = false;
	}

	function handleCancel() {
		tempStartTime = startTime;
		tempEndTime = endTime;
		showBottomSheet = false;
	}
</script>

<div class="time-range-picker">
	<button
		type="button"
		class="time-picker-button"
		on:click={() => (showBottomSheet = true)}
		aria-label="시간 범위 선택"
	>
		<span class="time-text">{formatTime(startTime)} ~ {formatTime(endTime)}</span>
		<svg
			class="time-icon"
			xmlns="http://www.w3.org/2000/svg"
			width="16"
			height="16"
			viewBox="0 0 24 24"
			fill="none"
			stroke="currentColor"
			stroke-width="2"
			stroke-linecap="round"
			stroke-linejoin="round"
		>
			<circle cx="12" cy="12" r="10" />
			<polyline points="12 6 12 12 16 14" />
		</svg>
	</button>
</div>

<BottomSheet show={showBottomSheet} onClose={handleCancel} title="시간 범위 선택">
	<div class="time-range-selector">
		<div class="time-column">
			<h3>시작 시간</h3>
			<div class="time-options">
				{#each timeOptions as time}
					{#if time < tempEndTime}
						<button
							type="button"
							class="time-option"
							class:selected={time === tempStartTime}
							on:click={() => handleTimeSelect(time, true)}
						>
							{formatTime(time)}
						</button>
					{/if}
				{/each}
			</div>
		</div>
		<div class="time-column">
			<h3>종료 시간</h3>
			<div class="time-options">
				{#each timeOptions as time}
					{#if time > tempStartTime}
						<button
							type="button"
							class="time-option"
							class:selected={time === tempEndTime}
							on:click={() => handleTimeSelect(time, false)}
						>
							{formatTime(time)}
						</button>
					{/if}
				{/each}
			</div>
		</div>
	</div>
	<div class="bottom-actions">
		<button type="button" class="action-button cancel" on:click={handleCancel}>취소</button>
		<button type="button" class="action-button confirm" on:click={handleConfirm}>확인</button>
	</div>
</BottomSheet>

<style>
	.time-range-picker {
		width: 100%;
		position: relative;
	}

	.time-picker-button {
		width: 100%;
		padding: 0.625rem;
		border: 1px solid #d1d5db;
		border-radius: 0.5rem;
		background: white;
		font-size: 0.875rem;
		display: flex;
		align-items: center;
		justify-content: space-between;
		cursor: pointer;
		transition: all 0.2s;
	}

	.time-picker-button:hover {
		border-color: #064b45;
	}

	.time-text {
		color: #111827;
	}

	.time-icon {
		color: #6b7280;
	}

	.time-range-selector {
		display: flex;
		gap: 1rem;
		padding: 1rem 0;
	}

	.time-column {
		flex: 1;
	}

	.time-column h3 {
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
		margin: 0 0 0.75rem 0;
	}

	.time-options {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		max-height: 300px;
		overflow-y: auto;
		padding: 0.5rem;
		background: #f9fafb;
		border-radius: 0.5rem;
	}

	.time-option {
		padding: 0.75rem;
		border: none;
		background: white;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		color: #374151;
		cursor: pointer;
		transition: all 0.2s;
		border: 1px solid transparent;
	}

	.time-option:hover {
		border-color: #064b45;
		color: #064b45;
	}

	.time-option.selected {
		background: #064b45;
		color: white;
		font-weight: 500;
	}

	.bottom-actions {
		display: flex;
		gap: 0.5rem;
		padding-top: 1rem;
		border-top: 1px solid #e5e7eb;
		margin-top: 1rem;
	}

	.action-button {
		flex: 1;
		padding: 0.75rem;
		border: none;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.action-button.cancel {
		background: #f3f4f6;
		color: #4b5563;
	}

	.action-button.cancel:hover {
		background: #e5e7eb;
	}

	.action-button.confirm {
		background: #064b45;
		color: white;
	}

	.action-button.confirm:hover {
		background: #053c37;
	}
</style> 