return {
  {
    "hedyhli/outline.nvim",
    lazy = true,
    cmd = { "Outline", "OutlineOpen" },
    keys = {
      { "<leader>o", "<cmd>Outline<CR>", desc = "Toggle outline" },
    },
    opts = {
      outline_window = {
        position = 'right',
        width = 25,
        relative_width = true,
      },
      outline_items = {
        show_symbol_details = true,
        show_symbol_lineno = false,
      },
      keymaps = {
        close = {'<Esc>', 'q'},
        goto_location = '<Cr>',
        peek_location = 'o',
        restore_location = '<C-g>',
        hover_symbol = '<C-space>',
        toggle_preview = 'K',
        rename_symbol = 'r',
        code_actions = 'a',
        fold = 'h',
        unfold = 'l',
        fold_toggle = '<Tab>',
        fold_toggle_all = '<S-Tab>',
        fold_all = 'W',
        unfold_all = 'E',
        fold_reset = 'R',
      },
      providers = {
        priority = { 'lsp', 'markdown' },
        lsp = {
          blacklist_clients = {},
        },
        markdown = {
          filetypes = {'markdown'},
        },
      },
    },
  },
}
