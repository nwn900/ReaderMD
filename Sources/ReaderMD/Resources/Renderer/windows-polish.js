(function () {
  "use strict";

  window.readermdForceTheme = function (theme, systemDark) {
    const isDark = theme === "dark" || (theme === "system" && systemDark === true);
    const root = document.documentElement;
    root.dataset.theme = isDark ? "dark" : "light";
    root.style.colorScheme = isDark ? "dark" : "light";
  };

  const originalMarkdownIt = window.markdownit;
  if (!originalMarkdownIt) return;

  const blockedElements = new Set([
    "SCRIPT",
    "STYLE",
    "IFRAME",
    "FRAME",
    "FRAMESET",
    "OBJECT",
    "EMBED",
    "BASE",
    "META",
    "LINK",
  ]);

  const urlAttributes = new Set([
    "href",
    "src",
    "poster",
    "action",
    "formaction",
    "xlink:href",
  ]);

  function normalizeHtmlTags(markdown) {
    return String(markdown || "").replace(/<\/?[A-Za-z][^<>]*>/g, function (tag) {
      return tag
        .replace(/[\u201c\u201d]/g, '"')
        .replace(/[\u2018\u2019]/g, "'")
        .replace(
          /\b(src|href)\s*=\s*"\[([^\]]+)\]\(([^)]+)\)"/gi,
          function (_, attribute, label, target) {
            return attribute + '="' + target + '"';
          }
        )
        .replace(
          /\b(src|href)\s*=\s*'\[([^\]]+)\]\(([^)]+)\)'/gi,
          function (_, attribute, label, target) {
            return attribute + "='" + target + "'";
          }
        );
    });
  }

  function normalizeAttributeValue(value) {
    const trimmed = String(value || "").trim();
    if (
      (trimmed.startsWith("\u201c") && trimmed.endsWith("\u201d")) ||
      (trimmed.startsWith("\u2018") && trimmed.endsWith("\u2019"))
    ) {
      return trimmed.slice(1, -1);
    }
    return trimmed;
  }

  function isSafeUrl(attributeName, value) {
    const normalized = normalizeAttributeValue(value);
    const compact = normalized.replace(/[\u0000-\u0020]+/g, "").toLowerCase();
    if (compact.startsWith("javascript:") || compact.startsWith("vbscript:")) {
      return false;
    }
    if (compact.startsWith("data:")) {
      return (
        attributeName === "src" &&
        /^data:image\/(?:png|jpe?g|gif|webp|bmp);base64,/i.test(normalized)
      );
    }
    return true;
  }

  function sanitizeMarkup(markup) {
    const template = document.createElement("template");
    template.innerHTML = markup;

    Array.from(template.content.querySelectorAll("*")).forEach(function (element) {
      if (blockedElements.has(element.tagName)) {
        element.remove();
        return;
      }

      Array.from(element.attributes).forEach(function (attribute) {
        const name = attribute.name.toLowerCase();
        if (name.startsWith("on") || name === "srcdoc" || name === "style") {
          element.removeAttribute(attribute.name);
          return;
        }

        if (urlAttributes.has(name)) {
          const normalizedValue = normalizeAttributeValue(attribute.value);
          if (!isSafeUrl(name, normalizedValue)) {
            element.removeAttribute(attribute.name);
            return;
          }
          if (normalizedValue !== attribute.value) {
            element.setAttribute(attribute.name, normalizedValue);
          }
        }
      });

      if (element.tagName === "A" && element.getAttribute("target") === "_blank") {
        element.setAttribute("rel", "noopener noreferrer");
      }
    });

    return template.innerHTML;
  }

  function wrappedMarkdownIt(options) {
    const configuration = Object.assign({}, options || {}, { html: true });
    const instance = originalMarkdownIt(configuration);

    const originalParse = instance.parse.bind(instance);
    instance.parse = function (source, environment) {
      return originalParse(normalizeHtmlTags(source), environment);
    };

    const originalRender = instance.renderer.render.bind(instance.renderer);
    instance.renderer.render = function (tokens, renderOptions, environment) {
      return sanitizeMarkup(originalRender(tokens, renderOptions, environment));
    };

    return instance;
  }

  Object.assign(wrappedMarkdownIt, originalMarkdownIt);
  window.markdownit = wrappedMarkdownIt;
})();