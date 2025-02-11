<script>
  export let size = 48;
</script>

<div class="logo-container">
  <svg class="logo" width={size} height={size} viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
    <circle cx="24" cy="24" r="20" fill="#064B45"/>
    <path d="M24 12V24L32 28" stroke="white" stroke-width="3" stroke-linecap="round"/>
  </svg>
  <h1 class="logo-text font-extrabold">언제모여</h1>
</div>

<style>
  .logo-container {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .logo {
    width: var(--size, 48px);
    height: var(--size, 48px);
  }

  .logo-text {
    font-size: 1.5rem;
    color: #064B45;
    margin: 0;
  }
</style>
