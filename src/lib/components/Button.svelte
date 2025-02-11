<script lang="ts">
  import Spinner from './Spinner.svelte';

  export let variant: 'primary' | 'outline' = 'primary';
  export let type: 'button' | 'submit' = 'button';
  export let disabled = false;
  export let loading = false;
  export let flex: number | undefined = undefined;
</script>

<button
  {type}
  {disabled}
  class="button {variant}"
  style={flex ? `flex: ${flex}` : ''}
  on:click
>
  {#if loading}
    <Spinner size="small" />
  {/if}
  <slot />
</button>

<style>
  .button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 0.875rem;
    border-radius: 8px;
    font-size: 0.95rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .button:disabled {
    opacity: 0.7;
    cursor: not-allowed;
  }

  /* Primary variant */
  .primary {
    background: linear-gradient(135deg, #064B45 0%, #0a786e 100%);
    color: white;
  }

  .primary:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(6, 75, 69, 0.2);
  }

  /* Outline variant */
  .outline {
    background: white;
    color: #86888c;
    border: 1px solid #e5e7eb;
  }

  .outline:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.05);
    border-color: #d1d5db;
    color: #374151;
  }
</style>
