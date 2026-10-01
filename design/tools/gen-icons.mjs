// Generate HarmonyOS layered-icon PNGs from the master InkAuth logo SVGs.
// Light: out/icon_foreground.png + out/icon_background.png (deployed to AppScope/base).
// Dark:  out/icon_foreground_dark.png + out/icon_background_dark.png (deployed to AppScope/dark).
// Composites (icon_preview*.png) are for human check only.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { Resvg } from '@resvg/resvg-js';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, '..', 'out');
mkdirSync(outDir, { recursive: true });

const innerOf = (svg) => svg.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');

const variants = [
  { suffix: '', svgFile: '../inkauth-logo-final.svg', bg: '#FBF8FF' },
  { suffix: '_dark', svgFile: '../inkauth-logo-final-dark.svg', bg: '#121318' },
];

for (const v of variants) {
  const inner = innerOf(readFileSync(join(here, v.svgFile), 'utf8'));
  // Ring outer edge is 312 units; with a 944-unit viewBox it lands at ~66% of 1024,
  // inside the HarmonyOS foreground safe zone.
  const fgSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="-472 -472 944 944" width="1024" height="1024">${inner}</svg>`;
  writeFileSync(join(outDir, `icon_foreground${v.suffix}.svg`), fgSvg);
  writeFileSync(
    join(outDir, `icon_foreground${v.suffix}.png`),
    new Resvg(fgSvg, { fitTo: { mode: 'width', value: 1024 } }).render().asPng()
  );

  const bgSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024"><rect width="1024" height="1024" fill="${v.bg}"/></svg>`;
  writeFileSync(
    join(outDir, `icon_background${v.suffix}.png`),
    new Resvg(bgSvg).render().asPng()
  );

  const compSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024"><rect width="1024" height="1024" fill="${v.bg}"/><svg viewBox="-472 -472 944 944" width="1024" height="1024">${inner}</svg></svg>`;
  writeFileSync(
    join(outDir, `icon_preview${v.suffix}.png`),
    new Resvg(compSvg).render().asPng()
  );
}
console.log('generated: icon_{foreground,background,preview}[_dark].png');
