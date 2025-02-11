<script lang="ts">
  import { fade, fly } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';

  export let show = false;
  export let onClose: () => void;
  export let title = '';
  export let blurBackground = false;
</script>

{#if show}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div 
    class="bottom-sheet-overlay" 
    class:blur-background={blurBackground}
    on:click={onClose} 
    transition:fade={{ duration: 200 }}
  >
    <div 
      class="bottom-sheet" 
      on:click|stopPropagation 
      transition:fly={{ y: 200, duration: 300, easing: quintOut }}
    >
      <div class="bottom-sheet-header">
        {#if title}
          <h2>{title}</h2>
        {/if}
        <button class="close-button" on:click={onClose} aria-label="Close">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
      </div>
      <div class="bottom-sheet-content">
        <slot />
      </div>
    </div>
  </div>
{/if}

<style>
  .bottom-sheet-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: flex-end;
    justify-content: center;
    z-index: 1000;
  }

  .blur-background {
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
  }

  .bottom-sheet {
    background: white;
    width: 100%;
    max-width: 480px;
    border-radius: 1rem 1rem 0 0;
    padding: 1.5rem;
    position: relative;
    max-height: 90vh;
    overflow-y: auto;
  }

  .bottom-sheet-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .bottom-sheet-header h2 {
    font-size: 1.25rem;
    font-weight: 600;
    margin: 0;
    color: #1F2937;
  }

  .close-button {
    background: none;
    border: none;
    padding: 0.5rem;
    cursor: pointer;
    color: #6B7280;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: color 0.2s;
  }

  .close-button:hover {
    color: #1F2937;
  }

  .bottom-sheet-content {
    width: 100%;
  }

  @media (max-width: 480px) {
    .bottom-sheet {
      border-radius: 1.25rem 1.25rem 0 0;
    }
  }
</style>
