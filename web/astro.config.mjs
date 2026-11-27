// @ts-check
import { defineConfig } from 'astro/config';

import react from '@astrojs/react';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  integrations: [react()],

  // El monitoreo comunitario vive en la portada.
  redirects: { '/plataforma/monitoreo': '/visores/reportes' },

  vite: {
    plugins: [tailwindcss()],
    server: { fs: { allow: ['..'] } }
  }
});