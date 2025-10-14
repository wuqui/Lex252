-- Inline full-citation filter for Pandoc/Quarto
-- Usage in Markdown: [@Key]{.fullcite} or [@Key1; @Key2]{.fullcite}
-- This replaces the span with the full CSL-formatted bibliography entry (or entries).

local doc_meta = pandoc.Meta({})
local project_root = nil

local function file_exists(path)
  local f = io.open(path, 'r')
  if f then f:close() return true end
  return false
end

local function read_all(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  return s
end

-- NOTE: Some pandoc.path helpers may be unavailable in certain versions;
-- keep resolution simple and robust by using the working directory.

-- Resolve a bibliography Meta value to absolute paths relative to project_root
local function resolve_bibliography_meta(meta_bib, base_root)
  if not meta_bib then return nil end
  local function to_abs(path_str)
    if pandoc.path.is_absolute(path_str) then return path_str end
    return pandoc.path.normalize(pandoc.path.join({ base_root, path_str }))
  end
  if meta_bib.t == 'MetaList' then
    local new_list = pandoc.List()
    for _, item in ipairs(meta_bib) do
      local s = pandoc.utils.stringify(item)
      new_list:insert(pandoc.MetaString(to_abs(s)))
    end
    return pandoc.MetaList(new_list)
  else
    local s = pandoc.utils.stringify(meta_bib)
    return pandoc.MetaString(to_abs(s))
  end
end

function Meta(m)
  -- Keep the document metadata unchanged; only record it for later use.
  doc_meta = m
  -- Prefer Quarto's project dir if available; else working directory
  project_root = os.getenv('QUARTO_PROJECT_DIR') or pandoc.system.get_working_directory()
  return nil
end

local function has_class(el, class)
  for _, c in ipairs(el.classes or {}) do
    if c == class then return true end
  end
  return false
end

local function extract_refs_div(blocks)
  for _, b in ipairs(blocks) do
    if b.t == 'Div' then
      local id = b.identifier or b.attr and b.attr.identifier
      if id == 'refs' then
        return b
      end
      local found = extract_refs_div(b.content)
      if found then return found end
    end
  end
  return nil
end

local function blocks_to_inlines(blocks)
  local inlines = pandoc.List()
  local function append_sep(i, n)
    if i < n then inlines:insert(pandoc.LineBreak()) end
  end

  for i, b in ipairs(blocks) do
    if b.t == 'Para' or b.t == 'Plain' then
      inlines:extend(b.content)
      append_sep(i, #blocks)
    elseif b.t == 'Div' then
      inlines:extend(blocks_to_inlines(b.content))
      append_sep(i, #blocks)
    elseif b.t == 'BulletList' then
      for j, item in ipairs(b.content) do
        inlines:extend(blocks_to_inlines(item))
        append_sep(j, #b.content)
      end
      append_sep(i, #blocks)
    elseif b.t == 'OrderedList' then
      for j, item in ipairs(b.content) do
        inlines:extend(blocks_to_inlines(item))
        append_sep(j, #b.content)
      end
      append_sep(i, #blocks)
    elseif b.t == 'LineBlock' then
      for j, line in ipairs(b.content) do
        inlines:extend(line)
        append_sep(j, #b.content)
      end
      append_sep(i, #blocks)
    end
  end
  return inlines
end

local function fullcite_inlines(cite_inlines)
  -- Build a temporary doc with only the citations and a refs anchor
  local tmp_blocks = pandoc.List()
  tmp_blocks:insert(pandoc.Para(cite_inlines))
  tmp_blocks:insert(pandoc.Div({}, pandoc.Attr('refs')))
  -- Ensure bibliography and csl propagate
  local tmp_meta = pandoc.Meta({})
  -- Copy CSL if present
  if doc_meta and doc_meta.csl then
    tmp_meta.csl = doc_meta.csl
  end
  -- Prefer a resolved bibliography based on the project's root
  if doc_meta and doc_meta.bibliography then
    tmp_meta.bibliography = resolve_bibliography_meta(doc_meta.bibliography, project_root)
  end
  -- If still no bibliography present, attempt to set to project_root/references.bib
  if not tmp_meta.bibliography and project_root then
    local cand = pandoc.path.join({ project_root, 'references.bib' })
    if file_exists(cand) then
      tmp_meta.bibliography = pandoc.MetaString(cand)
    else
      -- Try to detect from _quarto.yml if it lists a bibliography path
      local qy = pandoc.path.join({ project_root, '_quarto.yml' })
      local y = read_all(qy)
      if y and y:match('bibliography%:') then
        -- If any references.bib is mentioned, prefer project_root/references.bib
        if y:match('references%.bib') then
          local pcand = pandoc.path.join({ project_root, 'references.bib' })
          if file_exists(pcand) then
            tmp_meta.bibliography = pandoc.MetaString(pcand)
          end
        end
      end
    end
  end
  -- As a last resort, try current working directory
  if not tmp_meta.bibliography then
    local cwd = pandoc.system.get_working_directory()
    local cand = pandoc.path.join({ cwd, 'references.bib' })
    if file_exists(cand) then
      tmp_meta.bibliography = pandoc.MetaString(cand)
    end
  end
  local tmp_doc = pandoc.Pandoc(tmp_blocks, tmp_meta)

  -- Run citeproc to produce bibliography for just these citations
  local ok, processed = pcall(pandoc.utils.citeproc, tmp_doc)
  if not ok then
    -- Fallback: return the original cite inline
    return cite_inlines
  end

  local refs_div = extract_refs_div(processed.blocks)
  if not refs_div then
    return cite_inlines
  end

  -- Convert the refs div content (blocks) to inlines
  local out = blocks_to_inlines(refs_div.content)
  if #out == 0 then
    return cite_inlines
  end
  return out
end

function Span(el)
  if not has_class(el, 'fullcite') then
    return nil
  end

  -- DEBUG: uncomment to verify filter runs before citeproc
  -- return pandoc.Inlines(pandoc.Str('[FULLCITE]'))

  -- Collect citation keys from Cite inlines (pre-citeproc) or Links to #ref-KEY (post-citeproc)
  local citation_ids = {}
  for _, inline in ipairs(el.content) do
    if inline.t == 'Cite' then
      for __, cit in ipairs(inline.citations) do
        table.insert(citation_ids, cit.id)
      end
    elseif inline.t == 'Link' and inline.target then
      local m = inline.target:match('^#ref%-([%w%-%._:]+)')
      if m then table.insert(citation_ids, m) end
    end
  end

  if #citation_ids == 0 then
    return nil -- leave unchanged if no keys found
  end

  -- Build a merged Cite from collected ids
  local merged_citations = pandoc.List()
  for _, id in ipairs(citation_ids) do
    table.insert(merged_citations, pandoc.Citation(id, 'NormalCitation'))
  end
  local merged_cite_inline = pandoc.Cite({ pandoc.Str('') }, merged_citations)
  local inlines = fullcite_inlines({ merged_cite_inline })
  return inlines
end

return {
  { Meta = Meta, Span = Span }
}


