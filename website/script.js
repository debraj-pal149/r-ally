const coachButtons = document.querySelectorAll("[data-coach]");
const coachName = document.querySelector("#coach-name");
const coachLine = document.querySelector("#coach-line");
const coachPlay = document.querySelector(".coach-play");
const playLabel = document.querySelector("#play-label");
const playTime = document.querySelector(".play-time");
const coachSection = document.querySelector(".coach-section");
const coachAudio = typeof Audio === "undefined" ? null : new Audio();

function resetCoachAudio(status = "PLAY") {
  if (coachAudio) {
    coachAudio.pause();
    coachAudio.currentTime = 0;
  }
  coachPlay?.classList.remove("playing");
  coachSection?.classList.remove("is-speaking");
  if (playTime) playTime.textContent = status;
}

coachButtons.forEach((button) => {
  button.addEventListener("click", () => {
    resetCoachAudio();
    coachButtons.forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    coachName.textContent = button.dataset.coach.toUpperCase();
    coachLine.textContent = button.dataset.line;
    coachPlay.dataset.audio = button.dataset.audio;
    coachPlay.setAttribute("aria-label", `Play ${button.dataset.coach} voice sample`);
    playLabel.textContent = `Hear ${button.dataset.coach}`;
  });
});

coachPlay?.addEventListener("click", async () => {
  if (!coachAudio) return;
  const src = `assets/audio/${coachPlay.dataset.audio}.mp3`;
  const sameSample = coachAudio.getAttribute("src") === src;
  if (sameSample && !coachAudio.paused) {
    coachAudio.pause();
    coachPlay.classList.remove("playing");
    coachSection.classList.remove("is-speaking");
    playTime.textContent = "PAUSED";
    return;
  }
  if (!sameSample) {
    coachAudio.src = src;
  }
  try {
    await coachAudio.play();
    coachPlay.classList.add("playing");
    coachSection.classList.add("is-speaking");
  } catch {
    resetCoachAudio("TRY AGAIN");
  }
});

coachAudio?.addEventListener("timeupdate", () => {
  if (coachAudio.paused || !Number.isFinite(coachAudio.duration)) return;
  playTime.textContent = `${Math.max(0, Math.ceil(coachAudio.duration - coachAudio.currentTime))}s`;
});

coachAudio?.addEventListener("ended", () => resetCoachAudio("REPLAY"));

const stateButtons = [...document.querySelectorAll("[data-state]")];
const stage = document.querySelector(".state-stage");
const stateContent = {
  holding: {
    time: "18:42",
    kicker: "PACE IS STEADY",
    title: "THE COACH IS<br>STILL THERE.",
    copy: "Live coaching, pace cues and steady motivation keep you moving.",
    coach: "THE WHIP · ON PACE",
    line: "Easy shoulders. Keep that stride honest.",
  },
  fading: {
    time: "24:16",
    kicker: "EFFORT IS SLIPPING",
    title: "R·ALLY SEES<br>THE CHANGE.",
    copy: "Your pace slips and your stride gets rough. R·ALLY catches it while you are still moving.",
    coach: "THE WHIP · FADE SPOTTED",
    line: "I know what this is. Stay with me.",
  },
  rally: {
    time: "24:31",
    kicker: "RALLY MOMENT",
    title: "A FIRMER<br>PUSH LANDS.",
    copy: "Your coach steps in with a stronger push, then checks how you respond.",
    coach: "THE WHIP · IN YOUR CORNER",
    line: "Ten honest steps. Take them now.",
  },
};

function showRunState(button) {
  if (!stage) return;
  if (stage.dataset.currentState === button.dataset.state) return;
  const content = stateContent[button.dataset.state];
  const prevIndex = stateButtons.findIndex((item) => item.classList.contains("active"));
  const nextIndex = stateButtons.indexOf(button);
  stateButtons.forEach((item) => {
    const selected = item === button;
    item.classList.toggle("active", selected);
    item.setAttribute("aria-selected", String(selected));
  });
  stage.dataset.currentState = button.dataset.state;
  stage.dataset.slide = nextIndex >= prevIndex ? "forward" : "back";
  document.querySelector("#stage-time").textContent = content.time;
  document.querySelector("#stage-kicker").textContent = content.kicker;
  document.querySelector("#stage-title").innerHTML = content.title;
  document.querySelector("#stage-copy").textContent = content.copy;
  document.querySelector("#stage-coach").textContent = content.coach;
  document.querySelector("#stage-line").textContent = content.line;
  if (!reduceMotion) {
    stage.classList.remove("is-transitioning");
    void stage.offsetWidth;
    stage.classList.add("is-transitioning");
  }
}

stateButtons.forEach((button, index) => {
  button.addEventListener("click", () => showRunState(button));
  button.addEventListener("keydown", (event) => {
    if (!["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) return;
    event.preventDefault();
    const step = event.key === "ArrowLeft" || event.key === "ArrowUp" ? -1 : 1;
    const next = stateButtons[(index + step + stateButtons.length) % stateButtons.length];
    next.focus();
    showRunState(next);
  });
});

const progress = document.querySelector(".scroll-progress");
const siteHeader = document.querySelector(".site-header");
const heroPhoto = document.querySelector(".hero-photo");
const heroPhone = document.querySelector(".hero-phone");
const signalDemo = document.querySelector(".signal-demo");
const signalSticky = document.querySelector(".signal-sticky");
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
let scrollFrame = null;

function paintScroll() {
  const max = Math.max(1, document.documentElement.scrollHeight - innerHeight);
  const amount = Math.min(1, Math.max(0, scrollY / max));
  if (progress) progress.style.transform = `scaleX(${amount})`;
  siteHeader?.classList.toggle("scrolled", scrollY > 30);
  if (!reduceMotion && scrollY < innerHeight * 1.2) {
    heroPhoto?.style.setProperty("--hero-shift", `${scrollY * 0.08}px`);
    heroPhone?.style.setProperty("--phone-shift", `${scrollY * -0.035}px`);
  }
  if (signalDemo && signalSticky && stateButtons.length) {
    const rect = signalDemo.getBoundingClientRect();
    const travel = Math.max(1, signalDemo.offsetHeight - signalSticky.offsetHeight);
    const storyProgress = Math.min(1, Math.max(0, (88 - rect.top) / travel));
    const stateIndex = Math.min(stateButtons.length - 1, Math.floor(storyProgress * stateButtons.length));
    showRunState(stateButtons[stateIndex]);
  }
  scrollFrame = null;
}

addEventListener("scroll", () => {
  if (scrollFrame) return;
  scrollFrame = requestAnimationFrame(paintScroll);
}, { passive: true });
paintScroll();

const revealItems = document.querySelectorAll(
  ".steps article, .coach-copy > *, .coach-phone, .finish-copy > *, .finish-phone, .privacy-callout > *"
);
if (!reduceMotion && "IntersectionObserver" in window) {
  document.documentElement.classList.add("motion-ready");
  revealItems.forEach((item, index) => {
    item.classList.add("reveal-item");
    item.style.setProperty("--reveal-delay", `${(index % 3) * 75}ms`);
  });
  const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("in-view");
      revealObserver.unobserve(entry.target);
    });
  }, { threshold: 0.15 });
  revealItems.forEach((item) => revealObserver.observe(item));
}

document.querySelectorAll('a[aria-disabled="true"]').forEach((link) => {
  link.addEventListener("click", (event) => event.preventDefault());
});

document.querySelector("#year").textContent = new Date().getFullYear();
