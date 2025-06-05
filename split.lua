function Pandoc(doc)
  -- Identifiers of chapters we do not want to write out
  local ignore_chapters = {
    See_also        = true,
    References      = true,
    External_links  = true,
    Further_reading = true,
    Notes           = true
  }

  local title = pandoc.utils.stringify(doc.meta.title)
  for i, blk in ipairs(doc.blocks) do
    doc.blocks[i] = pandoc.walk_block(blk, {
      Image = function(el) return {} end,
      Note = function(el) return {} end,
      RawBlock = function(el) return {} end
    })
  end

  local function header_to_identifier(header_content)
    local identifier = pandoc.utils.stringify(header_content)
    return string.gsub(identifier, " ", "_")
  end

  local chapters = {}
  local cur_blocks = {}
  local last_identifier = nil

  for _, el in ipairs(doc.blocks) do
    if el.t == "Header" and el.level == 2 then
      if #cur_blocks > 0 then
        table.insert(chapters, {blocks = cur_blocks, identifier = last_identifier})
        cur_blocks = {}
      end
      last_identifier = header_to_identifier(el.content)
    end
    table.insert(cur_blocks, el)
  end

  -- push the last chapter
  if #cur_blocks > 0 then
    table.insert(chapters, {blocks = cur_blocks, identifier = last_identifier})
  end

  -- write each chapter to disk in plain text
  for _, chapter in ipairs(chapters) do
    local identifier = chapter.identifier -- may be nil for top-level
    if not (identifier and ignore_chapters[identifier]) then
      local chapter_doc = pandoc.Pandoc(chapter.blocks, doc.meta)
      local txt = pandoc.write(chapter_doc, "plain", { columns = 8192 })
      local fname = identifier and string.format("%s#%s", title, identifier) or title
      local f = io.open(fname, "w")
      f:write(txt)
      f:close()

      io.write(string.format("wrote %s\n", fname))
    end
  end

  -- suppress normal output (we've done all the work already)
  return pandoc.Pandoc({}, doc.meta)
end
