
# quickdiagnostics

Neovim plugin for feeding `:make`'s `'errorfile'` to Neovim diagnostics.

The goal of this plugin is to get LSP like diagnostics from Vim's `:compiler`
plugins

## usage

Install it with your plugin manager or with `vim.pack`:

```lua
vim.pack.add('https://github.com/anakin4747/quickdiagnostics')
```

Then select your `:compiler`:

```vim
:compiler ruff
```

Then run `:make`:

```vim
:make %
```

Any diagnostics made by the `:compiler` in this case `ruff` will be seen as
diagnostics.

