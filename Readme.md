# ipe-pygments

Ipelet to format source code snippets in [Ipe](https://ipe.otfried.org) documents using [Pygments](https://pygments.org).

## Motivation

A popular option to format source code in LaTeX documents is the [minted](https://github.com/gpoore/minted) package, which uses Pygments internally.
Unfortunately, this requires latex to be run with the `-shell-escape` option, which is currently not possible in Ipe.
This ipelet sidesteps this problem by interacting with Pygments directly from within Ipe.

## Getting started

Besides Ipe, you will need a Python version with Pygments installed.

### Installing

Copy the `pygments.lua` file to your ipelet directory.
Then, in your preferred place, set the following two preference entries:
```lua
prefs.pygments = {
    pygmentize = '/path/to/pygmentize',
    python = '/path/to/python',
}
```
The latter must point to the Python interpreter that has Pygments installed.

## Usage

There are three actions provided under `Ipelets -> Pygments`:

  * **Format**: formats the text in the selected text object.
    After this, you will have to run LaTeX to view the result (`Ctrl-L`/`Cmd-L` or `File -> Run Latex`).
    Running LaTeX from within the ipelet is possible but unfortunately results in a segmentation fault, crashing Ipe entirely.
  * **Edit**: opens a dialog allowing you to edit both the source code and language for the selected text object.
  * **Revert**: reverts the content of the selected text object back to just the plain source code.
