(() => {
  const slides = [...document.querySelectorAll('.slide')];
  const counter = document.querySelector('#slideCounter');
  const progress = document.querySelector('#progressBar');
  const previous = document.querySelector('#prevButton');
  const next = document.querySelector('#nextButton');
  const dotNav = document.querySelector('#dotNav');
  const overview = document.querySelector('#overviewDialog');
  const overviewList = document.querySelector('#overviewList');
  let current = 0;

  const pad = value => String(value).padStart(2, '0');

  function render(index, updateHash = true) {
    current = Math.max(0, Math.min(index, slides.length - 1));
    slides.forEach((slide, position) => {
      slide.classList.toggle('is-active', position === current);
      slide.classList.toggle('is-before', position < current);
      slide.setAttribute('aria-hidden', position === current ? 'false' : 'true');
      if (position === current) slide.scrollTop = 0;
    });
    [...dotNav.children].forEach((dot, position) => {
      dot.setAttribute('aria-current', position === current ? 'true' : 'false');
    });
    counter.textContent = `${pad(current + 1)} / ${pad(slides.length)}`;
    progress.style.width = `${((current + 1) / slides.length) * 100}%`;
    previous.disabled = current === 0;
    next.disabled = current === slides.length - 1;
    document.title = `${slides[current].dataset.title} — Interface V3 IA`;
    if (updateHash) history.replaceState(null, '', `#slide-${current + 1}`);
  }

  slides.forEach((slide, index) => {
    const dot = document.createElement('button');
    dot.type = 'button';
    dot.setAttribute('aria-label', `${index + 1}. ${slide.dataset.title}`);
    dot.addEventListener('click', () => render(index));
    dotNav.append(dot);

    const item = document.createElement('li');
    const jump = document.createElement('button');
    jump.type = 'button';
    jump.textContent = slide.dataset.title;
    jump.addEventListener('click', () => {
      overview.close();
      render(index);
    });
    item.append(jump);
    overviewList.append(item);
  });

  previous.addEventListener('click', () => render(current - 1));
  next.addEventListener('click', () => render(current + 1));
  document.querySelectorAll('[data-next]').forEach(button => button.addEventListener('click', () => render(current + 1)));
  document.querySelectorAll('[data-go]').forEach(button => button.addEventListener('click', () => render(Number(button.dataset.go) - 1)));
  document.querySelector('#overviewButton').addEventListener('click', () => overview.showModal());
  document.querySelector('#closeOverview').addEventListener('click', () => overview.close());
  overview.addEventListener('click', event => {
    if (event.target === overview) overview.close();
  });

  document.addEventListener('keydown', event => {
    if (overview.open && event.key !== 'Escape') return;
    if (['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement?.tagName)) return;
    if (event.key === 'ArrowRight' || event.key === 'PageDown' || event.key === ' ') {
      event.preventDefault(); render(current + 1);
    } else if (event.key === 'ArrowLeft' || event.key === 'PageUp') {
      event.preventDefault(); render(current - 1);
    } else if (event.key === 'Home') {
      event.preventDefault(); render(0);
    } else if (event.key === 'End') {
      event.preventDefault(); render(slides.length - 1);
    }
  });

  window.addEventListener('hashchange', () => {
    const match = location.hash.match(/^#slide-(\d+)$/);
    if (match) render(Number(match[1]) - 1, false);
  });

  const initial = location.hash.match(/^#slide-(\d+)$/);
  render(initial ? Number(initial[1]) - 1 : 0, false);
})();
