// Packs TrueType fonts as WOFF2 using only Node's built-in Brotli (no downloads).
// Tables are stored untransformed (WOFF2 "null transform"), so the output is a bit
// larger than a full woff2_compress but identical in glyphs and valid in every browser.
//
//   node docs/tools/ttf-to-woff2.mjs website/assets/fonts/*.ttf
//
// Writes <name>.woff2 next to each input. Keep the .ttf files as the originals/fallback.
import { readFileSync, writeFileSync } from 'node:fs';
import { brotliCompressSync, constants } from 'node:zlib';

const KNOWN = ['cmap','head','hhea','hmtx','maxp','name','OS/2','post','cvt ','fpgm','glyf','loca','prep','CFF ','VORG','EBDT','EBLC','gasp','hdmx','kern','LTSH','PCLT','VDMX','vhea','vmtx','BASE','GDEF','GPOS','GSUB','EBSC','JSTF','MATH','CBDT','CBLC','COLR','CPAL','SVG ','sbix','acnt','avar','bdat','bloc','bsln','cvar','fdsc','feat','fmtx','fvar','gvar','hsty','just','lcar','mort','morx','opbd','prop','trak','Zapf','Silf','Glat','Gloc','Feat','Sill'];

const base128 = (n) => {
  const out = [n & 0x7f];
  while ((n >>>= 7)) out.unshift((n & 0x7f) | 0x80);
  return Buffer.from(out);
};

function toWoff2(ttf) {
  const flavor = ttf.readUInt32BE(0);
  if (flavor !== 0x00010000) throw new Error('only TrueType (glyf) fonts are supported');
  const n = ttf.readUInt16BE(4);
  const tables = [];
  for (let i = 0; i < n; i++) {
    const o = 12 + i * 16;
    const tag = ttf.toString('latin1', o, o + 4);
    const off = ttf.readUInt32BE(o + 8), len = ttf.readUInt32BE(o + 12);
    tables.push({ tag, data: ttf.subarray(off, off + len) });
  }
  tables.sort((a, b) => (a.tag < b.tag ? -1 : 1));

  const dir = [], parts = [];
  let sfntSize = 12 + 16 * n;
  for (const t of tables) {
    const idx = KNOWN.indexOf(t.tag);
    const xform = t.tag === 'glyf' || t.tag === 'loca' ? 3 : 0; // 3 = null transform for glyf/loca
    dir.push(Buffer.from([(idx < 0 ? 63 : idx) | (xform << 6)]));
    if (idx < 0) dir.push(Buffer.from(t.tag, 'latin1'));
    dir.push(base128(t.data.length));
    parts.push(t.data);
    sfntSize += (t.data.length + 3) & ~3;
  }
  const dirBuf = Buffer.concat(dir);
  const packed = brotliCompressSync(Buffer.concat(parts), {
    params: { [constants.BROTLI_PARAM_QUALITY]: 11, [constants.BROTLI_PARAM_MODE]: constants.BROTLI_MODE_FONT },
  });
  const total = 48 + dirBuf.length + packed.length;
  const padded = (total + 3) & ~3;
  const h = Buffer.alloc(48);
  h.write('wOF2', 0, 'latin1');
  h.writeUInt32BE(flavor, 4);
  h.writeUInt32BE(padded, 8);
  h.writeUInt16BE(n, 12);
  h.writeUInt32BE(sfntSize, 16);
  h.writeUInt32BE(packed.length, 20);
  h.writeUInt16BE(1, 24); // major version
  return Buffer.concat([h, dirBuf, packed, Buffer.alloc(padded - total)]);
}

for (const file of process.argv.slice(2)) {
  const src = readFileSync(file);
  const out = toWoff2(src);
  const dest = file.replace(/\.ttf$/i, '.woff2');
  writeFileSync(dest, out);
  console.log(`${dest}  ${src.length} -> ${out.length} bytes`);
}
