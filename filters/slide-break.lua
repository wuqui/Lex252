-- Filter to create slide breaks for headings with .slide class.
-- When a heading has .slide class at H3+ level, it creates a new top-level slide
-- by promoting the heading to H2 level.
--
-- This uses a Blocks filter to work at the document level, ensuring promoted
-- H2 headings appear as top-level blocks rather than nested within parent sections.
--
-- Works with slide-level: 2 where H2 headings create slides.
--
-- Note: for included content wrapped in ::: {.shift-headings}, the .slide
-- promotion is handled directly by shift-headings.lua (which runs first).
-- This filter handles .slide headings in non-included content.

PANDOC_VERSION:must_be_at_least {2,8}

local utils = require 'pandoc.utils'

-- Helper: check if element has class
local function has_class(el, name)
  if not el.classes then return false end
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
  return div.t == 'Div' and has_class(div, 'section')
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

-- Process a single H2-level section and extract any .slide subsections
local function process_h2_section(section_div)
  local header = section_header(section_div)
  if not header or header.level ~= 2 then
    return nil -- Not an H2 section, skip
  end

  -- Check if this section contains any H3+ .slide headers
  local has_slide_subsection = false
  local function check_for_slides(blocks)
    for _, block in ipairs(blocks) do
      if block.t == 'Div' and is_section_div(block) then
        local h = section_header(block)
        if h and h.level >= 3 and has_class(h, 'slide') then
          has_slide_subsection = true
          return
        end
        check_for_slides(block.content)
      end
    end
  end
  check_for_slides(section_div.content)

  if not has_slide_subsection then
    return nil -- No .slide subsections, no changes needed
  end

  -- Split this section: extract everything before first .slide as the original section,
  -- then each .slide becomes a new top-level section
  local result = {}
  local current_section_content = {}
  local in_original_section = true
  local original_header = header

  local function process_content(blocks, depth)
    for _, block in ipairs(blocks) do
      if block.t == 'Div' and is_section_div(block) then
        local h = section_header(block)
        if h and h.level >= 3 and has_class(h, 'slide') then
          -- Found a .slide section - close current section and start new one
          if in_original_section then
            -- Output the original H2 section (even if empty, it's still a slide)
            table.insert(result, original_header)
            for _, b in ipairs(current_section_content) do
              table.insert(result, b)
            end
            in_original_section = false
            current_section_content = {}
          elseif #current_section_content > 0 then
            -- Output accumulated content
            for _, b in ipairs(current_section_content) do
              table.insert(result, b)
            end
            current_section_content = {}
          end

          -- Output promoted .slide header
          local promoted_header = h:clone()
          promoted_header.level = 2
          promoted_header.identifier = block.identifier or h.identifier
          remove_class(promoted_header, 'slide')
          table.insert(result, promoted_header)

          -- Process content of this .slide section (skip header)
          for i = 2, #block.content do
            local inner_block = block.content[i]
            if inner_block.t == 'Div' and is_section_div(inner_block) then
              -- Recursively process nested sections
              process_content({inner_block}, depth + 1)
            else
              table.insert(result, inner_block)
            end
          end
        else
          -- Non-.slide section - process recursively
          if h then
            table.insert(current_section_content, h)
          end
          for i = (h and 2 or 1), #block.content do
            local inner_block = block.content[i]
            if inner_block.t == 'Div' and is_section_div(inner_block) then
              process_content({inner_block}, depth + 1)
            else
              table.insert(current_section_content, inner_block)
            end
          end
        end
      else
        table.insert(current_section_content, block)
      end
    end
  end

  -- Start processing from content after the H2 header
  local content_to_process = {}
  for i = 2, #section_div.content do
    table.insert(content_to_process, section_div.content[i])
  end
  process_content(content_to_process, 0)

  -- Output any remaining content
  if in_original_section then
    -- We never hit a .slide, shouldn't happen but handle it
    table.insert(result, original_header)
    for _, b in ipairs(current_section_content) do
      table.insert(result, b)
    end
  elseif #current_section_content > 0 then
    for _, b in ipairs(current_section_content) do
      table.insert(result, b)
    end
  end

  return result
end

-- Pass 1: Setup - wrap all sections in Div elements
local function setup_document(doc)
  local sections = utils.make_sections(false, nil, doc.blocks)
  return pandoc.Pandoc(sections, doc.meta)
end

-- Pass 2: Process H2 sections and split out .slide subsections
local function split_slide_sections(div)
  return process_h2_section(div)
end

-- Pass 3: Flatten remaining section divs back to normal structure
local function flatten_sections(div)
  local header = section_header(div)
  if not header then return nil end
  -- Preserve the section identifier on the header
  header.identifier = div.identifier
  div.content[1] = header
  return div.content
end

-- Pass 4: Handle any remaining .slide headers (H1/H2 level) that don't need section restructuring
local function handle_toplevel_slide_headers(el)
  if has_class(el, 'slide') then
    remove_class(el, 'slide')
    -- H1/H2 with .slide just removes the class (they already create slides)
    return el
  end
  return el
end

return {
  { Pandoc = setup_document },
  { Div = split_slide_sections },
  { Div = flatten_sections },
  { Header = handle_toplevel_slide_headers }
}
