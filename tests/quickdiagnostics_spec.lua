local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local before_each = require("plenary.busted").before_each
local after_each = require("plenary.busted").after_each

local ERROR = vim.diagnostic.severity.ERROR
local WARN = vim.diagnostic.severity.WARN
local INFO = vim.diagnostic.severity.INFO
local HINT = vim.diagnostic.severity.HINT

local DEFAULT_EFM = table.concat({
    [[%f:%l:%c:\ %trror:\ %m]],
    [[%f:%l:%c:\ %tarning:\ %m]],
    [[%f:%l:%c:\ %tnfo:\ %m]],
    [[%f:%l:%c:\ %tote:\ %m]],
    [[%f:%l:%c:\ %m]],
}, ",")

local tmpdir
local a_path
local b_path
local output_path

-- Runs :make with makeprg printing `lines` verbatim. A file is used instead
-- of printf so `%` in makeprg is never expanded to the current file name.
local function run_make(lines)
    vim.fn.writefile(lines, output_path)
    vim.o.makeprg = "cat " .. vim.fn.shellescape(output_path)
    vim.cmd("silent make!")
end

describe("quickdiagnostics", function()
    before_each(function()
        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        a_path = tmpdir .. "/a.c"
        b_path = tmpdir .. "/b.c"
        output_path = tmpdir .. "/make_output.txt"
        vim.fn.writefile({ "line 1", "line 2", "line 3", "line 4", "line 5" }, a_path)
        vim.fn.writefile({ "line 1", "line 2", "line 3" }, b_path)
        vim.o.errorformat = DEFAULT_EFM
    end)

    after_each(function()
        vim.fn.setqflist({}, "f")
        vim.fn.setloclist(0, {}, "f")
        vim.diagnostic.reset()
        vim.cmd("silent! %bwipeout!")
        vim.fn.delete(tmpdir, "rf")
    end)

    describe("on :make", function()
        it("creates one diagnostic per valid entry", function()
            run_make({
                a_path .. ":1:1: error: one",
                a_path .. ":2:1: error: two",
                a_path .. ":3:1: error: three",
            })
            assert.are.equal(3, #vim.diagnostic.get(vim.fn.bufadd(a_path)))
        end)

        it("places diagnostics on the entry's buffer", function()
            run_make({ a_path .. ":1:1: error: boom" })
            local diagnostics = vim.diagnostic.get(vim.fn.bufadd(a_path))
            assert.are.equal(1, #diagnostics)
            assert.are.equal(vim.fn.bufnr(a_path), diagnostics[1].bufnr)
        end)

        it("converts lnum/col to 0-based", function()
            run_make({ a_path .. ":3:5: error: boom" })
            local diagnostics = vim.diagnostic.get(vim.fn.bufadd(a_path))
            assert.are.equal(2, diagnostics[1].lnum)
            assert.are.equal(4, diagnostics[1].col)
        end)

        it("treats col 0 as column 0", function()
            vim.o.errorformat = [[%f:%l:\ %m]]
            run_make({ a_path .. ":2: boom" })
            local diagnostics = vim.diagnostic.get(vim.fn.bufadd(a_path))
            assert.are.equal(1, diagnostics[1].lnum)
            assert.are.equal(0, diagnostics[1].col)
        end)

        it("honours end_lnum/end_col when present", function()
            vim.o.errorformat = [[%f:%l:%c:%e:%k:\ %m]]
            run_make({ a_path .. ":1:2:3:4: span" })
            local diagnostics = vim.diagnostic.get(vim.fn.bufadd(a_path))
            assert.are.equal(0, diagnostics[1].lnum)
            assert.are.equal(1, diagnostics[1].col)
            assert.are.equal(2, diagnostics[1].end_lnum)
            assert.are.equal(3, diagnostics[1].end_col)
        end)

        it("uses the entry text as the message", function()
            run_make({ a_path .. ":1:1: error: something broke" })
            assert.are.equal("something broke", vim.diagnostic.get(vim.fn.bufadd(a_path))[1].message)
        end)

        it("handles entries across multiple files", function()
            run_make({
                a_path .. ":1:1: error: in a",
                b_path .. ":2:1: error: in b",
            })
            local a_diagnostics = vim.diagnostic.get(vim.fn.bufadd(a_path))
            local b_diagnostics = vim.diagnostic.get(vim.fn.bufadd(b_path))
            assert.are.equal(1, #a_diagnostics)
            assert.are.equal(1, #b_diagnostics)
            assert.are.equal("in a", a_diagnostics[1].message)
            assert.are.equal("in b", b_diagnostics[1].message)
        end)

        it("sets source to \"quickfixdiagnostics\"", function()
            run_make({ a_path .. ":1:1: error: boom" })
            assert.are.equal("quickfixdiagnostics", vim.diagnostic.get(vim.fn.bufadd(a_path))[1].source)
        end)
    end)

    describe("severity", function()
        local cases = {
            { "E", ERROR, "ERROR" },
            { "e", ERROR, "ERROR" },
            { "W", WARN, "WARN" },
            { "w", WARN, "WARN" },
            { "I", INFO, "INFO" },
            { "i", INFO, "INFO" },
            { "N", HINT, "HINT" },
            { "n", HINT, "HINT" },
        }

        for _, case in ipairs(cases) do
            local type_char, expected, name = case[1], case[2], case[3]
            it("maps '" .. type_char .. "' to " .. name, function()
                vim.o.errorformat = [[%f:%l:%c:\ %t:\ %m]]
                run_make({ a_path .. ":1:1: " .. type_char .. ": boom" })
                assert.are.equal(expected, vim.diagnostic.get(vim.fn.bufadd(a_path))[1].severity)
            end)
        end

        it("maps the type captured from 'error' to ERROR", function()
            run_make({ a_path .. ":1:1: error: boom" })
            assert.are.equal(ERROR, vim.diagnostic.get(vim.fn.bufadd(a_path))[1].severity)
        end)

        it("maps the type captured from 'warning' to WARN", function()
            run_make({ a_path .. ":1:1: warning: boom" })
            assert.are.equal(WARN, vim.diagnostic.get(vim.fn.bufadd(a_path))[1].severity)
        end)

        it("maps an empty type (no %t in errorformat) to INFO", function()
            run_make({ a_path .. ":1:1: boom" })
            assert.are.equal(INFO, vim.diagnostic.get(vim.fn.bufadd(a_path))[1].severity)
        end)

        it("maps an unrecognised type char to INFO", function()
            vim.o.errorformat = [[%f:%l:%c:\ %t:\ %m]]
            run_make({ a_path .. ":1:1: x: boom" })
            assert.are.equal(INFO, vim.diagnostic.get(vim.fn.bufadd(a_path))[1].severity)
        end)
    end)

    describe("filtering", function()
        it("skips entries with valid == 0", function()
            run_make({
                "this line matches nothing",
                a_path .. ":1:1: error: boom",
            })
            assert.are.equal(1, #vim.diagnostic.get())
        end)

        it("skips entries with bufnr == 0", function()
            vim.o.errorformat = [[%l:\ %m,%f:%l:%c:\ %m]]
            run_make({
                "7: no file here",
                a_path .. ":1:1: boom",
            })
            local diagnostics = vim.diagnostic.get()
            assert.are.equal(1, #diagnostics)
            assert.are.equal("boom", diagnostics[1].message)
        end)
    end)

    describe("re-running :make", function()
        it("replaces previous diagnostics", function()
            run_make({ a_path .. ":1:1: error: first" })
            run_make({ a_path .. ":2:1: error: second" })
            local diagnostics = vim.diagnostic.get(vim.fn.bufadd(a_path))
            assert.are.equal(1, #diagnostics)
            assert.are.equal("second", diagnostics[1].message)
        end)

        it("clears all diagnostics when :make yields no errors", function()
            run_make({
                a_path .. ":1:1: error: in a",
                b_path .. ":1:1: error: in b",
            })
            run_make({})
            assert.are.equal(0, #vim.diagnostic.get())
        end)

        it("clears a buffer whose errors disappeared", function()
            run_make({
                a_path .. ":1:1: error: in a",
                b_path .. ":1:1: error: in b",
            })
            run_make({ b_path .. ":1:1: error: in b" })
            assert.are.equal(0, #vim.diagnostic.get(vim.fn.bufadd(a_path)))
            assert.are.equal(1, #vim.diagnostic.get(vim.fn.bufadd(b_path)))
        end)
    end)

    describe("isolation", function()
        it("leaves diagnostics in other namespaces untouched", function()
            local other = vim.api.nvim_create_namespace("quickdiagnostics_test_other")
            local bufnr = vim.fn.bufadd(a_path)
            vim.fn.bufload(bufnr)
            vim.diagnostic.set(other, bufnr, {
                { lnum = 0, col = 0, message = "from lsp", severity = WARN },
            })

            run_make({ a_path .. ":2:1: error: from make" })
            run_make({})

            local diagnostics = vim.diagnostic.get(bufnr, { namespace = other })
            assert.are.equal(1, #diagnostics)
            assert.are.equal("from lsp", diagnostics[1].message)
        end)
    end)

    describe("non-triggers", function()
        it(":lmake does nothing", function()
            vim.fn.writefile({ a_path .. ":1:1: error: boom" }, output_path)
            vim.o.makeprg = "cat " .. vim.fn.shellescape(output_path)
            vim.cmd("silent lmake!")
            assert.are.equal(0, #vim.diagnostic.get())
        end)

        it(":grep does nothing", function()
            vim.fn.writefile({ a_path .. ":1:1: error: boom" }, output_path)
            vim.o.grepprg = "cat " .. vim.fn.shellescape(output_path)
            vim.o.grepformat = DEFAULT_EFM
            vim.cmd("silent grep!")
            assert.are.equal(0, #vim.diagnostic.get())
        end)

        it(":vimgrep does nothing", function()
            vim.cmd("silent! vimgrep /line/j " .. vim.fn.fnameescape(a_path))
            assert.is_true(#vim.fn.getqflist() > 0)
            assert.are.equal(0, #vim.diagnostic.get())
        end)

        it(":cexpr does nothing", function()
            vim.fn.execute("cexpr [" .. vim.fn.string(a_path .. ":1:1: error: boom") .. "]")
            assert.is_true(#vim.fn.getqflist() > 0)
            assert.are.equal(0, #vim.diagnostic.get())
        end)

        it("setqflist() does nothing", function()
            vim.fn.setqflist({
                { filename = a_path, lnum = 1, col = 1, text = "boom", type = "E" },
            })
            assert.are.equal(0, #vim.diagnostic.get())
        end)
    end)
end)
