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
-- Control visibility via params:
--   - Default: params.show_solutions: false (removed)
--   - Show solutions: params.show_solutions: true (shown)

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
  { Div = Div, Span = Span, Header = Header }
}
