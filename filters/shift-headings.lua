-- Shift heading levels in included content.
--
-- Usage: wrap an include in a .shift-headings div with a `by` attribute:
--
--   ::: {.shift-headings by=1}
--   {{< include _file.qmd >}}
--   :::
--
-- This shifts all headings by the given amount (# -> ##, ## -> ###, etc.)
-- and unwraps the div so blocks remain top-level (important for revealjs
-- slide breaks).
--
-- For revealjs: headings with .slide class are promoted back to h2 (slide
-- level) after shifting, so they still create new slides. Use .slide on
-- headings in the source file that should become slides after inclusion.
--
-- Example in source file:
--   # Section {.slide}     -> shifted to ## (slide) in revealjs
--   ## Subsection           -> shifted to ### (within slide)
--
-- For HTML, .slide is ignored and heading levels are simply shifted.

function Div(el)
  if el.classes:includes("shift-headings") then
    local shift = tonumber(el.attributes["by"]) or 1
    local is_revealjs = quarto.doc.is_format("revealjs")
    local shifted = el:walk({
      Header = function(h)
        h.level = math.min(h.level + shift, 6)
        -- For revealjs, promote .slide headers back to slide level (h2)
        if is_revealjs and h.classes:includes("slide") then
          h.level = 2
          local new_classes = {}
          for _, c in ipairs(h.classes) do
            if c ~= "slide" then table.insert(new_classes, c) end
          end
          h.classes = new_classes
        end
        return h
      end
    })
    return shifted.content
  end
end
