-- Solution blocks filter for Quarto
-- Removes .sol elements when params.show_solutions is false
-- Keeps them when params.show_solutions is true
--
-- Usage in document:
--   ::: {.sol}
--   [solution content]
--   :::
--
--   ::: {.sol .slide}
--   [solution on new slide]
--   :::
--
--   ::: {.sol .fragment}
--   [solution appears as fragment/pause]
--   :::
--
--   ::: {.sol .incremental}
--   [solution with incremental list reveal]
--   :::
--
--   ## Section Heading {.sol}
--   [entire section content, including all subsections, is removed]
--
--   ### Subsection {.sol}
--   [this subsection and its content is also removed]
--
-- Control visibility via params:
--   - Default: params.show_solutions: false (removed)
--   - Show solutions: params.show_solutions: true (shown)
--
-- Note: When a heading has .sol class, the entire section (including all
--       subsections) is removed until the next heading at the same or higher level.

local show_solutions = false

local function has_class(el, name)
  for _, class in ipairs(el.classes) do
    if class == name then
      return true
    end
  end
  return false
end

local function remove_class(el, name)
  local new_classes = {}
  for _, class in ipairs(el.classes) do
    if class ~= name then
      table.insert(new_classes, class)
    end
  end
  el.classes = new_classes
end

function Meta(meta)
  if meta.params and meta.params.show_solutions == true then
    show_solutions = true
  end
  return meta
end

function Pandoc(doc)
  -- If solutions should be shown, return document unchanged
  -- (individual element handlers will still process .sol elements)
  if show_solutions then
    return doc
  end
  
  -- Process document to remove entire sections starting with .sol headings
  local blocks = {}
  local skip_section = false
  local section_level = nil
  
  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" then
      -- Check if this header has .sol class
      if has_class(block, "sol") then
        -- Start skipping this section
        skip_section = true
        section_level = block.level
        -- Don't add this header to output
      elseif skip_section then
        -- Check if we've reached the end of the section
        -- (next heading at same or higher level)
        if block.level <= section_level then
          -- End of section, stop skipping
          skip_section = false
          section_level = nil
          -- Add this header to output
          table.insert(blocks, block)
        end
        -- If block.level > section_level, it's a subsection, continue skipping
      else
        -- Normal header, not in a skipped section
        table.insert(blocks, block)
      end
    else
      -- Non-header block
      if not skip_section then
        table.insert(blocks, block)
      end
      -- If skip_section is true, don't add this block
    end
  end
  
  return pandoc.Pandoc(blocks, doc.meta)
end

function Div(el)
  if has_class(el, "sol") then
    if not show_solutions then
      return {}
    end
    -- Check for .slide class - insert slide break before
    if has_class(el, "slide") then
      remove_class(el, "slide")
      return { pandoc.HorizontalRule(), el }
    end
  end
  return el
end

function Span(el)
  if has_class(el, "sol") then
    if not show_solutions then
      return pandoc.Span({})
    end
  end
  return el
end

function Header(el)
  if has_class(el, "sol") then
    if not show_solutions then
      return {}
    end
  end
  return el
end

return {
  { Meta = Meta },
  { Pandoc = Pandoc },
  { Div = Div, Span = Span, Header = Header }
}
