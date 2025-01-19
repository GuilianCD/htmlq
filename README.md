
# Htmlq

## Overview

> In short: [jq](https://jqlang.github.io/jq/), but for HTML

This project is a from-scratch implementation of an HTML and CSS parser, written entirely in Lua. No external dependencies. It's designed to take HTML and CSS as input and provide a way to query the Document Object Model (DOM) using CSS selectors.

## Features

There's really only one feature: it takes in HTML and a CSS selector, and returns whatever is matched by that selector in the DOM.

Supported simple selectors:
* **tag name** - `h1`
* **class** - `.class`
* **id** - `#id`

And any _compound_ selector (like `p.text-center.bold` matching all `p`s that have the `text-center` and `bold` class)


Supported combinators are all the "basic" ones:
* ` ` - the [descendant combinator](https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/Styling_basics/Combinators#descendant_combinator)
* `>` - the [child combinator](https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/Styling_basics/Combinators#child_combinator)
* `+` - the [next sibling combinator](https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/Styling_basics/Combinators#next-sibling_combinator)
* `~` - the [subsequent sibling](https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/Styling_basics/Combinators#subsequent-sibling_combinator)


### Limitations

* The [column](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_selectors/Selectors_and_combinators#column_combinator) and [namespace](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_selectors/Selectors_and_combinators#namespace_separator) combinators are **not** supported
* **Here be dragons**: This tool was written by someone who is not especially good at writing parsers ; It may break or behave unexpectedly. Don't hesitate to report issues !
* This tool was not designed with speed in mind ; it seems _fast enough_ for common CLI usage purposes.

### TODO

- [ ] Universal selector (`*` to match any element)
- [ ] Attribute selectors (`[attr="value"]`)
- [ ] A way to "group" selectors, e.g. `aside {p, footer}` to select all `p`s and `footer`s in `aside`s ? 

## Usage

```
Usage: lua main.lua [FLAGS] <html_path_or_minus> <css_selector>
  html_path_or_minus: Path to HTML file or '-' for stdin
  css_selector: CSS selector to search for

  Flags:
  -f, --first-only: return only the first match
  -q, --quiet: Don't print warnings
```

## Motivation

I needed this for a specific need of mine, where I wanted to systematically extract the HTML starting with an element with a certain id, up to the closing tag. While I could probably have hacked something together for this one-time use case, in typical programmer spirit, I decided to create a tool.

This is my first parser, and it was very fun!
Writing a parser seems to be a kind of "rite of passage" for programmers, and now I did it too.

Obviously, this could have been solved with `jsdom` and like 10 lines of JS.

Plus, it's kinda neat to have a lightweight, dependency-free way to mess with web stuff in Lua.


## Installation

Htmlq is written in Lua and requires no external dependencies. To use it, you will need to have Lua installed on your system. You can check if Lua is installed by running `lua -v` in your terminal. If Lua is not installed, you can install it from your distribution's package manager or from the official Lua website.

## Compiling

To compile Htmlq, you will need to use `luastatic`. You can install `luastatic` via `luarocks` by running the following command:

```
luarocks install luastatic
```

Once `luastatic` is installed, you can compile Htmlq by running the following command in your terminal, from the project's root directory:

```
luastatic main.lua css.lua html.lua logging.lua /usr/lib/liblua5.4.so
```

Note that all `.lua` files from the project need to be specified, with `main.lua` as the first one. Also, the path to `liblua` may vary according to your system. The example provided is for an installation on EndeavourOS.

## Running

Once compiled, you can run Htmlq using the following command:

```
./htmlq [FLAGS] <html_path_or_minus> <css_selector>
```

Where:

*   `<html_path_or_minus>` is the path to the HTML file you want to parse, or `-` to read from stdin.
*   `<css_selector>` is the CSS selector you want to use to query the HTML.

### Flags

*   `-f`, `--first-only`: Return only the first match
*   `-q`, `--quiet`: Don't print warnings
