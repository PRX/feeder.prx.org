// Global ARIA sanitizer: fix common misspelled ARIA attributes and keep observing DOM
<<<<<<< HEAD
;(function () {
  const fixes = {
    "aria-auto-complete": "aria-autocomplete",
    "aria-has-popup": "aria-haspopup",
=======
(function () {
  const fixes = {
    'aria-auto-complete': 'aria-autocomplete',
    'aria-has-popup': 'aria-haspopup'
>>>>>>> 5b0a7cc11b6644909a77ce7d006b19ae6c95d572
  }

  function fixElement(el) {
    if (!el || !el.getAttribute) return
    Object.keys(fixes).forEach((wrong) => {
      if (el.hasAttribute(wrong)) {
        const val = el.getAttribute(wrong)
        if (val !== null) {
          el.setAttribute(fixes[wrong], val)
          el.removeAttribute(wrong)
        }
      }
    })
  }

  function walkAndFix(root) {
    try {
      if (root.nodeType === Node.ELEMENT_NODE) fixElement(root)
<<<<<<< HEAD
      const els = root.querySelectorAll
        ? root.querySelectorAll(
            Object.keys(fixes)
              .map((k) => "[" + k + "]")
              .join(",")
          )
        : []
=======
      const els = root.querySelectorAll ? root.querySelectorAll(Object.keys(fixes).map(k => '['+k+']').join(',')) : []
>>>>>>> 5b0a7cc11b6644909a77ce7d006b19ae6c95d572
      for (const el of els) fixElement(el)
    } catch (e) {
      // ignore
    }
  }

  // Run once on load
<<<<<<< HEAD
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => walkAndFix(document))
=======
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => walkAndFix(document))
>>>>>>> 5b0a7cc11b6644909a77ce7d006b19ae6c95d572
  } else {
    walkAndFix(document)
  }

  // Remove potentially prohibited ARIA attributes from trix-editor elements
<<<<<<< HEAD
  const trixWhitelist = new Set(["aria-label", "aria-labelledby", "aria-describedby", "aria-required", "aria-invalid"])
  function sanitizeTrixEditors(root) {
    try {
      const editors = root.querySelectorAll ? root.querySelectorAll("trix-editor") : []
      for (const ed of editors) {
        for (const attr of Array.from(ed.attributes)) {
          if (attr.name.startsWith("aria-") && !trixWhitelist.has(attr.name)) {
=======
  const trixWhitelist = new Set(['aria-label', 'aria-labelledby', 'aria-describedby', 'aria-required', 'aria-invalid'])
  function sanitizeTrixEditors(root) {
    try {
      const editors = (root.querySelectorAll) ? root.querySelectorAll('trix-editor') : []
      for (const ed of editors) {
        for (const attr of Array.from(ed.attributes)) {
          if (attr.name.startsWith('aria-') && !trixWhitelist.has(attr.name)) {
>>>>>>> 5b0a7cc11b6644909a77ce7d006b19ae6c95d572
            ed.removeAttribute(attr.name)
          }
        }
      }
    } catch (e) {
      // ignore
    }
  }

  // sanitize existing trix editors
  sanitizeTrixEditors(document)

  // Observe for future additions / attribute changes
  const observer = new MutationObserver((mutations) => {
    for (const m of mutations) {
<<<<<<< HEAD
      if (m.type === "attributes") {
        fixElement(m.target)
      } else if (m.type === "childList") {
=======
      if (m.type === 'attributes') {
        fixElement(m.target)
      } else if (m.type === 'childList') {
>>>>>>> 5b0a7cc11b6644909a77ce7d006b19ae6c95d572
        for (const node of m.addedNodes) {
          walkAndFix(node)
        }
      }
    }
  })

  try {
    observer.observe(document.documentElement || document, {
      subtree: true,
      childList: true,
      attributes: true,
<<<<<<< HEAD
      attributeFilter: Object.keys(fixes),
    })
  } catch (e) {
    // fallback: observe without attributeFilter
    try {
      observer.observe(document.documentElement || document, { subtree: true, childList: true, attributes: true })
    } catch (e2) {}
=======
      attributeFilter: Object.keys(fixes)
    })
  } catch (e) {
    // fallback: observe without attributeFilter
    try { observer.observe(document.documentElement || document, { subtree: true, childList: true, attributes: true }) } catch (e2) { }
>>>>>>> 5b0a7cc11b6644909a77ce7d006b19ae6c95d572
  }
})()
