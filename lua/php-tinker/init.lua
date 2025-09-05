local M = {}

-- gsplit: iterate over substrings in a string separated by a pattern
-- stolen from somewhere probably
--
-- Parameters:
-- text (string)    - the string to iterate over
-- pattern (string) - the separator pattern
-- plain (boolean)  - if true (or truthy), pattern is interpreted as a plain
--                    string, not a Lua pattern
--
-- Returns: iterator
--
-- Usage:
-- for substr in gsplit(text, pattern, plain) do
--   doSomething(substr)
-- end
local function gsplit(text, pattern, plain)
	local splitStart, length = 1, #text
	return function()
		if splitStart then
			local sepStart, sepEnd = string.find(text, pattern, splitStart, plain)
			local ret
			if not sepStart then
				ret = string.sub(text, splitStart)
				splitStart = nil
			elseif sepEnd < sepStart then
				-- Empty separator!
				ret = string.sub(text, splitStart, sepStart)
				if sepStart < length then
					splitStart = sepStart + 1
				else
					splitStart = nil
				end
			else
				ret = sepStart > splitStart and string.sub(text, splitStart, sepStart - 1) or ""
				splitStart = sepEnd + 1
			end
			return ret
		end
	end
end

-- split: split a string into substrings separated by a pattern.
-- stolen from somewhere probably
--
-- Parameters:
-- text (string)    - the string to iterate over
-- pattern (string) - the separator pattern
-- plain (boolean)  - if true (or truthy), pattern is interpreted as a plain
--                    string, not a Lua pattern
--
-- Returns: table (a sequence table containing the substrings)
local function str_split(text, pattern, plain)
	local ret = {}
	for match in gsplit(text, pattern, plain) do
		table.insert(ret, match)
	end
	return ret
end

local function str_finish(inputstr, suffix)
	if vim.endswith(inputstr, suffix) then
		return inputstr
	end
	return inputstr .. suffix
end

local function str_beforeLast(inputstr, needle)
	local result, _ = string.gsub(inputstr, "^(.*)" .. needle .. ".*$", "%1")
	return result
end

M.fake_scratch_buffer = function(set_buffer_name_to)
	local already_set_name = vim.api.nvim_buf_get_name(0)
	if already_set_name ~= "" then
		error(string.format("Cannot make %s a scratch buffer", vim.inspect(already_set_name)))
	end
	if not set_buffer_name_to then
		set_buffer_name_to = "php-tinker-" .. vim.loop.hrtime() .. ".php"
	end
	vim.cmd.file(set_buffer_name_to)
	vim.o.bufhidden = "wipe"
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = 0,
		callback = function() end,
	})
	vim.api.nvim_create_autocmd("BufModifiedSet", {
		buffer = 0,
		callback = function()
			vim.o.modified = false
		end,
	})
end

M.run_tinker = function()
	vim.cmd("set ft=php")

	-- MARK: get contents and context
	local contents = vim.trim(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"))
	if contents ~= "<?php" then
		contents = str_finish(contents, ";")
	end
	local b64contents = vim.base64.encode(contents)
	local working_dir = vim.fn.getcwd()

	-- MARK: Get php version
	local getPhpVersion_Command = "php -v | grep \"PHP [0-9]\\.[0-9]\" | sed 's/^.* \\([0-9]\\.[0-9]\\).*$/\\1/'"
	local phpver_handle = io.popen(getPhpVersion_Command)
	if not phpver_handle then
		print("PHP version retrieval failed. Please ensure PHP is installed and is in your path.")
		return
	end
	local phpver_result = vim.trim(phpver_handle:read("*a"))
	phpver_handle:close()
	local versionValid = string.match(phpver_result, "%d%.%d") ~= nil

	if not versionValid then
		print("PHP version response was an improper format.\n" .. phpver_result)
		return
	end

	local pluginDirectory = str_beforeLast(debug.getinfo(1).source:sub(2), "/")

	-- MARK: run command
	local command =
			string.format('php %s/client-%s.phar %s execute "%s"', pluginDirectory, phpver_result, working_dir, b64contents)
	local handle = io.popen(command)
	if not handle then
		print("Failed to run tinker client with version " .. phpver_result)
		return
	end
	local result = handle:read("*a")
	handle:close()

	-- MARK: process/prettify results
	-- first we ensure a successful result
	if not vim.startswith(result, "TWEAKPHP_RESULT") then
		vim.notify(result, vim.log.levels.ERROR)
		do
			return
		end
	end

	-- then we parse the result
	local datastr = result:sub(("TWEAKPHP_RESULT:"):len() + 1)
	local data = vim.json.decode(datastr)

	local info_contents = ""

	for _, value in ipairs(data.output) do
		if vim.trim(info_contents) ~= "" then
			info_contents = info_contents .. "\n\n\n"
		end

		if value.output and value.output ~= "" then
			info_contents = info_contents .. " // LINE " .. value.line .. "\n\n" .. value.output
		end
	end

    local olddata = vim.g.dakin_php_tinker

	-- MARK: create split buffer
	local workingWin = vim.api.nvim_get_current_win()
	olddata.state.workingWin = workingWin

	local win, buf
	-- restore existing window if possible
	if olddata.state.win == nil or not vim.api.nvim_win_is_valid(olddata.state.win) then
		vim.cmd("vsplit")
		win = vim.api.nvim_get_current_win()
		olddata.state.win = win
	else
		win = olddata.state.win
	end

	--restore existing buffer if possible
	if olddata.state.buf == nil or not vim.api.nvim_buf_is_valid(olddata.state.buf) then
		buf = vim.api.nvim_create_buf(true, false)
		olddata.state.buf = buf
		vim.api.nvim_win_set_buf(win, buf)
		M.fake_scratch_buffer("php-tinker-output.php")
	else
		buf = olddata.state.buf
		vim.api.nvim_win_set_buf(win, buf)
	end

	vim.cmd("set ft=php") -- add syntax highlighting

	-- switch back to editor window
	vim.api.nvim_set_current_win(workingWin)

	-- add <?php if not already present to keep line numbers consistent
	if not vim.startswith(contents, "<?php") then
		contents = "<?php\n" .. contents
		vim.api.nvim_buf_set_lines(0, 0, -1, false, str_split(contents, "\n", true))
	end

	-- Placeholder results text
	if info_contents == "" then
		info_contents = "\n\n\n// Get started by entering some code into the left window"
	end
	-- send processed results to results buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, str_split(info_contents, "\n", true))

    -- Placeholder results text
    if info_contents == "" then
        info_contents = "\n\n\n// Get started by entering some code into the left window"
    end
    -- send processed results to results buffer
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, str_split(info_contents, "\n", true))

    -- save state
    vim.g.dakin_php_tinker = olddata
end

M.setup = function(opts)
	opts = opts or {}

    -- prepare state table
    vim.g.dakin_php_tinker = { state = { buf = nil, win = nil, workingWin = nil } }

    -- have some fallback in case the user wants one for their callback
    -- or doesn't specify their own template
    local defaultTemplate = { "\"Tinker away!\"" }

    local template_content = opts.template_content or defaultTemplate

    -- easily bootable tinker window
    vim.api.nvim_create_user_command('PhpTinker', function()
        local buf = vim.api.nvim_create_buf(true, true)
		vim.api.nvim_set_option_value("filetype", "php", { buf = buf })
		vim.api.nvim_win_set_buf(0, buf)

        M.fake_scratch_buffer("php-tinker-main.php")

        -- prepare the template
        local template = { "<?php", "", }
        local additional_template_content = template_content
        -- if the template_content is a callback, run it with the defaultTemplate as a param
        if type(template_content) == "function" then
            additional_template_content = template_content(defaultTemplate)
        end

        vim.list_extend(template, additional_template_content)

        vim.api.nvim_buf_set_lines(buf, 0, 1, false, template) -- example code
        vim.api.nvim_win_set_cursor(0, { #template, 0 })       -- position cursor

		vim.api.nvim_buf_create_user_command(buf, "PhpTinkerRun", M.run_tinker, {})

		-- setup Refresh rePl keymap
		if opts.keymaps and opts.keymaps.run_tinker then
			vim.keymap.set("n", opts.keymaps.run_tinker, M.run_tinker, { buffer = true })
		end

		-- initialize results window by running once at startup
		M.run_tinker()
	end, {})
end

return M
