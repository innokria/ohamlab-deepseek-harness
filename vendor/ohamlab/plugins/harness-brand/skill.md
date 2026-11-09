# Harness Branding Plugin - Steps

## Overview
This plugin customizes the DSH (DeepSeek Harness) web UI branding. It displays a custom brand name in the sidebar and adds a floating fish animation overlay.

## Installation

1. **Place the plugin directory**
   - Ensure your plugin is located at `/data/dsh/plugins/harness-brand/`
   - The plugin structure should include:
     - `package.json` - Plugin manifest
     - `lib/client.js` - Client-side code
     - `lib/index.ts` - Server-side API
     - `steps.md` - This documentation

2. **Build the plugin** (if modifications are needed)
   ```bash
   # From the plugin directory
   cd /data/dsh/plugins/harness-brand
   npm run build
   # or
   node build.mjs
   ```
   - This compiles TypeScript in `lib/` from source in `src/` (if applicable)
   - The existing build is already pre-compiled

## Configuration

### Setting a Custom Brand Name

The plugin reads the brand name from the `HARNS_BRAND_NAME` environment variable.

**To set a custom brand name:**

```bash
# Using the DSH web interface startup
export HARNS_BRAND_NAME="My Custom Brand"
# Then start/restart the DSH web interface

# Or set it in your .env file
echo 'HARNS_BRAND_NAME=My Custom Brand' >> /path/to/.env

# Or pass it when starting the process
HARNS_BRAND_NAME="DeepSeek" pnpm run dev:web
```

**Default behavior:**
- If `HARNS_BRAND_NAME` is not set, the plugin displays "OhamLab Harness" (the original branding)
- The gradient color scheme adapts automatically based on the brand name length

### How it works

1. At plugin initialization, the `apply(ctx)` function reads `process.env.HARNS_BRAND_NAME`
2. It injects a custom component into the `sidebar.brand.name` slot
3. The component renders the brand name with a gradient background
4. The floating fish overlay continues to work as before

## Features

### 1. Custom Brand Name
- Displays your chosen text in the left sidebar brand area
- Adapts gradient colors based on the name
- Falls back to "OhamLab Harness" if not configured

### 2. Floating Fish Overlay
- Animated fish swimming across the screen
- Bubbles rising from the fish
- Clicking the fish triggers a speed boost effect
- Maintains original behavior regardless of brand name

### 3. Non-Breaking
- The plugin uses DSH's slot injection system
- It registers after any core branding, so it can override default branding
- If another plugin registers the same slot first, this one won't overwrite it (declaration-aware)

## Testing

### Verify Brand Name Display

1. Start the DSH web interface with your custom brand:
   ```bash
   HARNS_BRAND_NAME="My Lab" pnpm run dev:web
   ```

2. Open http://127.0.0.1:3080 in your browser

3. Check the left sidebar - you should see "My Lab" with gradient styling instead of "OhamLab Harness"

### Verify Fish Overlay

1. Ensure the fish animation is still present at the bottom of the screen

2. Try clicking on the larger fish - it should trigger a speed boost with extra bubbles

3. Verify the swimming animation continues smoothly

### Edge Cases

- **Empty brand name**: Falls back gracefully to "OhamLab Harness"
- **Very long brand name**: Gradient colors cycle, text may wrap (handled by CSS)
- **Special characters**: Rendered as-is, may not display optimally

## Troubleshooting

### Brand Name Not Appearing

1. Check that `HARNS_BRAND_NAME` is set in the environment where the DSH web process is running
2. Verify the plugin is loading - check browser console for plugin load messages
3. Ensure the DSH web interface is refreshed after changing the environment variable

### Fish Overlay Missing

1. Confirm the plugin is loading correctly
2. Check that no other plugin is interfering with the `shell.overlay` slot
3. Verify the browser supports CSS animations (modern browsers supported)

### Gradient Colors Look Wrong

- The gradient is auto-generated based on the brand name length
- Shorter names have fewer color stops
- Very short names (1-2 words) may have solid or simple gradients

## Development

### Modifying the Plugin

1. Edit source files in `/data/dsh/plugins/harness-brand/lib/` or create `src/` directory
2. Rebuild with `npm run build` or `node build.mjs`
3. Restart the DSH web interface to see changes

### Adding New Features

1. The plugin architecture uses DSH's slot injection system
2. New slots can be injected using `ctx.slots.inject(slotName, component)`
3. Refer to `@deepseek-ai/dsh-client-ui-sidebar` and `@deepseek-ai/dsh-client-ui-layout` for slot names
