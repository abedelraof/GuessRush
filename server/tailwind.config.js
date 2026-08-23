/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/views/**/*.ejs', './public/**/*.js'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Inter"', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
      colors: {
        brand: {
          50: '#f4f1fe',
          100: '#ebe5fd',
          200: '#d5c9fb',
          300: '#b7a1f7',
          400: '#9a79f0',
          500: '#764be5',
          600: '#5f36cc',
          700: '#4c2aa3',
          800: '#3d2381',
          900: '#332069',
        },
      },
      boxShadow: {
        card: '0 1px 2px rgba(16, 24, 40, 0.06), 0 1px 3px rgba(16, 24, 40, 0.08)',
      },
    },
  },
  plugins: [],
};
