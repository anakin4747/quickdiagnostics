if vim.g.loaded_quickdiagnostics then
    return
end
vim.g.loaded_quickdiagnostics = true

local namespace = vim.api.nvim_create_namespace("quickfixdiagnostics")

local severities = {
    E = vim.diagnostic.severity.ERROR,
    W = vim.diagnostic.severity.WARN,
    I = vim.diagnostic.severity.INFO,
    N = vim.diagnostic.severity.HINT,
}

vim.api.nvim_create_autocmd("QuickFixCmdPost", {
    group = vim.api.nvim_create_augroup("quickdiagnostics", { clear = true }),
    pattern = "make",
    callback = function()
        local diagnostics_by_buffer = {}

        for _, item in ipairs(vim.fn.getqflist()) do
            if item.valid == 1 and item.bufnr > 0 then
                local lnum = math.max(0, item.lnum - 1)
                local col = math.max(0, item.col - 1)
                diagnostics_by_buffer[item.bufnr] = diagnostics_by_buffer[item.bufnr] or {}
                table.insert(diagnostics_by_buffer[item.bufnr], {
                    lnum = lnum,
                    col = col,
                    end_lnum = item.end_lnum > 0 and item.end_lnum - 1 or lnum,
                    end_col = item.end_col > 0 and item.end_col - 1 or col,
                    severity = severities[item.type:upper()] or vim.diagnostic.severity.INFO,
                    message = item.text,
                    source = "quickfixdiagnostics",
                })
            end
        end

        vim.diagnostic.reset(namespace)
        for bufnr, diagnostics in pairs(diagnostics_by_buffer) do
            vim.diagnostic.set(namespace, bufnr, diagnostics)
        end
    end,
})
