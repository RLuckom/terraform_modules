/* https://github.com/dev-ggaurav/responsive-hamburger-tutorial */
const hamburger = document.querySelector(".hamburger");
const navMenu = document.querySelector(".nav-menu");

hamburger.addEventListener("click", mobileMenu);

function mobileMenu() {
  hamburger.classList.toggle("active");
  navMenu.classList.toggle("active");
}

const navLink = document.querySelectorAll(".nav-link");

navLink.forEach(n => n.addEventListener("click", closeMenu));

window.addEventListener('load', () => {
  try {
    const name = new RegExp(`https://${window.location.host}/plugins/(.*)/(.*).html`).exec(window.location.href)[1]
    if (name) {
      const s = document.createElement('span')
      s.innerText = '::'
      s.className = "location-link-sep"
      document.getElementById('location-links').appendChild(s)
      const a = document.createElement('a')
      a.href = `/plugins/${name}/index.html`
      a.className = 'nav-logo'
      a.innerText = name
      document.getElementById('location-links').appendChild(a)
    }
  } catch(e) {}
})

function closeMenu() {
  hamburger.classList.remove("active");
  navMenu.classList.remove("active");
}

const appHeight = () => {
  const doc = document.documentElement
  doc.style.setProperty('--app-height', `${window.innerHeight}px`)
}
window.addEventListener('resize', appHeight)
appHeight()
