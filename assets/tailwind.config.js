module.exports = {
  purge: [
    '../lib/**/*.ex',
    '../lib/**/*.leex',
    '../lib/**/*.eex',
    './js/**/*.js'
  ],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      colors: {
        brown: {
          DEFAULT: '#7E6449',
          '50': '#E1D7CB',
          '100': '#D8CABB',
          '200': '#C5B19B',
          '300': '#B3977A',
          '400': '#9F7E5B',
          '500': '#7E6449',
          '600': '#5E4B36',
          '700': '#3E3123',
          '800': '#1D1711',
          '900': '#000000'
        },
        green: {
          DEFAULT: '#658259',
          '50': '#DEE6DB',
          '100': '#D0DCCB',
          '200': '#B5C7AD',
          '300': '#99B38F',
          '400': '#7E9E70',
          '500': '#658259',
          '600': '#4E6444',
          '700': '#364630',
          '800': '#1F271B',
          '900': '#070906'
        }
      }
    },
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
