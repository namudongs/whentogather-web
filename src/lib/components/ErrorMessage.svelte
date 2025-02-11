<script lang="ts">
  export let message: string;
</script>

<div class="error">
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <circle cx="12" cy="12" r="10"></circle>
    <line x1="12" y1="8" x2="12" y2="12"></line>
    <line x1="12" y1="16" x2="12.01" y2="16"></line>
  </svg>
  {message}
</div>

<style>
  .error {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem;
    background-color: #FEE2E2;
    color: #991B1B;
    border-radius: 0.375rem;
    margin: 0.5rem 0;
    font-size: 0.875rem;
  }
</style>
