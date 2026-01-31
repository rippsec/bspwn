return {
  {
    "NvChad/nvim-colorizer.lua",
    event = "VeryLazy", -- Load lazily to avoid startup issues
    config = function()
      require("colorizer").setup({
        filetypes = { "*" }, -- Enable for all filetypes
        user_default_options = {
          RGB = true,         -- #RGB hex codes
          RRGGBB = true,      -- #RRGGBB hex codes
          names = true,       -- Named colors like "red"
          rgb_fn = true,      -- CSS rgb() and rgba()
          hsl_fn = false,     -- Optional: hsl() and hsla()
          css = false,        -- Optional: enable all CSS features
          css_fn = false,     -- Optional: enable all CSS functions
          mode = "background" -- Display color as background
        }
      })

      -- Optional: attach to current buffer immediately
      vim.defer_fn(function()
        require("colorizer").attach_to_buffer(0)
      end, 0)
    end,
  }
}

