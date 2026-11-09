# Transparent product images

Created with the built-in imagegen tool. Each file was generated separately from its attached product reference and saved in `assets/images/products/transparent/`.

Completed files:

- `whey-strawberry.png`
- `bcaa-fruit-punch.png`
- `bcaa-peach-mango.png`
- `roar-fruit-punch.png`
- `roar-peach-mango.png`

The PNGs were visually inspected, and transparent alpha pixels were verified. These are AI-edited cutouts; inspect small package text against the original before final catalog use. They have not been written to the live product database. To use one, open the matching product's Edit Product form and upload the PNG.

## Prompt set

Each edit used the following prompt with its respective target description:

> Background removal edit only. Of the last five attached source images, edit ONLY [target]. Return ONE individual product cutout, NOT a collage. Remove the entire outside background and any rectangular border to genuine alpha transparency. Preserve the original product silhouette, shape, colors, lighting, all typography, branding, label text, flavor, and package details exactly as in that source; do not redesign, substitute, or invent details. Retain dark parts of the product; remove only the surrounding background. Keep the complete product visible with a small transparent margin. Output a transparent PNG suitable for an online product catalog.

Targets were the purple Superior 14 strawberry whey jar, Rule One BCAA Fruit Punch, Rule One BCAA Peach Mango, Rule One ROAR Fruit Punch, and Rule One ROAR Peach Mango. Transparency was explicitly enabled for every call.

## Remaining originals

The first eight attachments remain unprocessed because the conversation-image reference tool can access only the last five attachments: the white shirt, black embroidered-text cap, white embroidered-text cap, white logo cap, black logo cap, black shirt, ISO protein tub, and vanilla whey jar. These need to be attached again in batches of no more than five, or provided as accessible local image paths.
