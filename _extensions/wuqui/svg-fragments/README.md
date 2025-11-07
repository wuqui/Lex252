# SVG Fragments for Reveal.js (Quarto Extension)

Inline SVGs authored in Inkscape and reveal them step-by-step in Reveal.js by mapping layers to fragments.

## Install

```bash
quarto add wuqui/quarto-revealjs-svg-fragments --no-prompt
```

## Use

```markdown
{{< svg-frag file="img/layered.svg" >}}
{{< svg-frag file="img/layered.svg" start=5 >}}
{{< svg-frag file="img/layered.svg" class="custom-fragment" >}}
{{< svg-frag file="img/layered.svg" width="600px" >}}
{{< svg-frag file="img/layered.svg" width="80%" height="400px" >}}
```

Parameters:
- `file` (required): path to the SVG.
- `start` (default `0`): starting fragment index.
- `class` (default `fragment`): fragment class name.
- `width` (optional): custom width (e.g., `600px`, `80%`). Overrides default CSS.
- `height` (optional): custom height (e.g., `400px`, `50vh`). Overrides default CSS.

Notes:
- Layers are ordered by numeric suffix in `inkscape:label` if present (e.g., `Layer 2`), else by document order.
- If no Inkscape layers are found, the SVG is emitted unchanged.

## Responsive SVG

This extension contributes CSS to make inline SVGs scale within slides.

```css
.reveal .slides svg {
  width: 100%;
  height: auto;
  max-height: 75vh;
  display: block;
}
```

## Optional: Crop page to drawing

For large canvases, pre-crop using Inkscape CLI via the helper script:

```bash
lua src/crop_svg_to_drawing.lua img/source.svg img/source_cropped.svg
```

Then include the cropped file.

## License

MIT

