// The server owns values and forms. This only fits decorative ducts to the cards.
(() => {
  if (window.ductCalcEquipmentInitialized) return;
  window.ductCalcEquipmentInitialized = true;
  let network, wires, blower;
  function drawMobileWye(base, hub, cx) {
    const bottom = hub.y - base.y + hub.height * .04;
    const stemHalf = hub.width * .24;
    const neck = bottom - 20;
    const ends = ['heating','cooling'].map(mode => {
      const card = network.querySelector(`[data-equipment-mode="${mode}"]`);
      const bounds = card.getBoundingClientRect();
      const port = card.querySelector('.port').getBoundingClientRect();
      const x = port.x-base.x+port.width/2;
      return {
        outer:mode === 'heating' ? x-13 : x+13,
        inner:mode === 'heating' ? bounds.right-base.x-8 : bounds.left-base.x+8,
        y:port.y-base.y+port.height/2,
        color:mode === 'heating' ? 'var(--heating)' : 'var(--cooling)'
      };
    });
    const [left,right] = ends;
    const fork = Math.max(left.y,right.y) + (neck-Math.max(left.y,right.y))*.55;
    const shape = `M${cx-stemHalf} ${bottom} V${neck}
      Q${cx-stemHalf} ${neck-9} ${cx-stemHalf-8} ${neck-18}
      L${left.outer} ${left.y+6} V${left.y} H${left.inner} V${left.y+6}
      L${cx-5} ${fork-10} Q${cx} ${fork-6} ${cx+5} ${fork-10}
      L${right.inner} ${right.y+6} V${right.y} H${right.outer} V${right.y+6}
      L${cx+stemHalf+8} ${neck-18}
      Q${cx+stemHalf} ${neck-9} ${cx+stemHalf} ${neck} V${bottom} Z`;
    let markup = `<path class="plenum mobile-wye" d="${shape}"/>`;
    markup += `<path class="duct-seam" d="M${cx-stemHalf} ${bottom-7} H${cx+stemHalf}"/>`;
    for (const end of ends) markup += `<rect x="${Math.min(end.outer,end.inner)-2}" y="${end.y}" width="${Math.abs(end.inner-end.outer)+4}" height="7" rx="1" fill="var(--bg)" stroke="${end.color}" stroke-width="1.5"/>`;
    wires.innerHTML = markup;
  }
  function drawDuctwork(base, hub, cx, mobile) {
    if (mobile) {
      drawMobileWye(base,hub,cx);
      return;
    }
    const bottom = hub.y - base.y + hub.height * .04;
    const top = 62;
    const half = 36;
    const baseHalf = hub.width * .24;
    const branchWidth = 42;
    const runY = top + 4 + branchWidth / 2;
    const upperSlope = Math.tan(Math.PI / 6);
    const lowerSlope = Math.tan(Math.PI / 4);
    const openingHeight = branchWidth * 1.4;
    const transitionLength = (openingHeight - branchWidth) / (lowerSlope - upperSlope);
    const openingTop = runY - branchWidth / 2 + transitionLength * upperSlope;
    const openingBottom = runY + branchWidth / 2 + transitionLength * lowerSlope;
    let markup = '';
    for (const [mode, sign] of [['heating',-1], ['cooling',1]]) {
      const card = network.querySelector(`[data-equipment-mode="${mode}"]`);
      const port = card.querySelector('.port').getBoundingClientRect();
      const ex = port.x - base.x + port.width / 2;
      const ey = port.y - base.y + port.height / 2;
      const sx = cx + sign * half;
      const shoulder = sx + sign * transitionLength;
      const elbow = 20;
      const path = `M${shoulder} ${runY} H${ex - sign * elbow} Q${ex} ${runY} ${ex} ${runY + elbow} V${ey}`;
      markup += `<path class="duct-edge" stroke-width="${branchWidth + 2}" d="${path}"/><path class="duct-face" stroke-width="${branchWidth}" d="${path}"/>`;
      // Straight 30° / 45° edges give the plenum opening 1.4 times the duct height.
      // Extend those slopes beneath the plenum to hide the end cap.
      const transition = `M${sx-sign*2} ${openingTop+2*upperSlope}
        L${shoulder} ${runY-branchWidth/2}
        V${runY+branchWidth/2}
        L${sx-sign*2} ${openingBottom+2*lowerSlope} Z`;
      markup += `<path class="plenum takeoff-transition" d="${transition}"/>`;
      const seamX = (shoulder + ex - sign * elbow) / 2;
      markup += `<path class="duct-seam" d="M${seamX} ${runY - branchWidth/2} V${runY + branchWidth/2}"/>`;
      const color = mode === 'heating' ? 'var(--heating)' : 'var(--cooling)';
      markup += `<rect x="${ex - branchWidth/2 - 2}" y="${ey - 8}" width="${branchWidth + 4}" height="8" rx="1" fill="var(--bg)" stroke="${color}" stroke-width="1.5"/>`;
    }
    const taperY = bottom - 42;
    markup += `<path class="plenum" d="M${cx-half} ${top} H${cx+half} V${taperY} L${cx+baseHalf} ${bottom} H${cx-baseHalf} L${cx-half} ${taperY} Z"/>`;
    markup += `<path class="plenum-side" d="M${cx+half-6} ${top+6} L${cx+half} ${top} V${taperY} L${cx+baseHalf} ${bottom} H${cx+baseHalf-6} L${cx+half-6} ${taperY} Z"/>`;
    markup += `<path class="duct-seam" d="M${cx-half} ${top+6} H${cx+half-6} M${cx-half} ${taperY} H${cx+half}"/>`;
    markup += `<path class="duct-seam" d="M${cx-half} ${openingBottom+12} H${cx+half-6}"/>`;
    wires.innerHTML = markup;
  }

  function draw() {
    if (!network?.isConnected) return;
    const base = network.getBoundingClientRect();
    if (!base.width || !base.height) return;
    wires.setAttribute('viewBox', `0 0 ${base.width} ${base.height}`);
    const hub = blower.getBoundingClientRect();
    drawDuctwork(base, hub, hub.x-base.x+hub.width/2, base.width <= 560);
  }
  const resize = typeof ResizeObserver === 'function' ? new ResizeObserver(draw) : null;
  function restore() {
    resize?.disconnect();
    network = document.querySelector('.equipment-network');
    wires = network?.querySelector('.airflow-lines');
    blower = network?.querySelector('.blower');
    if (!wires || !blower) return;
    resize?.observe(network);
    network.querySelectorAll('.mode-card').forEach(card => resize?.observe(card));
    draw();
  }
  document.addEventListener('close', event => {
    const form = event.target.querySelector?.('form[data-equipment-form]');
    form?.reset();
    form?.querySelectorAll('[aria-invalid]').forEach(input => input.removeAttribute('aria-invalid'));
  }, true);
  document.addEventListener('toggle', event => {
    if (event.target.matches('.equipment-canvas')) draw();
  }, true);
  for (const name of ['DOMContentLoaded', 'htmx:afterSwap', 'htmx:afterSettle', 'htmx:historyRestore']) {
    document.addEventListener(name, restore);
  }
  window.addEventListener('resize', draw);
  restore();
})();
