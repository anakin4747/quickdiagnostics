vim.opt.swapfile = false
vim.opt.runtimepath:append('.')
vim.cmd('runtime plugin/plenary.vim')
vim.cmd('runtime plugin/quickdiagnostics.lua')

vim.g.i_am_in_a_test = true
