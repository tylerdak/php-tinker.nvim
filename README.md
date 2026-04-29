# php-tinker.nvim
A PHP REPL right in your editor! Tinker away without sacrificing your blessed keybinds!

![Preview of php-tinker.nvim editor](https://github.com/user-attachments/assets/64659f5c-0b71-45e1-b7c8-98f473cbc581)
<details>
  <summary>See it in action</summary>

  <video src="https://github.com/user-attachments/assets/5c3b31e5-63d7-49f0-b872-58e711a9278c">Demo video</video>

</details>

## Usage
As long as you're in a PHP project, run `:PhpTinker` to open two buffers split on the screen.
> If you don't see two buffers in split screen, it's likely because you're not in a PHP project that could be found by the [TweakPHP client](https://github.com/tweakphp/client).

If you see the text "Tinker away!" on both screens, you're good to go! You can edit the left buffer, then run `:PhpTinkerRun` and you'll see the evaluation in the right buffer.

## Requirements
- PHP
  - Currently, versions 8.2, 8.3, and 8.4 are supported
  - `php` must be in your path so we can run [the client](https://github.com/tweakphp/client)
  - If you're using a version other than those listed above, feel free to submit a pull request adding that version of [the client phar](https://github.com/tweakphp/client).
- grep & sed
  - We use these to detect your PHP version. php-tinker runs `php -v` and then pipes it to grep and sed to pull out the version (e.g. `8.4`).
- Neovim 0.11+
  - I think I tested this on 0.10 before I upgraded, but currently I'm only testing this on 0.11
 
## Installation
In your favorite package manager, add `tylerdak/php-tinker.nvim`. I use lazy, here's my config:
```lua
{
    "tylerdak/php-tinker.nvim",
    opts = {
        keymaps = {
            run_tinker = "<CR>"
        },
        -- Automatically download the client phar for your current PHP version
        -- See lua/php-tinker/init.lua:96 for the command being ran
        auto_download = true,
    }
}
```

## Configuration
I suggest starting with the above if you're using lazy. Once you've added the plugin to your manager, you could technically be up and running on your next restart. However, I suggest adding a keymap like I do above.

The `run_tinker` keymap defines what keymap in normal mode will trigger the `:PhpTinkerRun` command.
> For consistency with something like CodeCompanion, `<CR>` feels like a nice default to try first. When developing this I was using `<Leader>rp` (for RunPhp, I guess) but that was pretty goofy and not very intuitive.

## Troubleshooting
<details>
  <summary>`Invalid Path` when running `:PhpTinker`</summary>
  
  This means your project isn't being loaded properly by [the TweakPHP client](https://github.com/tweakphp/client/blob/8e3f588a89de86e1055d22f6a862123992db7973/src/Loader.php#L27). 
  
  Any Laravel, WordPress, or Symfony project should be picked up automatically, but at a minimum your project directory should have a vendor/autoload.php file so the client's ComposerLoader can find your project. 

  If you _really_ want to avoid Composer for some reason, you can even get away with a nearly blank php file at vendor/autoload.php like this:
  
  ```php
  <?php
  ```

  No other files necessary. Just a quick `mkdir vendor && echo "<?php" > vendor/autoload.php` should do the trick.
  
</details>

<details>
  <summary>Are semicolons required or not?</summary>
  
  Semicolons **are required** for every PHP statement you would normally need one on **except for the last line**. So when you write your first line in the buffer, you could leave it off. However, once you start adding more code you'd need to go back and add a semicolon to that first statement you wrote.
  
  The last line can have a semicolon too if that's what you really want, though.
  
</details>

## Roadmap

If I have time, I might tackle some of these:
- Add more configuration where applicable
  - e.g. hooks for the startup process, so you can replace the default `"Tinker away!"` text with something useful like dependency imports
- Add a help entry
- Automatic client download for your relevant PHP version
  - Feels somewhat silly and wasteful to have several client versions in the repo
  - It'd be cool to build the client using the user's installed PHP if it doesn't exist
- Savable tinker sessions
- LSP/cmp support would be really poggers but I have no clue how to do that yet

> Feel free to submit PRs or ideas for getting the above done, though!
