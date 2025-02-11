<script>
  export let size = 'normal'; // 'normal' | 'small' | 'large'
</script>

<div class="spinner-container">
  <div class="spinner {size}"></div>
</div>

<style>
  .spinner-container {
    display: flex;
    justify-content: center;
    align-items: center;
  }

  .spinner {
    width: 1.5rem;
    height: 1.5rem;
    border: 2px solid #f3f3f3;
    border-top: 2px solid #064B45;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  .spinner.small {
    width: 1rem;
    height: 1rem;
    border-width: 1.5px;
  }

  .spinner.large {
    width: 2.5rem;
    height: 2.5rem;
    border-width: 3px;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
</style>
