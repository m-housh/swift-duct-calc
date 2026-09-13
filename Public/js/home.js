(() => {
  const preview = document.querySelector("[data-preview-panel]")?.closest(".workspace-demo");
  if (preview) {
    const steps = [...preview.querySelectorAll("[data-preview-step]")];
    const panels = [...preview.querySelectorAll("[data-preview-panel]")];
    const playback = preview.querySelector(".demo-playback");
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    const frames = [...preview.querySelectorAll(".demo-app-frame")];
    const systemDark = window.matchMedia("(prefers-color-scheme: dark)");
    const updateFrameTheme = () => {
      const theme = systemDark.matches ? "dark" : "light";
      frames.forEach(frame => {
        if (frame.contentDocument?.documentElement) {
          frame.contentDocument.documentElement.dataset.theme = theme;
        }
      });
    };
    frames.forEach(frame => frame.addEventListener("load", updateFrameTheme));
    systemDark.addEventListener("change", updateFrameTheme);
    updateFrameTheme();

    const stage = preview.querySelector(".demo-stage");
    const resize = () => {
      if (stage.clientWidth) preview.style.setProperty("--preview-scale", stage.clientWidth / 1200);
    };
    if (window.ResizeObserver) new ResizeObserver(resize).observe(stage);
    else window.addEventListener("resize", resize);
    resize();

    let current = 0;
    let autoplay = !reducedMotion.matches;
    let visible = !window.IntersectionObserver;
    let timer;

    function schedule() {
      window.clearTimeout(timer);
      const playing = autoplay && visible && !document.hidden;
      preview.dataset.playing = String(playing);
      playback.textContent = autoplay ? "Pause preview" : "Play preview";
      if (playing) {
        timer = window.setTimeout(() => show((current + 1) % panels.length), 3000);
      }
    }

    function show(index) {
      current = index;
      steps.forEach((step, i) => step.setAttribute("aria-pressed", String(i === current)));
      panels.forEach((panel, i) => panel.setAttribute("aria-hidden", String(i !== current)));
      schedule();
    }

    steps.forEach((step, index) => {
      step.disabled = false;
      step.addEventListener("click", () => {
        autoplay = false;
        show(index);
      });
    });
    playback.disabled = false;
    playback.addEventListener("click", () => {
      autoplay = !autoplay;
      schedule();
    });
    preview.addEventListener("focusin", (event) => {
      if (event.target !== playback) { autoplay = false; schedule(); }
    });
    document.addEventListener("visibilitychange", schedule);
    reducedMotion.addEventListener("change", () => {
      if (reducedMotion.matches) autoplay = false;
      schedule();
    });
    if (window.IntersectionObserver) {
      new IntersectionObserver(([entry]) => {
        visible = entry.isIntersecting;
        schedule();
      }, { threshold: 0.2 }).observe(preview);
    }
    schedule();
  }

})();
