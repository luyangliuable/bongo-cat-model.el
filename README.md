# bongo-cat-mode

[![CI](https://github.com/luyangliuable/bongo-cat-model.el/actions/workflows/ci.yml/badge.svg)](https://github.com/luyangliuable/bongo-cat-model.el/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

Bongo Cat types in your Emacs mode-line.

This package displays the CodingCat artwork in the mode-line with the laptop and
headphones removed. When you type, the cat alternates paw frames and appears to
beat on the keyboard. After typing stops, it returns to an idle frame.

There are two modes to choose from:

- `bongo-cat-mode` - the original cat, drawn at its natural angle. It animates
  only while you type.
- `bongo-cat-scroll-mode` - a flattened (0 degrees) cat that slides left and
  right along a horizontal track following the window's scroll position
  (`window-start`/`window-end`, like Emacs's `%p`/`%P` and `sml-modeline`): far
  left when the top of the buffer is visible, far right when the last screenful
  is shown. A continuous table line (matching the cat's own border color
  and thickness) runs the full width and through the cat: solid behind the cat
  (already scrolled) and faint ahead (remaining). It still animates its paws
  while you type.

Enable whichever you prefer:

```elisp
(bongo-cat-mode 1)         ; angled, typing only
(bongo-cat-scroll-mode 1)  ; flat, slides with scroll position
```

The two modes are alternatives; enable one at a time.

The artwork is adapted from the "Coding Cat" design and redrawn for the
mode-line (laptop and headphones removed).

## Installation

The package ships the artwork in the `img/` directory, so make sure those
assets are installed alongside the Elisp file.

### straight.el / use-package

```elisp
(use-package bongo-cat-mode
  :straight (bongo-cat-mode
             :host github
             :repo "luyangliuable/bongo-cat-model.el"
             :files ("bongo-cat-mode.el" "img"))
  :config
  (bongo-cat-mode 1))
```

### Doom Emacs

Add this to `packages.el`:

```elisp
(package! bongo-cat-mode
  :recipe (:host github
           :repo "luyangliuable/bongo-cat-model.el"
           :files ("bongo-cat-mode.el" "img")))
```

Then run `doom sync` and enable it from your config:

```elisp
(use-package! bongo-cat-mode
  :config
  (bongo-cat-mode 1))
```

For local development, point the recipe at a local checkout instead
(`:local-repo "~/path/to/bongo-cat-model.el"`).

### Vanilla Emacs

```elisp
(add-to-list 'load-path "~/bongo-cat-mode")
(require 'bongo-cat-mode)
(bongo-cat-mode 1)
```

## Customization

Choose a color scheme by setting `bongo-cat-color-scheme` before enabling the
mode.

```elisp
(setq bongo-cat-color-scheme 'white)
```

Available schemes:

```elisp
(setq bongo-cat-color-scheme 'white) ; white cat, black lines
(setq bongo-cat-color-scheme 'black) ; black cat, colored lines
```

If changing the scheme in a running Emacs session, refresh cached images:

```elisp
(setq bongo-cat-color-scheme 'white)
(bongo-cat-mode-clear-cache)
(force-mode-line-update t)
```

Doom example:

```elisp
(use-package! bongo-cat-mode
  :init
  (setq bongo-cat-color-scheme 'white
        bongo-cat-height 28)
  :config
  (bongo-cat-mode-clear-cache)
  (bongo-cat-mode 1))
```

Options:

- `bongo-cat-height`
- `bongo-cat-color-scheme`
- `bongo-cat-animation-frame-interval`
- `bongo-cat-idle-timeout`
- `bongo-cat-minimum-window-width`

Scroll-mode options (`bongo-cat-scroll-mode`):

- `bongo-cat-track-width` - track length in mode-line cells (default `48`);
  increase it for a longer table / more cat travel
- `bongo-cat-track-baseline` - fraction of the flat cat above its body-bottom
  line, used as the image `:ascent`. The flat cat image is padded so its
  body-underside (table) line is centered, so both the cat and the rail tiles
  sit on that line with the paws hanging below (default `0.5`)

The rail is drawn with matching line-tile images
(`img/bongo-cat-<scheme>-rail-solid.png` behind the cat and `-rail-faint.png`
ahead), so its color and thickness match the cat's border exactly.  When PNG
images are unavailable it falls back to box-drawing characters, controlled by:

- `bongo-cat-track-fill-char` - fallback char behind the cat (default heavy `─`)
- `bongo-cat-track-line-char` - fallback char ahead of the cat (default light `─`)
- `bongo-cat-track-face` - fallback face for the rail (default `shadow`)
- `bongo-cat-track-raise` - fallback vertical nudge for the rail characters
  (default `0.0`)

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for how to
run the tests and linters locally.

## License

GPL-3.0-or-later. See `LICENSE`.
