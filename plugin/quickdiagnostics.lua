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

local function get_line(bufnr, lnum)
    if vim.api.nvim_buf_is_loaded(bufnr) then
        return vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
    end
    local path = vim.api.nvim_buf_get_name(bufnr)
    if vim.fn.filereadable(path) == 0 then
        return nil
    end
    return vim.fn.readfile(path, "", lnum + 1)[lnum + 1]
end

-- Returns the 0-based exclusive end of the word under col, or col when
-- there is no word there.
local function word_end(bufnr, lnum, col)
    local line = get_line(bufnr, lnum)
    if not line then
        return col
    end
    local word = line:match("^[%w_]+", col + 1)
    if not word then
        return col
    end
    return col + #word
end

local function end_col_for(item, lnum, col)
    if item.end_col > 0 then
        return item.end_col - 1
    end
    if item.col == 0 then
        return col
    end
    return word_end(item.bufnr, lnum, col)
end

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
                    end_col = end_col_for(item, lnum, col),
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
