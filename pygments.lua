label = 'Pygments'

about = [[
Format source code with pygments
]]

function ensurePreamble(model)
  local preamble_begin_marker = '%%% BEGIN PYGMENTS PREAMBLE %%%'
  local use_packages = '\\usepackage{color}\n\\usepackage{fancyvrb}'
  local get_preamble_py_code = 'from pygments.formatters import LatexFormatter; print(LatexFormatter().get_style_defs())'

  local props = model.doc:properties()
  local preamble = props['preamble']
  if preamble:find(preamble_begin_marker, 1, true) then return true end

  if not prefs.pygments.python then model:warning('Missing setting prefs.pygments.python') return false end

  local p, open_err = _G.io.popen(prefs.pygments.python .. ' -c "' .. get_preamble_py_code .. '"', 'r')
  if not p then model:warning('Failed to execute pygment python: ' .. model_err) return false end
  local defs, read_err = assert(p:read('*a'))
  if not defs then model:warning('Failed to read from python process: ' .. read_err) return false end
  local close, close_err = p:close()
  if not close then model:warning('Failed to close python process: ' .. close_err) return false end

  if preamble:len() > 0 then
    preamble = preamble .. '\n\n'
  end
  preamble = preamble .. preamble_begin_marker .. '\n' .. use_packages .. '\n' .. defs .. '%%% END PYGMENTS PREAMBLE %%%\n\n'
  model.doc:setProperties({preamble=preamble})
  return true
end

function askLanguage(model)
  local d = ipeui.Dialog(model.ui:win(), 'Pygments')
  d:add('label1', 'label', {label='Language'}, 1, 1, 1, 1)
  d:add('language', 'input', {}, 1, 2, 1, 1)
  d:addButton('ok', '&Ok', 'accept')
  d:addButton('cancel', '&Cancel', 'reject')
  if not d:execute() then return end
  return d:get('language')
end

function encodeInput(language, source_code)
  local result = '%%% PYGMENTS LANGUAGE: ' .. language .. '\n%%% PYGMENTS SOURCE CODE BEGIN %%%\n'
  for s in source_code:gmatch('[^\n]*\n?') do
    result = result .. '% ' .. s
  end
  if not source_code:find('\n$') then
    result = result .. '\n'
  end
  return result .. '%%% PYGMENTS SOURCE CODE END %%%\n\n'
end

function recoverInput(model, latex)
  local language = latex:match('%%%%%% PYGMENTS LANGUAGE: (%w+)')
  if not language then return end

  local _, i = latex:find('%%% PYGMENTS SOURCE CODE BEGIN %%%\n', 1, true)
  if not i then return end

  local j = latex:find('%%% PYGMENTS SOURCE CODE END %%%\n', i + 1, true)
  local commented_code = latex:sub(i + 1, j - 1)
  local code = nil
  for s in commented_code:gmatch('%% ([^\n]*)\n') do
    if code then
      code = code .. '\n' .. s
    else
      code = s
    end
  end
  return language, code
end

function ensureTextSelection(model)
  local p = model:page()
  local prim = p:primarySelection()
  if not prim then model.ui:explain('no selection') return end

  local obj = p[prim]
  if obj:type() ~= 'text' then model:warning('Primary selection is not a text object') return end
  return obj
end

function doFormat(model, obj, source_code, language, action_label)
  local result = encodeInput(language, source_code)

  local tmp_in, tmp_err1 = _G.os.tmpname()
  if not tmp_in then model:warning('Failed to create temp file: ' .. tmp_err1) return end
  local tmp_out, tmp_err2 = _G.os.tmpname()
  if not tmp_in then model:warning('Failed to create temp file: ' .. tmp_err2) return end

  local file_in, file_in_err = _G.io.open(tmp_in, 'w')
  if not file_in then model:warning('Failed to open temp file ' .. tmp_in .. ': ' .. file_in_err) return end
  local write, write_err = file_in:write(source_code)
  if not write then model:warning('Failed to write to temp file: ' .. write_err) return end
  local close1, close1_err = file_in:close()
  if not close1 then model:warning('Failed to close temp file: ' .. close1_err) return end

  if not prefs.pygments.pygmentize then model:warning('Missing settings prefs.pygments.pygmentize') return end
  _G.os.execute(prefs.pygments.pygmentize .. ' -l ' .. language .. ' -f latex -o ' .. tmp_out .. ' ' .. tmp_in)

  local file_out, file_out_err = _G.io.open(tmp_out, 'r')
  if not file_out then model:warning('Failed to open temp file ' .. tmp_out .. ': ' .. file_out_err) return end
  local pygments_code, read_err = file_out:read('*a')
  if not pygments_code then model:warning('Failed to read from temp file: ' .. read_err) return end
  result = result .. pygments_code
  local close2, close2_err = file_out:close()
  if not close2 then model:warning('Failed to close temp file: ' .. close2_err) return end

  local remove1, remove1_err = _G.os.remove(tmp_in)
  if not remove1 then model:warning('Failed to delete temp file ' .. tmp_in .. ': ' .. remove1_err) return end
  local remove2, remove2_err = _G.os.remove(tmp_out)
  if not remove2 then model:warning('Failed to delete temp file ' .. tmp_out .. ': ' .. remove2_err) return end

  local t = {
    label=action_label,
    pno=model.pno,
    vno=model.vno,
    minipage=obj:get('minipage'),
    text=obj:text(),
    obj=obj,
    result=result,
  }
  t.redo = function (t)
    t.obj:setText(t.result)
    t.obj:set('minipage', true)
    -- Calling runLatex here to show results segfaults ipe :(
  end
  t.undo = function (t)
    t.obj:setText(t.text)
    t.obj:set('minipage', t.minipage)
  end
  t.redo(t)
  model:register(t)
end

function format(model)
  local obj = ensureTextSelection(model)
  if not obj then return end

  local language = askLanguage(model)
  if not language then return end

  if not ensurePreamble(model) then return end

  local source_code = obj:text()
  doFormat(model, obj, source_code, language, 'Pygments format')
end

function revert(model)
  local obj = ensureTextSelection(model)
  if not obj then return end

  local latex = obj:text()
  local _language, code = recoverInput(model, latex)
  if not code then model:warning('Nothing to revert') return end

  local t = {
    label='Pygments revert',
    pno=model.pno,
    vno=model.vno,
    text=obj:text(),
    obj=obj,
    code=code,
  }
  t.redo = function (t)
    t.obj:setText(t.code)
  end
  t.undo = function (t)
    t.obj:setText(t.text)
  end
  t.redo(t)
  model:register(t)
end

function edit(model)
  if not ensurePreamble(model) then return end

  local obj = ensureTextSelection(model)
  if not obj then return end

  local latex = obj:text()
  local language, code = recoverInput(model, latex)
  if not code then model:warning('No encoded source code found') return end

  local d = ipeui.Dialog(model.ui:win(), 'Pygments')
  d:add('label1', 'label', {label='Language'}, 1, 1, 1, 1)
  d:add('language', 'input', {}, 1, 2, 1, 1)
  d:set('language', language)
  d:add('code', 'text', {}, 2, 1, 1, 2)
  d:set('code', code)
  d:addButton('ok', '&Ok', 'accept')
  d:addButton('cancel', '&Cancel', 'reject')
  if not d:execute() then return end

  doFormat(model, obj, d:get('code'), d:get('language'), 'Pygments edit')
end

methods = {
  { label='Format', run=format },
  { label='Edit', run=edit },
  { label='Revert', run=revert },
}
