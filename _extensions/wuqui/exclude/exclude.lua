-- Exclude filter for Quarto
-- Removes .excl elements when params.show_excl is false
-- Keeps them when params.show_excl is true (default)
--
-- Usage in document:
--   ::: {.excl}
--   [content to exclude]
--   :::
--
--   [inline content]{.excl}
--
--   ## Header {.excl}
--   Content below header is also excluded (entire section)
--
--   ## Header {.excl .slide}  -- Creates slide break in RevealJS
--   ## Header {.excl .fragment}  -- Reveals heading as RevealJS fragment
--
-- Control visibility in YAML frontmatter:
--   params:
--     show_excl: false  # hide .excl content
--
-- Control styling in YAML frontmatter:
--   params:
--     show_excl: true
--     excl-style:
--       enabled: false  # disable default styling

-- Requires pandoc 2.8+ for pandoc.utils.make_sections
PANDOC_VERSION:must_be_at_least {2,8}

local utils = require 'pandoc.utils'
local show_excl = true  -- default: show everything

-- Styling configuration
local excl_style_enabled = true

-- Helper: check if element has class
local function has_class(el, name)
  for _, class in ipairs(el.classes) do
    if class == name then
      return true
    end
  end
  return false
end

-- Helper: remove class from element
local function remove_class(el, name)
  local new_classes = {}
  for _, class in ipairs(el.classes) do
    if class ~= name then
      table.insert(new_classes, class)
    end
  end
  el.classes = new_classes
end

-- Helper: check if div is a section div created by make_sections
local function is_section_div(div)
  return div.t == 'Div'
    and div.classes[1] == 'section'
    and div.attributes.number
end

-- Helper: get header from section div
local function section_header(div)
  if not is_section_div(div) then return nil end
  local header = div.content and div.content[1]
  if header and header.t == 'Header' then
    return header
  end
  return nil
end

-- Helper: conditionally remove .excl class based on styling configuration
local function maybe_remove_excl_class(el)
  if not excl_style_enabled then
    remove_class(el, "excl")
  end
end

-- Pass 1: Read params from document metadata
function Meta(meta)
  -- Read show_excl parameter
  if meta.params and meta.params.show_excl == false then
    show_excl = false
  end

  -- Read styling configuration
  if meta.params and meta.params["excl-style"] then
    local style = meta.params["excl-style"]
    if style.enabled == false then
      excl_style_enabled = false
      -- Add body class to disable styling via CSS
      if not meta.html then meta.html = {} end
      if not meta.html["body-header"] then meta.html["body-header"] = {} end
      table.insert(meta.html["body-header"], '<script>document.body.classList.add("excl-style-disabled");</script>')
    end
  end

  return meta
end

-- Pass 2: Setup - wrap all sections in Div elements
local function setup_document(doc)
  -- Ensure CSS is included for all HTML-based formats
  -- We use quarto.doc.add_html_dependency() to automatically include CSS for all formats,
  -- including clean-revealjs which doesn't properly support format contributions in _extension.yml.
  -- Format contributions in _extension.yml serve as a fallback for html and revealjs formats.
  -- This approach ensures users don't need to manually specify the CSS file.
  if quarto.doc.is_format("html") or quarto.doc.is_format("clean-revealjs") or quarto.doc.is_format("revealjs") then
    quarto.doc.add_html_dependency({
      name = "quarto-exclude",
      version = "1.5.0",
      stylesheets = {"exclude-styles.css"}
    })
  end

  if show_excl then return nil end  -- skip processing if showing everything
  local sections = utils.make_sections(false, nil, doc.blocks)
  return pandoc.Pandoc(sections, doc.meta)
end

-- Pass 3: Remove section divs where header has .excl class
local function drop_excl_sections(div)
  if show_excl then return nil end
  local header = section_header(div)
  if header and has_class(header, "excl") then
    return {}
  end
end

-- Pass 4: Flatten remaining section divs back to normal structure
local function flatten_sections(div)
  if show_excl then return nil end
  local header = section_header(div)
  if not header then return nil end
  -- Preserve the section identifier on the header
  header.identifier = div.identifier
  div.content[1] = header
  return div.content
end

-- Pass 5: Remove standalone .excl divs and spans
local function remove_excl_div(el)
  if has_class(el, "excl") then
    if not show_excl then
      return {}  -- remove when hiding
    end
    -- When showing, handle modifiers
    -- Keep .excl class for styling unless styling is disabled
    if has_class(el, "slide") then
      remove_class(el, "slide")
      maybe_remove_excl_class(el)
      return { pandoc.HorizontalRule(), el }
    end
    -- .fragment stays on element (RevealJS handles it)
    -- For both fragment and non-fragment cases, remove .excl class if styling disabled
    maybe_remove_excl_class(el)
    return el
  end
  return nil  -- no modification needed
end

local function remove_excl_span(el)
  if has_class(el, "excl") then
    if not show_excl then
      return {}  -- remove when hiding
    end
    -- When showing, keep .excl class for styling unless styling is disabled
    maybe_remove_excl_class(el)
    return el
  end
  return nil  -- no modification needed
end

-- Pass 6: Handle headings with .excl class (for styling control)
function Header(el)
  if has_class(el, "excl") then
    if not show_excl then
      return {}  -- remove when hiding
    end
    -- When showing, handle modifiers like .slide and .fragment
    -- If heading has .slide class, remove it and insert HorizontalRule before heading
    -- This creates a slide break in RevealJS (horizontal rules create new slides)
    -- Note: strip-revealjs-html filter will remove horizontal rules from HTML handouts
    if has_class(el, "slide") then
      remove_class(el, "slide")
      maybe_remove_excl_class(el)
      -- Return array with HorizontalRule first (creates slide break), then heading
      -- This replaces the heading with [HorizontalRule, Heading] in the document
      return { pandoc.HorizontalRule(), el }
    end
    -- .fragment stays on element (RevealJS handles it)
    -- When showing, remove .excl class only if styling is disabled
    maybe_remove_excl_class(el)
  end
  return el
end

return {
  { Meta = Meta },
  { Pandoc = setup_document },
  { Div = drop_excl_sections },
  { Div = flatten_sections },
  { Div = remove_excl_div, Span = remove_excl_span, Header = Header }
}
