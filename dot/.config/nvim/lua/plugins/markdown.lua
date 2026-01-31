return {
  -- Live Markdown rendering with colors (headings, tables, etc.)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "rmd" },  -- Load only for Markdown files
    opts = {
      heading = {
        icons = { "󰘎", "󰏒", "󰏘", "󰏠", "󰏪", "󰏲", "󰢎" },  -- Custom icons for headings (optional)
      },
      code = {
        sign = true,  -- Add line numbers to code blocks
      },
      file_types = { "markdown", "rmd" },
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)
      -- Optional: Toggle with <leader>rm (remap if you want <leader>md)
      local rm = require("render-markdown")
      vim.keymap.set("n", "<leader>rm", rm.toggle, { desc = "Toggle Markdown Render" })
    end,
  },

  -- Outline/Table of Contents sidebar
  {
    "stevearc/aerial.nvim",
    opts = {
      on_attach = function(bufnr)
        -- Jump to symbol under cursor
        vim.keymap.set("n", "<leader>o", "<cmd>AerialToggle!<cr>", { buffer = bufnr, desc = "Toggle Outline" })
      end,
      filter_kind = false,  -- Show all (headings, etc.)
      layout = {
        default_direction = "right",  -- Open on the right side
        min_width = 30,
      },
      manage_focus = true,  -- Auto-focus when opening
    },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
  },
}
