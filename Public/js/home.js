(() => {
  const root = document.documentElement;
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const applyMotion = () => {
    root.classList.toggle('motion-enabled', !reducedMotion.matches);
    root.classList.toggle('motion-paused', reducedMotion.matches);
  };
  reducedMotion.addEventListener('change', applyMotion);
  applyMotion();

  if (!('IntersectionObserver' in window)) return;
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.remove('is-waiting');
        observer.unobserve(entry.target);
      }
    }
  }, { threshold: 0.12 });
  for (const element of document.querySelectorAll('.reveal')) {
    element.classList.add('is-waiting');
    observer.observe(element);
  }
})();
