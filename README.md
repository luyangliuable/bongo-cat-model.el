# bongo-cat-mode

Bongo Cat types in your Emacs mode-line.

This package displays the CodingCat artwork in the mode-line with the laptop and
headphones removed. When you type, the cat alternates paw frames and appears to
beat on the keyboard. After typing stops, it returns to an idle frame.

The artwork is adapted from the local CodingCat component at:

```text
/Users/liul31/personal-portfolio-next/src/components/CodingCat/
```

## Installation

### Doom Emacs local package

Add this to `packages.el`:

```elisp
(package! bongo-cat-mode
  :recipe (:local-repo "~/bongo-cat-mode"
           :files ("bongo-cat-mode.el" "img")))
```

Then run:

```sh
doom sync
```

Enable it from your config:

```elisp
(use-package! bongo-cat-mode
  :config
  (bongo-cat-mode 1))
```

### Vanilla Emacs

```elisp
(add-to-list 'load-path "~/bongo-cat-mode")
(require 'bongo-cat-mode)
(bongo-cat-mode 1)
```

## Customization

Use the white image set:

```elisp
(setq bongo-cat-color-scheme 'white)
```

Use the original color image set:

```elisp
(setq bongo-cat-color-scheme 'color)
```

Options:

- `bongo-cat-height`
- `bongo-cat-color-scheme`
- `bongo-cat-animation-frame-interval`
- `bongo-cat-idle-timeout`
- `bongo-cat-minimum-window-width`

## License

GPL-3.0-or-later. See `LICENSE`.
