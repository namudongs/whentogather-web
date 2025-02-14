<script lang="ts">
	import { fade, fly } from 'svelte/transition';
	
	export let message: string;
	export let type: 'success' | 'error' | 'info' = 'success';
	export let duration: number = 3000;
	export let show: boolean = false;
	
	let timeout: NodeJS.Timeout;
	
	$: if (show) {
		if (timeout) clearTimeout(timeout);
		timeout = setTimeout(() => {
			show = false;
		}, duration);
	}
	
	function getIcon() {
		switch (type) {
			case 'success':
				return `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>`;
			case 'error':
				return `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>`;
			default:
				return `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>`;
		}
	}
</script>

{#if show}
	<div
		class="toast-container"
		in:fly={{ y: 50, duration: 300 }}
		out:fade={{ duration: 200 }}
	>
		<div class="toast {type}">
			<div class="icon" class:success={type === 'success'} class:error={type === 'error'}>
				{@html getIcon()}
			</div>
			<span class="message font-regular">{message}</span>
		</div>
	</div>
{/if}

<style>
	.toast-container {
		position: fixed;
		top: 1rem;
		left: 50%;
		transform: translateX(50%);
		z-index: 1000;
		pointer-events: none;
	}
	
	.toast {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: white;
		border-radius: 0.5rem;
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
		pointer-events: all;
	}
	
	.icon {
		display: flex;
		align-items: center;
		justify-content: center;
		color: #6b7280;
	}
	
	.icon.success {
		color: #064b45;
	}
	
	.icon.error {
		color: #ef4444;
	}
	
	.message {
		font-size: 0.875rem;
		color: #374151;
	}
</style> 