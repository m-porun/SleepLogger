module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js'
  ],
  plugins: [require("daisyui")],
  daisyui: {
    themes: [
      {
        mytheme: {
          "primary": "#f5f5f5",
          "secondary": "#c3c3c3",
          "accent": "#5862ab",
          "neutral": "#3d3a39",
          "base-100": "#e3e0dc",
          "info": "#5862ab",
          "success": "#5862ab",
          "warning": "#8d7683",
          "error": "#8d7683",
          },
        },
      ],
      darkTheme: false, // ダークテーマを採用しない
    },
}