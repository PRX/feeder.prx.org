// Global ARIA sanitizer: fix common misspelled ARIA attributes and keep observing DOM
(function () {
  const fixes = {
    'aria-auto-complete': 'aria-autocomplete',
    'aria-has-popup': 'aria-haspopup'
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
      const els = root.querySelectorAll ? root.querySelectorAll(Object.keys(fixes).map(k => '['+k+']').join(',')) : []
      for (const el of els) fixElement(el)
    } catch (e) {
      // ignore
    }
  }

  // Run once on load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => walkAndFix(document))
  } else {
    walkAndFix(document)
  }

  // Remove potentially prohibited ARIA attributes from trix-editor elements
  const trixWhitelist = new Set(['aria-label', 'aria-labelledby', 'aria-describedby', 'aria-required', 'aria-invalid'])
  function sanitizeTrixEditors(root) {
    try {
      const editors = (root.querySelectorAll) ? root.querySelectorAll('trix-editor') : []
      for (const ed of editors) {
        for (const attr of Array.from(ed.attributes)) {
          if (attr.name.startsWith('aria-') && !trixWhitelist.has(attr.name)) {
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
      if (m.type === 'attributes') {
        fixElement(m.target)
      } else if (m.type === 'childList') {
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
      attributeFilter: Object.keys(fixes)
    })
  } catch (e) {
    // fallback: observe without attributeFilter
    try { observer.observe(document.documentElement || document, { subtree: true, childList: true, attributes: true }) } catch (e2) { }
  }
})()
