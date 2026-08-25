const header = document.querySelector('[data-header]');

const updateHeader = () => {
  header?.toggleAttribute('data-scrolled', window.scrollY > 20);
};

updateHeader();
window.addEventListener('scroll', updateHeader, { passive: true });

const reveals = document.querySelectorAll('.reveal');
if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add('is-inview');
      observer.unobserve(entry.target);
    }
  }, { rootMargin: '0px 0px -10% 0px' });
  reveals.forEach((element) => observer.observe(element));
} else {
  reveals.forEach((element) => element.classList.add('is-inview'));
}
