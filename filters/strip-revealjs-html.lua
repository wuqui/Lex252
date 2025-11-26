-- Strip RevealJS-specific elements from HTML handout and production slides
-- This filter removes slide-specific elements (notes, pauses, horizontal rules)
-- and classes (.small, .smaller) when rendering to HTML format (not RevealJS).
-- In production builds (CI=true), also strips notes from RevealJS slides.
--
-- Usage: Add to document YAML:
--   filters:
--     - filters/strip-revealjs-html.lua

local function is_html_handout()
  -- Check if we're rendering HTML format but NOT RevealJS
  return quarto.doc.is_format("html") and not quarto.doc.is_format("revealjs")
end

local function is_production_build()
  -- Check for CI environment variable (set by GitHub Actions)
  local ci = os.getenv("CI")
  local github_actions = os.getenv("GITHUB_ACTIONS")
  return ci == "true" or github_actions == "true"
end

function Div(el)
  -- Remove notes from HTML handout (always)
  if is_html_handout() then
    for _, class in ipairs(el.classes) do
      if class == "notes" then
        return {} -- Remove the entire div
      end
    end
  end
  
  -- Remove notes from RevealJS slides in production builds only
  if quarto.doc.is_format("revealjs") and is_production_build() then
    for _, class in ipairs(el.classes) do
      if class == "notes" then
        return {} -- Remove the entire div
      end
    end
  end
  
  -- Remove .small and .smaller classes from HTML handout divs
  if is_html_handout() then
    local filtered_classes = {}
    for _, class in ipairs(el.classes) do
      if class ~= "small" and class ~= "smaller" then
        table.insert(filtered_classes, class)
      end
    end
    el.classes = filtered_classes
  end
  
  return el
end

function HorizontalRule(el)
  if is_html_handout() then
    return {} -- Remove all horizontal rules (slide dividers)
  end
  return el
end

function Para(el)
  if not is_html_handout() then return el end
  
  -- Remove paragraphs containing only ". . ." (fragment pauses)
  -- Pandoc parses this as: Str "." , Space , Str "." , Space , Str "."
  if #el.content == 5 then
    if el.content[1].t == "Str" and el.content[1].text == "." and
       el.content[2].t == "Space" and
       el.content[3].t == "Str" and el.content[3].text == "." and
       el.content[4].t == "Space" and
       el.content[5].t == "Str" and el.content[5].text == "." then
      return {} -- Remove the paragraph
    end
  end
  
  return el
end

function Span(el)
  if not is_html_handout() then return el end
  
  -- Remove .small and .smaller classes from spans
  local filtered_classes = {}
  for _, class in ipairs(el.classes) do
    if class ~= "small" and class ~= "smaller" then
      table.insert(filtered_classes, class)
    end
  end
  el.classes = filtered_classes
  
  return el
end

function Header(el)
  if not is_html_handout() then return el end
  
  -- Remove .small and .smaller classes from headers
  local filtered_classes = {}
  for _, class in ipairs(el.classes) do
    if class ~= "small" and class ~= "smaller" then
      table.insert(filtered_classes, class)
    end
  end
  el.classes = filtered_classes
  
  return el
end

function Meta(meta)
  if not is_html_handout() then return meta end
  
  -- Remove course website link from subtitle in HTML handout
  -- Subtitle format: "Lexicology and Lexicography — [Course Website](../../index.qmd)"
  -- We want: "Lexicology and Lexicography"
  if meta.subtitle then
    local subtitle_str = pandoc.utils.stringify(meta.subtitle)
    -- Remove everything from " — " onwards
    local cleaned = subtitle_str:match("^([^—]+)") or subtitle_str
    if cleaned ~= subtitle_str then
      -- Trim trailing whitespace
      cleaned = cleaned:match("^%s*(.-)%s*$")
      meta.subtitle = pandoc.MetaString(cleaned)
    end
  end
  
  return meta
end

-- Return filter functions in order
return {
  { Meta = Meta },
  { Div = Div },
  { HorizontalRule = HorizontalRule },
  { Para = Para },
  { Span = Span },
  { Header = Header }
}

