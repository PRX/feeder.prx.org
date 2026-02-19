// Global ARIA sanitizer: fix common misspelled ARIA attributes and keep observing DOM
;(function () {
  const fixes = {
    "aria-auto-complete": "aria-autocomplete",
    "aria-has-popup": "aria-haspopup",
    "aria-labeledby": "aria-labelledby",
  }

  const trixWhitelist = new Set(["aria-label", "aria-labelledby", "aria-describedby", "aria-required", "aria-invalid"])

  const standardAutocomplete = [
    "on",
    "off",
    "name",
    "honorific-prefix",
    "given-name",
    "additional-name",
    "family-name",
    "honorific-suffix",
    "nickname",
    "email",
    "username",
    "new-password",
    "current-password",
    "one-time-code",
    "organization-title",
    "organization",
    "street-address",
    "address-line1",
    "address-line2",
    "address-line3",
    "address-level4",
    "address-level3",
    "address-level2",
    "address-level1",
    "country",
    "country-name",
    "postal-code",
    "cc-name",
    "cc-given-name",
    "cc-additional-name",
    "cc-family-name",
    "cc-number",
    "cc-exp",
    "cc-exp-month",
    "cc-exp-year",
    "cc-csc",
    "cc-type",
    "transaction-currency",
    "transaction-amount",
    "language",
    "bday",
    "bday-day",
    "bday-month",
    "bday-year",
    "sex",
    "url",
    "tel",
    "tel-country-code",
    "tel-national",
    "tel-area-code",
    "tel-local",
    "tel-extension",
    "impp",
    "photo",
  ]

  function fixElement(el) {
    if (!el || !el.getAttribute) return

    // Fix misspelled ARIA attributes
    Object.keys(fixes).forEach((wrong) => {
      if (el.hasAttribute(wrong)) {
        const val = el.getAttribute(wrong)
        if (val !== null) {
          el.setAttribute(fixes[wrong], val)
          el.removeAttribute(wrong)
        }
      }
    })

    // Fix invalid autocomplete values
    if (el.hasAttribute("autocomplete")) {
      const auto = el.getAttribute("autocomplete")
      if (auto && (auto.startsWith("field-") || !standardAutocomplete.includes(auto))) {
        el.setAttribute("autocomplete", "off")
      }
    }

    // Special case for roles requiring a name (textbox, combobox, listbox, etc)
    const role = el.getAttribute("role")
    if (role === "textbox" || role === "combobox" || role === "listbox") {
      ensureAccessibleName(el)
    }

    // Ensure scrollable SlimSelect list is keyboard accessible (Axe: scrollable-region-focusable)
    if (el.classList.contains("ss-list") && !el.hasAttribute("tabindex")) {
      el.setAttribute("tabindex", "0")
    }
  }

  function ensureAccessibleName(el) {
    // If it already has a name or title, we're good
    if (el.hasAttribute("aria-label") || el.hasAttribute("aria-labelledby") || el.hasAttribute("title")) return

    const role = el.getAttribute("role")

    // Helper to link a label to the element
    const linkLabel = (label) => {
      if (!label) return false
      if (!label.id) label.id = "label-" + Math.random().toString(36).slice(2, 11)
      el.setAttribute("aria-labelledby", label.id)
      return true
    }

    // 1. Try finding label by the element's own ID
    if (el.id && linkLabel(document.querySelector(`label[for="${el.id}"]`))) return

    // 2. Special handling for SlimSelect main (div with role="combobox" and class "ss-main")
    if (role === "combobox" && el.classList.contains("ss-main")) {
      const originalSelect = el.previousElementSibling?.tagName === "SELECT" ? el.previousElementSibling : null
      if (originalSelect && originalSelect.id) {
        if (linkLabel(document.querySelector(`label[for="${originalSelect.id}"]`))) return
      }
    }

    // 3. Special handling for SlimSelect listbox (div with role="listbox" and class "ss-list")
    if (role === "listbox" && el.classList.contains("ss-list")) {
      const content = el.closest(".ss-content")
      if (content) {
        const id = content.id || content.dataset.id
        const main = document.getElementById(id) || document.querySelector(`.ss-main[data-id="${id}"]`)
        if (main) {
          const originalSelect = main.previousElementSibling?.tagName === "SELECT" ? main.previousElementSibling : null
          if (originalSelect && originalSelect.id) {
            if (linkLabel(document.querySelector(`label[for="${originalSelect.id}"]`))) return
          }
        }
      }
    }

    // 4. Redundant role removal for Trix
    if (el.tagName === "TRIX-EDITOR" && role === "textbox") {
      el.removeAttribute("role")
    }
  }

  function sanitizeTrixEditor(ed) {
    if (!ed || ed.tagName !== "TRIX-EDITOR") return

    // Ensure name/role compliance first
    ensureAccessibleName(ed)

    // Then strip prohibited aria attributes
    for (const attr of Array.from(ed.attributes)) {
      if (attr.name.startsWith("aria-") && !trixWhitelist.has(attr.name)) {
        ed.removeAttribute(attr.name)
      }
    }
  }

  function walkAndFix(root) {
    try {
      if (root.nodeType !== Node.ELEMENT_NODE && root.nodeType !== Node.DOCUMENT_NODE) return

      // Fix misspellings and roles on the root itself
      if (root.nodeType === Node.ELEMENT_NODE) fixElement(root)

      // Find and fix misspellings and role issues in children
      const selector =
        Object.keys(fixes)
          .map((k) => "[" + k + "]")
          .join(",") + ", [role='textbox'], [role='combobox'], [role='listbox'], [autocomplete], .ss-list"
      const targets = root.querySelectorAll ? root.querySelectorAll(selector) : []
      for (const el of targets) fixElement(el)

      // Sanitize Trix editors
      const editors = root.querySelectorAll ? Array.from(root.querySelectorAll("trix-editor")) : []
      if (root.tagName === "TRIX-EDITOR") editors.push(root)
      for (const ed of editors) sanitizeTrixEditor(ed)
    } catch (e) {
      // ignore
    }
  }

  // Run once on load
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => walkAndFix(document))
  } else {
    walkAndFix(document)
  }

  // Observe for future additions / attribute changes
  const observer = new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.type === "attributes") {
        if (
          Object.keys(fixes).includes(m.attributeName) ||
          m.attributeName === "role" ||
          m.attributeName === "autocomplete" ||
          m.attributeName === "class"
        ) {
          fixElement(m.target)
        }
        if (m.target.tagName === "TRIX-EDITOR") {
          sanitizeTrixEditor(m.target)
        }
      } else if (m.type === "childList") {
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
    })
  } catch (e) {
    // ignore
  }
})()
