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

  // ---------- Match-3 phalanx grid demo ----------
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
    function fill() {
      cells.forEach((c) => {
        const t = randType();
        c.className = "cell " + t;
        c.textContent = GLYPHS[t];
      });
    }

    // pick a random row and force-match it for the demo
    function stagedMatch() {
      fill();
      // pick row, set 3-4 same type
      const row = Math.floor(Math.random() * ROWS);
      const type = randType();
      const len = 3 + Math.floor(Math.random() * 2);
      const start = Math.floor(Math.random() * (COLS - len + 1));
      for (let x = 0; x < len; x++) {
        const i = row * COLS + (start + x);
        cells[i].className = "cell " + type;
        cells[i].textContent = GLYPHS[type];
      }
      // play sequence
      setTimeout(() => {
        for (let x = 0; x < len; x++) {
          const i = row * COLS + (start + x);
          cells[i].classList.add("match");
        }
      }, 600);
      setTimeout(() => {
        for (let x = 0; x < len; x++) {
          const i = row * COLS + (start + x);
          cells[i].classList.add("gone");
        }
      }, 1400);
    }

    let timer;
    const start = () => {
      stagedMatch();
      timer = setInterval(stagedMatch, 2600);
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
