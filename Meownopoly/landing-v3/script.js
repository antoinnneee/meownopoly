const scenarios = {
  trap: {
    prompt: "« Ajoute une plaque piégée qui propulse le prochain joueur. »",
    status: "Validé par le MJ · matérialisé"
  },
  river: {
    prompt: "« Fais traverser une rivière et double les loyers sur ses rives. »",
    status: "Règle amendée · pont ajouté"
  },
  moon: {
    prompt: "« Passe le plateau en gravité lunaire pendant trois minutes. »",
    status: "Simulation réussie · monde synchronisé"
  }
};

const world = document.querySelector("[data-world]");
const promptText = document.querySelector("[data-prompt-text]");
const statusText = document.querySelector("[data-status]");
const scenarioButtons = document.querySelectorAll("[data-scenario]");

scenarioButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const scenario = button.dataset.scenario;
    world.dataset.world = scenario;
    promptText.textContent = scenarios[scenario].prompt;
    statusText.textContent = scenarios[scenario].status;
    scenarioButtons.forEach((item) => {
      const active = item === button;
      item.classList.toggle("is-active", active);
      item.setAttribute("aria-pressed", String(active));
    });
  });
});

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const reveals = document.querySelectorAll(".reveal");

if (reducedMotion || !("IntersectionObserver" in window)) {
  reveals.forEach((element) => element.classList.add("is-visible"));
} else {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });
  reveals.forEach((element) => observer.observe(element));
}

const header = document.querySelector("[data-header]");
const updateHeader = () => header.classList.toggle("is-scrolled", window.scrollY > 80);
window.addEventListener("scroll", updateHeader, { passive: true });
updateHeader();
