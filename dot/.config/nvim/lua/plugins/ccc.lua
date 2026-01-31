return {
  "uga-rosa/ccc.nvim",
  name = "ccc",
  lazy = false,
  config = function()
    require("ccc").setup({
      highlighter = {
        enabled = true,
        auto_enable = true,
      },
    })
    -- Keymap to open CccPick
    vim.keymap.set("n", "<leader>cp", "<cmd>CccPick<cr>", { desc = "Open color picker" })
  end,
}
