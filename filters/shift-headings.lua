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
