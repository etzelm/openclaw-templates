// Render the avatar SVG to PNGs with sharp. Set SHARP_MODULE to its path if sharp is not installed here.
// Usage: node render-icon.cjs <svg> <outdir>
const path = require("node:path");
const sharp = require(process.env.SHARP_MODULE || "sharp");
const [svg, outdir] = process.argv.slice(2);
(async () => {
  for (const size of [256, 96, 24]) {
    const out = path.join(outdir, `icon-${size}.png`);
    await sharp(svg, { density: 300 }).resize(size, size).png().toFile(out);
    console.log(out);
  }
})().catch((e) => { console.error(e); process.exit(1); });
