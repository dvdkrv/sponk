// PHALANX — small landing-page interactions
(() => {
  // ---------- Year ----------
  const yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  // ---------- Mobile nav ----------
  const nav = document.querySelector(".nav");
  const navToggle = document.querySelector(".nav-toggle");
  if (nav && navToggle) {
    navToggle.addEventListener("click", () => {
      const open = nav.classList.toggle("open");
      navToggle.setAttribute("aria-expanded", String(open));
    });
    nav.querySelectorAll("a").forEach((a) =>
      a.addEventListener("click", () => {
        nav.classList.remove("open");
        navToggle.setAttribute("aria-expanded", "false");
      })
    );
  }

  // ---------- Reveal on scroll ----------
  const revealEls = document.querySelectorAll(
    ".section, .pillar, .row, .hero-meta li"
  );
  revealEls.forEach((el) => el.classList.add("reveal"));
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add("in");
          io.unobserve(e.target);
        }
      });
    },
    { threshold: 0.12 }
  );
  revealEls.forEach((el) => io.observe(el));

  // ---------- Frontline pressure demo ----------
  const gridEl = document.querySelector(".grid-demo");
  if (gridEl) {
    const TYPES = ["t-hop", "t-spr", "t-shd", "t-cap"];
    const GLYPHS = {
      "t-hop": "Λ",
      "t-spr": "↟",
      "t-shd": "⬡",
      "t-cap": "★",
    };
    const COLS = 5;
    const ROWS = 5;

    const cells = [];
    for (let i = 0; i < COLS * ROWS; i++) {
      const c = document.createElement("div");
      c.className = "cell";
      gridEl.appendChild(c);
      cells.push(c);
    }

    const randType = () => TYPES[Math.floor(Math.random() * TYPES.length)];
    const resetCell = (cell) => {
      const t = randType();
      cell.className = "cell " + t;
      cell.textContent = GLYPHS[t];
    };

    function fill() {
      cells.forEach(resetCell);
    }

    function pressurePulse() {
      fill();
      const casualties = 3 + Math.floor(Math.random() * 5);
      const picked = new Set();
      while (picked.size < casualties) picked.add(Math.floor(Math.random() * cells.length));

      setTimeout(() => {
        picked.forEach((i) => cells[i].classList.add("match"));
      }, 450);
      setTimeout(() => {
        picked.forEach((i) => cells[i].classList.add("gone"));
      }, 1000);
      setTimeout(() => {
        picked.forEach((i) => resetCell(cells[i]));
      }, 1500);
    }

    let timer;
    const start = () => {
      pressurePulse();
      timer = setInterval(pressurePulse, 2400);
    };
    const stop = () => clearInterval(timer);

    // start when visible
    const gio = new IntersectionObserver(
      (entries) =>
        entries.forEach((e) => (e.isIntersecting ? start() : stop())),
      { threshold: 0.25 }
    );
    gio.observe(gridEl);
  }

  // ---------- Newsletter form ----------
  const form = document.getElementById("signup-form");
  const status = document.getElementById("form-status");
  if (form && status) {
    form.addEventListener("submit", (e) => {
      e.preventDefault();
      const email = /** @type {HTMLInputElement} */ (
        document.getElementById("email")
      ).value.trim();
      const valid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
      status.classList.remove("error");
      if (!valid) {
        status.textContent = "That doesn't look like a valid email, soldier.";
        status.classList.add("error");
        return;
      }
      // No backend yet — store locally so the UI feels real.
      try {
        const list = JSON.parse(localStorage.getItem("phalanx:signups") || "[]");
        list.push({ email, at: Date.now() });
        localStorage.setItem("phalanx:signups", JSON.stringify(list));
      } catch {}
      status.textContent = "Enlisted. The 300 will summon you when ready.";
      form.reset();
    });
  }
})();
