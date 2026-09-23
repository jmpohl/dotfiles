-- kept in a global so re-sourcing this file does not lose it
_G.KvHandoff = _G.KvHandoff or nil

function _G.KvEnter(file, line, col, top, handoff)
  _G.KvHandoff = handoff
  -- kv can be started with no file, to attach to the session as it was left
  if file == '' then
    return
  end
  if vim.api.nvim_buf_get_name(0) ~= file then
    pcall(vim.cmd.edit, vim.fn.fnameescape(file))
  end
  vim.cmd.checktime()
  line = math.min(line, vim.api.nvim_buf_line_count(0))
  col = math.min(col, #vim.fn.getline(line) + 1)
  if top and top > 0 then
    vim.fn.winrestview({ topline = top, lnum = line, col = math.max(col - 1, 0) })
  else
    vim.api.nvim_win_set_cursor(0, { line, math.max(col - 1, 0) })
  end
end

local function kv_swap()
  local file = vim.api.nvim_buf_get_name(0)
  if not _G.KvHandoff or file == '' then
    vim.notify('kv-swap: needs a file buffer started by kv', vim.log.levels.ERROR)
    return
  end
  if vim.bo.modified then
    vim.cmd.write()
  end
  local pos = vim.api.nvim_win_get_cursor(0)
  vim.fn.writefile({
    'kak',
    tostring(pos[1]),
    tostring(pos[2] + 1),
    tostring(vim.fn.line 'w0'),
    -- kakoune reports resolved paths, so resolve here too, otherwise a symlink
    -- comes back as a second buffer for the same file
    vim.uv.fs_realpath(file) or file,
  }, _G.KvHandoff)
  vim.cmd('detach')
end

vim.keymap.set('n', '<F8>', kv_swap, { desc = 'Swap to kakoune' })
