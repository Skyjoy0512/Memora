const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');

const appRoot = path.resolve(__dirname, '..');
const tokenPath = path.join(appRoot, 'src/design/tokens.ts');
const outputPath = path.join(appRoot, 'src/design/heroui-theme.css');
const source = fs.readFileSync(tokenPath, 'utf8');
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const tokenModule = { exports: {} };

vm.runInNewContext(compiled, { exports: tokenModule.exports, module: tokenModule, require });

const { colors, darkColors, fonts, radius, shadow, spacing } = tokenModule.exports;
const declaration = (name, value) => `    ${name}: ${value};`;
const shadowValue = ({ shadowColor, shadowOffset, shadowOpacity, shadowRadius }) => {
  const hex = shadowColor.slice(1);
  const expandedHex = hex.length === 3 ? [...hex].map((character) => character.repeat(2)).join('') : hex;
  const red = Number.parseInt(expandedHex.slice(0, 2), 16);
  const green = Number.parseInt(expandedHex.slice(2, 4), 16);
  const blue = Number.parseInt(expandedHex.slice(4, 6), 16);

  return `${shadowOffset.width}px ${shadowOffset.height}px ${shadowRadius}px rgba(${red}, ${green}, ${blue}, ${shadowOpacity})`;
};
const shared = [
  declaration('--memora-font-regular', `'${fonts.sans.regular.fontFamily}'`),
  declaration('--memora-font-medium', `'${fonts.sans.medium.fontFamily}'`),
  declaration('--memora-font-semibold', `'${fonts.sans.semibold.fontFamily}'`),
  ...Object.entries(spacing).map(([name, value]) => declaration(`--memora-space-${name}`, `${value}px`)),
  ...Object.entries(radius).map(([name, value]) => declaration(`--memora-radius-${name}`, `${value}px`)),
];
const theme = (palette) => [
  declaration('--background', palette.canvas),
  declaration('--foreground', palette.text),
  declaration('--surface', palette.surface),
  declaration('--surface-foreground', palette.text),
  declaration('--surface-secondary', palette.surfaceAlt),
  declaration('--surface-secondary-foreground', palette.text),
  declaration('--surface-tertiary', palette.surfaceElevated),
  declaration('--surface-tertiary-foreground', palette.text),
  declaration('--overlay', palette.surfaceElevated),
  declaration('--overlay-foreground', palette.text),
  declaration('--backdrop', palette.overlayLight),
  declaration('--muted', palette.textSecondary),
  declaration('--default', palette.surfaceAlt),
  declaration('--default-foreground', palette.text),
  declaration('--accent', palette.accent),
  declaration('--accent-foreground', palette.textInverse),
  declaration('--field-background', palette.surface),
  declaration('--field-foreground', palette.text),
  declaration('--field-placeholder', palette.textTertiary),
  declaration('--field-border', palette.border),
  declaration('--success', palette.success),
  declaration('--success-foreground', palette.textInverse),
  declaration('--warning', palette.warning),
  declaration('--warning-foreground', palette.textInverse),
  declaration('--danger', palette.danger),
  declaration('--danger-foreground', palette.textInverse),
  declaration('--segment', palette.surface),
  declaration('--segment-foreground', palette.text),
  declaration('--border', palette.border),
  declaration('--separator', palette.separator),
  declaration('--focus', palette.accent),
  declaration('--link', palette.accent),
];

const css = `/* Generated from src/design/tokens.ts by scripts/generate-heroui-theme.cjs. */
@theme inline static {
  --font-sans: var(--memora-font-regular);
  --font-normal: var(--memora-font-regular);
  --font-medium: var(--memora-font-medium);
  --font-semibold: var(--memora-font-semibold);
  --spacing: var(--memora-space-xs);
  --radius: var(--memora-radius-md);
  --radius-xs: var(--memora-radius-xs);
  --radius-sm: var(--memora-radius-sm);
  --radius-md: var(--memora-radius-md);
  --radius-lg: var(--memora-radius-md);
  --radius-xl: var(--memora-radius-lg);
  --radius-2xl: var(--memora-radius-lg);
  --radius-3xl: var(--memora-radius-lg);
  --radius-4xl: var(--memora-radius-lg);
}

@layer theme {
  :root {
${shared.join('\n')}

    @variant light {
${theme(colors).join('\n')}
      --surface-shadow: ${shadowValue(shadow.card)};
      --overlay-shadow: ${shadowValue(shadow.floating)};
      --field-shadow: ${shadowValue(shadow.card)};
    }

    @variant dark {
${theme(darkColors).join('\n')}
      --surface-shadow: none;
      --overlay-shadow: none;
      --field-shadow: none;
    }
  }
}
`;

fs.writeFileSync(outputPath, css);
