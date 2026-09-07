// @pascal-app/mcp@0.3.2 ships 179 extensionless relative imports while being
// "type": "module". Bundlers (Next/Vite) resolve those; plain Node ESM does not.
// This resolve hook retries a failed relative specifier as "<spec>.js" and then
// "<spec>/index.js", which is exactly what a bundler would have done.
export async function resolve(specifier, context, nextResolve) {
  try {
    return await nextResolve(specifier, context)
  } catch (err) {
    const fixable = err?.code === 'ERR_MODULE_NOT_FOUND' || err?.code === 'ERR_UNSUPPORTED_DIR_IMPORT'
    if (!fixable || !specifier.startsWith('.')) throw err
    for (const suffix of ['.js', '/index.js']) {
      try {
        return await nextResolve(specifier + suffix, context)
      } catch {
        /* try next */
      }
    }
    throw err
  }
}
